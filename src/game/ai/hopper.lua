-- The Hopper personality (docs/CONTEXT.md "Personality"): sits landed and
-- fires from the turret with the shared aim-and-fire step (Basic.shoot).
-- When src/game/ai/skills/danger.lua senses a shell or asteroid coming, it
-- lifts off straight up the surface normal, steers its thrust across the
-- threat's path, keeps flying while still threatened, then lands gently
-- with src/game/ai/skills/flight.lua and goes back to the turret. A target
-- the turret cannot reach gets a hop tilted toward it instead. Hops are
-- only planned with config.ai.hopFuel in the tank (fuel refills only in
-- tank mode). Stuck (src/game/ai/skills/stuck.lua: no shot for
-- config.ai.stuckDelay) it stops hopping and fires an unsolved shot with the
-- turret at its limit toward the target; stuck for two delays it hops again.
--
-- Modes on `state.mode`: "landed" -> "hop" (thrust for at least the level's
-- hopTime, longer while a threat remains and fuel allows) -> "land" ->
-- "landed". Thinks every `reactionDelay` seconds and holds the intent in
-- between; levels differ only by config numbers (dangerHorizon, hopTime).
local Angle = require("src.core.angle")
local Bodies = require("src.sim.bodies")
local Lander = require("src.game.components.lander")
local Basic = require("src.game.ai.basic")
local Danger = require("src.game.ai.skills.danger")
local Flight = require("src.game.ai.skills.flight")
local Stuck = require("src.game.ai.skills.stuck")

local Hopper = {}

local function clamp(value, limit)
	return math.max(-limit, math.min(limit, value))
end

local INCOMING = { shell = true, asteroid = true }

-- Across the threat's path, on the side away from the surface, at most
-- `tilt` off the surface normal (the landed body's angle).
local function dodgeAngle(body, threat, tilt)
	local nx, ny = math.sin(body.angle), -math.cos(body.angle)
	local px, py = threat.vy, -threat.vx
	if px * nx + py * ny < 0 then
		px, py = -px, -py
	end
	return body.angle + clamp(Angle.wrap(Flight.angleOf(px, py) - body.angle), tilt)
end

local function startHop(ctx, level, state, angle)
	state.mode = "hop"
	state.hopUntil = ctx.time + level.hopTime
	state.hopAngle = angle
	state.charging = false
	return Flight.liftOff()
end

-- A shot at the turret's limit toward the aim the turret cannot reach,
-- kept the level's aim error inside the limit so the aim stays reachable.
local function limitShot(ctx, ship, body, level, state)
	local limit = ctx.config.tank.turretLimit - level.aimError
	state.aim.angle = body.angle + clamp(Angle.wrap(state.aim.angle - body.angle), limit)
	state.aim.solved = false
	return Basic.shoot(ctx, ship, body, level, state)
end

local function think(ctx, ship, body, level, state)
	local config = ctx.config
	local grounded = Lander.isGrounded(ship)
	local threats = Danger.scan(ctx.sim, ctx.level.worlds, body, config, { dt = ctx.dt, horizon = level.dangerHorizon })
	local threat = Danger.firstOf(threats, INCOMING, math.huge)

	if state.mode == "hop" then
		if grounded and ctx.time >= state.hopUntil then
			state.mode = "landed"
		elseif ctx.time < state.hopUntil or (threat and ship.fuel.amount > config.ai.landFuel) then
			local rotate = Flight.steer(body, state.hopAngle, config, level.reactionDelay)
			return { rotate = grounded and 0 or rotate, thrust = true, fire = false }
		else
			state.mode = "land"
		end
	end

	if not grounded then
		state.mode = "land"
		return Flight.land(ctx.sim, body, threats, config, { fuel = ship.fuel, hold = level.reactionDelay })
	end

	state.mode = "landed"
	local canHop = ship.fuel.amount >= config.ai.hopFuel
	if threat and canHop then
		return startHop(ctx, level, state, dodgeAngle(body, threat, config.ai.dodgeTilt))
	end
	local intent = Basic.shoot(ctx, ship, body, level, state)
	if intent.thrust then
		-- The turret can't reach the aim. Stuck: fire at the turret's limit,
		-- unless two delays have passed and a hop is possible. Otherwise hop
		-- toward the target, or wait.
		local stuck = Stuck.cycles(ctx, state)
		if stuck >= 1 and not (stuck >= 2 and canHop) then
			return limitShot(ctx, ship, body, level, state)
		end
		if canHop then
			local side = Angle.wrap(state.aim.angle - body.angle) < 0 and -1 or 1
			return startHop(ctx, level, state, body.angle + side * config.ai.dodgeTilt)
		end
		intent.thrust = false
	end
	return intent
end

-- Writes ctx.intents[slot]. Re-thinks once ctx.time reaches state.nextThink;
-- otherwise the previous intent stays on ctx.intents.
function Hopper.update(ctx, slot, ship, level, state)
	local body = Bodies.get(ctx.sim.bodies, ship.body)
	if not body then
		return
	end
	if ctx.time >= state.nextThink then
		state.intent = think(ctx, ship, body, level, state)
		if state.intent.fire then
			Stuck.fired(ctx, state)
		end
		state.nextThink = ctx.time + level.reactionDelay
	end
	local held = state.intent
	ctx.intents[slot] = { rotate = held.rotate, thrust = held.thrust, fire = held.fire }
end

return Hopper
