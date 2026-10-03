-- The Sniper personality (docs/CONTEXT.md "Personality"): fires long,
-- gravity-corrected shots from tank mode with the shared aim-and-fire step
-- (Basic.shoot), charging to whatever power the solved shot needs -- but
-- only a solved shot (state.aim.solved), never Basic's straight-line
-- fallback. With no solved shot for config.ai.relocateDelay seconds (and
-- config.ai.takeoffFuel in the tank) it picks a vantage point with
-- src/game/ai/skills/vantage.lua, lifts off, flies above it with
-- src/game/ai/skills/flight.lua, and descends onto it. A shell or asteroid
-- that src/game/ai/skills/danger.lua senses coming makes it lift off and
-- fly across the threat's path, then relocate.
--
-- Modes on `state.mode`: "settle" (landed, no solved shot yet) <-> "shoot"
-- (landed, firing a solved shot); "relocate" (flying to `state.vantage`,
-- or landing anywhere when the pick found none); "dodge" (threatened).
-- The vantage pick (several shot solves) runs once per relocate decision,
-- never per think. Thinks every `reactionDelay` seconds and holds the
-- intent in between; levels differ only by config numbers (vantageRange,
-- predictionHorizon, dangerHorizon, flightHorizon).
local Bodies = require("src.sim.bodies")
local Lander = require("src.game.components.lander")
local Basic = require("src.game.ai.basic")
local Danger = require("src.game.ai.skills.danger")
local Flight = require("src.game.ai.skills.flight")
local Vantage = require("src.game.ai.skills.vantage")

local Sniper = {}

-- The soonest shell or asteroid threat within `horizon` seconds, or nil.
local function incoming(threats, horizon)
	for _, threat in ipairs(threats) do
		if threat.time > horizon then
			return nil
		elseif threat.kind == "shell" or threat.kind == "asteroid" then
			return threat
		end
	end
	return nil
end

local function fly(ctx, ship, body, level, goal)
	return (Flight.flyTo(ctx.sim, ctx.level.worlds, body, goal, ctx.config, {
		fuel = ship.fuel,
		hold = level.reactionDelay,
		dt = ctx.dt,
		horizon = level.flightHorizon,
	}))
end

-- A vantage point for a shot at any living enemy, or false.
local function pickVantage(ctx, ship, body, level)
	local targets = {}
	for _, other in ipairs(ctx.pools.ships) do
		local otherBody = other ~= ship and not other.dead and Bodies.get(ctx.sim.bodies, other.body)
		if otherBody then
			targets[#targets + 1] = { x = otherBody.x, y = otherBody.y, radius = otherBody.radius or 0 }
		end
	end
	return Vantage.pick(ctx.sim, ctx.level.worlds, targets, ctx.config, {
		dt = ctx.dt,
		horizon = level.predictionHorizon,
		range = level.vantageRange,
		points = ctx.level.spawnCandidates,
	}) or false
end

local function landed(ctx, ship, body, level, state)
	local config = ctx.config
	if state.mode ~= "settle" and state.mode ~= "shoot" then
		state.mode = "settle"
		state.shotAt = ctx.time
	end
	local intent = Basic.shoot(ctx, ship, body, level, state)
	if state.aim and state.aim.solved and not intent.thrust then
		state.mode = "shoot"
		state.shotAt = ctx.time
		return intent
	end
	state.mode = "settle"
	state.charging = false
	intent.fire, intent.thrust = false, false
	if ctx.time - state.shotAt >= config.ai.relocateDelay and ship.fuel.amount >= config.ai.takeoffFuel then
		state.mode = "relocate"
		state.vantage = pickVantage(ctx, ship, body, level)
		state.descending = false
		return Flight.liftOff()
	end
	return intent
end

-- Flies to vantageApproach px up the vantage point's normal, and once
-- there and slow, straight onto it (Flight.approach skips flyTo's world
-- clearance, which would refuse the touchdown).
local function relocate(ctx, ship, body, level, state, threats)
	local config = ctx.config
	state.mode = "relocate"
	state.charging = false
	if state.vantage == nil then
		state.vantage = pickVantage(ctx, ship, body, level)
		state.descending = false
	end
	local v = state.vantage
	if not v or ship.fuel.amount < config.ai.refuelFuel then
		return Flight.land(ctx.sim, body, threats, config, { fuel = ship.fuel, hold = level.reactionDelay })
	end
	local above = { x = v.x + v.normal.x * config.ai.vantageApproach, y = v.y + v.normal.y * config.ai.vantageApproach }
	local dx, dy = above.x - body.x, above.y - body.y
	local slow = body.vx * body.vx + body.vy * body.vy <= config.ai.vantageSpeed * config.ai.vantageSpeed
	if not state.descending and (not slow or dx * dx + dy * dy > config.ai.vantageArrive * config.ai.vantageArrive) then
		return fly(ctx, ship, body, level, above)
	end
	state.descending = true
	return Flight.approach(ctx.sim, body, v, config, { fuel = ship.fuel, hold = level.reactionDelay })
end

local function think(ctx, ship, body, level, state)
	local config = ctx.config
	local grounded = Lander.isGrounded(ship)
	-- Flying, the scan reaches attackClearance too, so flight never coasts
	-- into a world unseen.
	local horizon = grounded and level.dangerHorizon or math.max(level.dangerHorizon, config.ai.attackClearance)
	local threats = Danger.scan(ctx.sim, ctx.level.worlds, body, config, { dt = ctx.dt, horizon = horizon })
	local threat = incoming(threats, level.dangerHorizon)
	if threat and (not grounded or ship.fuel.amount >= config.ai.hopFuel) then
		state.mode = "dodge"
		state.vantage = nil
		state.charging = false
		if grounded then
			return Flight.liftOff()
		end
		return fly(ctx, ship, body, level, Flight.evadeGoal(ctx.sim, body, threat, config))
	end
	if grounded then
		return landed(ctx, ship, body, level, state)
	end
	return relocate(ctx, ship, body, level, state, threats)
end

-- Writes ctx.intents[slot]. Re-thinks once ctx.time reaches state.nextThink;
-- otherwise the previous intent stays on ctx.intents.
function Sniper.update(ctx, slot, ship, level, state)
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

return Sniper
