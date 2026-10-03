-- The Hopper personality (docs/CONTEXT.md "Personality"): sits landed and
-- fires from the turret with the shared aim-and-fire step (Basic.shoot).
-- When src/game/ai/skills/danger.lua senses a shell or asteroid coming, it
-- lifts off straight up the surface normal, steers its thrust across the
-- threat's path, keeps flying while still threatened, then lands gently
-- with src/game/ai/skills/flight.lua and goes back to the turret. A target
-- the turret cannot reach gets a hop tilted toward it instead. Hops are
-- only planned with config.ai.hopFuel in the tank (fuel refills only in
-- tank mode).
--
-- Modes on `state.mode`: "landed" -> "hop" (thrust for at least the level's
-- hopTime, longer while a threat remains and fuel allows) -> "land" ->
-- "landed". Thinks every `reactionDelay` seconds and holds the intent in
-- between; levels differ only by config numbers (dangerHorizon, hopTime).
local Bodies = require("src.sim.bodies")
local Lander = require("src.game.components.lander")
local Basic = require("src.game.ai.basic")
local Danger = require("src.game.ai.skills.danger")
local Flight = require("src.game.ai.skills.flight")

local Hopper = {}

local function wrap(angle)
	return (angle + math.pi) % (2 * math.pi) - math.pi
end

local function clamp(value, limit)
	return math.max(-limit, math.min(limit, value))
end

local function incoming(threats)
	for _, threat in ipairs(threats) do
		if threat.kind == "shell" or threat.kind == "asteroid" then
			return threat
		end
	end
	return nil
end

-- Across the threat's path, on the side away from the surface, at most
-- `tilt` off the surface normal (the landed body's angle).
local function dodgeAngle(body, threat, tilt)
	local nx, ny = math.sin(body.angle), -math.cos(body.angle)
	local px, py = threat.vy, -threat.vx
	if px * nx + py * ny < 0 then
		px, py = -px, -py
	end
	return body.angle + clamp(wrap(Flight.angleOf(px, py) - body.angle), tilt)
end

local function startHop(ctx, level, state, angle)
	state.mode = "hop"
	state.hopUntil = ctx.time + level.hopTime
	state.hopAngle = angle
	state.charging = false
	return Flight.liftOff()
end

local function think(ctx, ship, body, level, state)
	local config = ctx.config
	local grounded = Lander.isGrounded(ship)
	local threats = Danger.scan(ctx.sim, ctx.level.worlds, body, config, { dt = ctx.dt, horizon = level.dangerHorizon })
	local threat = incoming(threats)

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
		-- The turret can't reach the aim: hop toward the target, or wait.
		if canHop then
			local side = wrap(state.aim.angle - body.angle) < 0 and -1 or 1
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
		state.nextThink = ctx.time + level.reactionDelay
	end
	local held = state.intent
	ctx.intents[slot] = { rotate = held.rotate, thrust = held.thrust, fire = held.fire }
end

return Hopper
