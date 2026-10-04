-- The Sniper personality (docs/CONTEXT.md "Personality"): fires long,
-- gravity-corrected shots from tank mode with the shared aim-and-fire step
-- (Basic.shoot), charging to whatever power the solved shot needs -- but
-- only a solved shot (state.aim.solved), never Basic's straight-line
-- fallback. With no solved shot for config.ai.relocateDelay seconds (and
-- config.ai.takeoffFuel in the tank) it picks a vantage point with
-- src/game/ai/skills/vantage.lua, lifts off, flies above it with
-- src/game/ai/skills/flight.lua, and descends onto it. A shell or asteroid
-- that src/game/ai/skills/danger.lua senses coming makes it lift off and
-- fly across the threat's path, then relocate. When a vantage pick finds
-- nothing it hands over to Artillery (src/game/ai/artillery.lua) for the
-- rest of the ship's life (`state.handover`), which looks for a concealed
-- position instead and falls back on the stuck rule.
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
local Stuck = require("src.game.ai.skills.stuck")

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

-- A vantage point for a shot at any living enemy, or false. `concealed`
-- asks for a concealed position instead (Vantage.pick's option).
function Sniper.pick(ctx, ship, level, concealed)
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
		concealed = concealed,
	}) or false
end

-- Artillery takes over this think and every later one (Sniper.update).
local function handOver(ctx, ship, body, level, state)
	state.handover = true
	state.vantage = nil
	return require("src.game.ai.artillery").think(ctx, ship, body, level, state)
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
		local vantage = Sniper.pick(ctx, ship, level)
		if not vantage then
			return handOver(ctx, ship, body, level, state)
		end
		state.mode = "relocate"
		state.vantage = vantage
		state.descending = false
		return Flight.liftOff()
	end
	return intent
end

-- Flies to vantageApproach px up the vantage point's normal, and once
-- there and slow, straight onto it (Flight.approach skips flyTo's world
-- clearance, which would refuse the touchdown). With no point picked yet it
-- picks one with `pick(ctx, ship, level)`; a false pick lands anywhere.
-- Shared with Artillery.
function Sniper.relocate(ctx, ship, body, level, state, threats, pick)
	local config = ctx.config
	state.mode = "relocate"
	state.charging = false
	if state.vantage == nil then
		state.vantage = pick(ctx, ship, level)
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

-- The dodge every relocating personality shares: an intent when a sensed
-- threat makes it lift off or fly clear, else nil. Also returns the
-- scanned threats.
function Sniper.dodge(ctx, ship, body, level, state)
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
		return fly(ctx, ship, body, level, Flight.evadeGoal(ctx.sim, body, threat, config)), threats
	end
	return nil, threats
end

local function think(ctx, ship, body, level, state)
	local evade, threats = Sniper.dodge(ctx, ship, body, level, state)
	if evade then
		return evade
	end
	if Lander.isGrounded(ship) then
		return landed(ctx, ship, body, level, state)
	end
	if state.vantage == nil then
		local vantage = Sniper.pick(ctx, ship, level)
		if not vantage then
			return handOver(ctx, ship, body, level, state)
		end
		state.vantage, state.descending = vantage, false
	end
	return Sniper.relocate(ctx, ship, body, level, state, threats, Sniper.pick)
end

-- Writes ctx.intents[slot]. Re-thinks once ctx.time reaches state.nextThink;
-- otherwise the previous intent stays on ctx.intents.
function Sniper.update(ctx, slot, ship, level, state)
	if state.handover then
		return require("src.game.ai.artillery").update(ctx, slot, ship, level, state)
	end
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

return Sniper
