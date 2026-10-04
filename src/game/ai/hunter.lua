-- The Hunter personality (docs/CONTEXT.md "Personality"): lifts off at the
-- first think, flies at the nearest enemy with src/game/ai/skills/flight.lua
-- (Flight.flyTo keeps its predicted path clear of worlds and the hard
-- boundary) to a standoff point above and toward itself, and fires from
-- the air with the shared aim-and-fire step (Basic.shoot) -- but only a
-- gravity-aware solution (state.aim.solved), never Basic's straight-line
-- fallback. A shell or asteroid that src/game/ai/skills/danger.lua senses
-- coming sends it across the threat's path. Below config.ai.refuelFuel
-- it lands gently and
-- sits in tank mode, still firing solved shots from the turret, until the
-- tank holds config.ai.takeoffFuel. Stuck (src/game/ai/skills/stuck.lua:
-- no shot for config.ai.stuckDelay) it takes Basic's best aimed shot,
-- solved or not.
--
-- Modes on `state.mode`: "pursue" <-> "attack" while flying, "evade" while
-- threatened, "refuel" from low fuel until refilled. Thinks every
-- `reactionDelay` seconds and holds the intent in between; levels differ
-- only by config numbers (flightHorizon, dangerHorizon, predictionHorizon).
local Bodies = require("src.sim.bodies")
local Field = require("src.sim.field")
local Lander = require("src.game.components.lander")
local Basic = require("src.game.ai.basic")
local Danger = require("src.game.ai.skills.danger")
local Flight = require("src.game.ai.skills.flight")
local Stuck = require("src.game.ai.skills.stuck")

local Hunter = {}

local function normalize(x, y)
	local len = math.sqrt(x * x + y * y)
	if len < 1e-9 then
		return 0, 0
	end
	return x / len, y / len
end

local INCOMING = { shell = true, asteroid = true }
local IMPACT = { world = true, boundary = true }

-- standoff px from the target, between straight above it (against its
-- local pull) and the direction back toward the hunter. Shared with the
-- Ambusher's strike.
function Hunter.standoffGoal(ctx, body, target)
	local pull = Field.sample(ctx.sim.field, target.x, target.y)
	local ux, uy = normalize(-pull.x, -pull.y)
	if ux == 0 and uy == 0 then
		uy = -1
	end
	local bx, by = normalize(body.x - target.x, body.y - target.y)
	local dx, dy = normalize(ux + bx, uy + by)
	if dx == 0 and dy == 0 then
		dx, dy = ux, uy
	end
	local standoff = ctx.config.ai.standoff
	return { x = target.x + dx * standoff, y = target.y + dy * standoff }
end

-- Basic.shoot, with fire and charge dropped unless the aim is a solved shot
-- (or the hunter is stuck, which takes the best aimed shot, solved or not).
local function shootSolved(ctx, ship, body, level, state)
	local intent = Basic.shoot(ctx, ship, body, level, state)
	if not (state.aim and state.aim.solved) and Stuck.cycles(ctx, state) < 1 then
		intent.fire = false
		state.charging = false
	end
	return intent
end

local function think(ctx, ship, body, level, state)
	local config = ctx.config

	if Lander.isGrounded(ship) then
		if state.mode == "refuel" and ship.fuel.amount < config.ai.takeoffFuel then
			local intent = shootSolved(ctx, ship, body, level, state)
			intent.thrust = false
			return intent
		end
		state.mode = "pursue"
		state.charging = false
		return Flight.liftOff()
	end

	-- Shells and asteroids count within the level's dangerHorizon; the scan
	-- reaches attackClearance too, so an attack never coasts into a world.
	local horizon = math.max(level.dangerHorizon, config.ai.attackClearance)
	local threats = Danger.scan(ctx.sim, ctx.level.worlds, body, config, { dt = ctx.dt, horizon = horizon })
	if state.mode == "refuel" or Basic.lowFuel(ctx, ship) then
		state.mode = "refuel"
		state.charging = false
		return Flight.land(ctx.sim, body, threats, config, { fuel = ship.fuel, hold = level.reactionDelay })
	end

	local threat = Danger.firstOf(threats, INCOMING, level.dangerHorizon)
	if threat then
		state.mode = "evade"
		state.charging = false
		return Flight.flyWith(ctx, ship, body, level, Flight.evadeGoal(ctx.sim, body, threat, config))
	end

	local target = Basic.nearestEnemy(ctx, ship, body)
	if not target then
		state.mode = "pursue"
		return Flight.land(ctx.sim, body, threats, config, { fuel = ship.fuel, hold = level.reactionDelay })
	end

	local clear = not Danger.firstOf(threats, IMPACT, config.ai.attackClearance)
	local shellAlive = ship.weapon and ship.weapon.shell and Bodies.get(ctx.sim.bodies, ship.weapon.shell)
	if clear and target.dist <= config.ai.attackRange and (state.charging or not shellAlive) then
		local intent = shootSolved(ctx, ship, body, level, state)
		if state.aim.solved or Stuck.cycles(ctx, state) >= 1 then
			state.mode = "attack"
			return intent
		end
	end

	state.mode = "pursue"
	state.charging = false
	return Flight.flyWith(ctx, ship, body, level, Hunter.standoffGoal(ctx, body, target))
end

-- Writes ctx.intents[slot]. Re-thinks once ctx.time reaches state.nextThink;
-- otherwise the previous intent stays on ctx.intents.
function Hunter.update(ctx, slot, ship, level, state)
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

return Hunter
