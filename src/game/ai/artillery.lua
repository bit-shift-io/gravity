-- The Artillery personality (docs/CONTEXT.md "Personality"): lands on a
-- concealed position (docs/CONTEXT.md "Concealed position", picked with
-- src/game/ai/skills/vantage.lua's concealed option) and lobs solved,
-- gravity-corrected shots (Basic.shoot) at an enemy it has no direct line
-- to. A solved shot with a direct line is held, not fired: it relocates
-- instead, on its first landed think and then every config.ai.relocateDelay
-- seconds without a concealed shot (with config.ai.takeoffFuel in the
-- tank), thrusting straight up for the level's hopTime before it steers.
-- A pick that finds nothing keeps it where it is. Its last resort is
-- the stuck rule (src/game/ai/skills/stuck.lua): with no shot fired for
-- config.ai.stuckDelay it fires whatever Basic.shoot aims -- exposed,
-- unsolved, or at the turret's limit. Dodging and flying to the pick are
-- Sniper's (src/game/ai/sniper.lua), which also hands over to Artillery
-- when its own vantage pick finds nothing.
--
-- Modes on `state.mode`: "settle" (landed, no concealed shot) <-> "shoot"
-- (landed, firing a concealed shot); "relocate"; "dodge". Thinks every
-- `reactionDelay` seconds and holds the intent in between; levels differ
-- only by config numbers (vantageRange, predictionHorizon, dangerHorizon,
-- flightHorizon, hopTime).
local Bodies = require("src.sim.bodies")
local Lander = require("src.game.components.lander")
local Basic = require("src.game.ai.basic")
local Flight = require("src.game.ai.skills.flight")
local Stuck = require("src.game.ai.skills.stuck")
local Vantage = require("src.game.ai.skills.vantage")
local Sniper = require("src.game.ai.sniper")

local Artillery = {}

local function wrap(angle)
	return (angle + math.pi) % (2 * math.pi) - math.pi
end

local function clamp(value, limit)
	return math.max(-limit, math.min(limit, value))
end

local function concealedPick(ctx, ship, level)
	return Sniper.pick(ctx, ship, level, true)
end

local function near(body, point, reach)
	local dx, dy = point.x - body.x, point.y - body.y
	return dx * dx + dy * dy <= reach * reach
end

-- The stuck shot: Basic.shoot's aim as it is, or, when the turret can't
-- reach it, kept the level's aim error inside the turret's limit.
local function stuckShot(ctx, ship, body, level, state, intent)
	if not intent.thrust then
		return intent
	end
	local limit = ctx.config.tank.turretLimit - level.aimError
	state.aim.angle = body.angle + clamp(wrap(state.aim.angle - body.angle), limit)
	state.aim.solved = false
	return Basic.shoot(ctx, ship, body, level, state)
end

local function landed(ctx, ship, body, level, state)
	local config = ctx.config
	if state.mode ~= "settle" and state.mode ~= "shoot" then
		state.mode = "settle"
		state.shotAt = ctx.time
	end
	local wasCharging = state.charging
	local intent = Basic.shoot(ctx, ship, body, level, state)
	local target = Basic.nearestEnemy(ctx, ship, body)
	local hidden = target and not Vantage.inSight(ctx.level.worlds, body, target)
	if hidden and state.aim and state.aim.solved and not intent.thrust then
		state.mode = "shoot"
		state.shotAt = ctx.time
		return intent
	end

	state.mode = "settle"
	local due = state.vantage == nil or ctx.time - state.shotAt >= config.ai.relocateDelay
	if due and ship.fuel.amount >= config.ai.takeoffFuel then
		local pick = concealedPick(ctx, ship, level)
		state.vantage = pick
		state.shotAt = ctx.time
		if pick and not near(body, pick, config.ai.vantageArrive) then
			state.mode = "relocate"
			state.descending = false
			state.charging = false
			state.liftUntil = ctx.time + level.hopTime
			return Flight.liftOff()
		end
	end
	if (wasCharging and state.charging) or Stuck.cycles(ctx, state) >= 1 then
		return stuckShot(ctx, ship, body, level, state, intent)
	end
	state.charging = false
	intent.fire, intent.thrust = false, false
	return intent
end

-- One think: also Sniper's, once it has handed over.
function Artillery.think(ctx, ship, body, level, state)
	local evade, threats = Sniper.dodge(ctx, ship, body, level, state)
	if evade then
		return evade
	end
	if state.mode == "relocate" and ctx.time < (state.liftUntil or 0) then
		return Flight.liftOff()
	end
	if Lander.isGrounded(ship) then
		return landed(ctx, ship, body, level, state)
	end
	return Sniper.relocate(ctx, ship, body, level, state, threats, concealedPick)
end

-- Writes ctx.intents[slot]. Re-thinks once ctx.time reaches state.nextThink;
-- otherwise the previous intent stays on ctx.intents.
function Artillery.update(ctx, slot, ship, level, state)
	local body = Bodies.get(ctx.sim.bodies, ship.body)
	if not body then
		return
	end
	if ctx.time >= state.nextThink then
		state.intent = Artillery.think(ctx, ship, body, level, state)
		if state.intent.fire then
			Stuck.fired(ctx, state)
		end
		state.nextThink = ctx.time + level.reactionDelay
	end
	local held = state.intent
	ctx.intents[slot] = { rotate = held.rotate, thrust = held.thrust, fire = held.fire }
end

return Artillery
