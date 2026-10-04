-- The Ambusher personality (docs/CONTEXT.md "Personality"): waits landed
-- and still, out of sight. Landing first with a direct line to the nearest
-- enemy, it moves once to a concealed position (Artillery's pick,
-- docs/CONTEXT.md "Concealed position", here about
-- config.ai.ambushHideRange px from an enemy). With an enemy within
-- config.ai.ambushRange px it lifts off (climbing straight out for the
-- level's hopTime), flies for the Hunter's standoff point over it
-- (Hunter.standoffGoal) and fires from the air with the shared
-- aim-and-fire step (Basic.shoot) -- a solved shot only, unless stuck.
-- Once no enemy is in range (or fuel runs below config.ai.refuelFuel) it
-- flies back to a concealed position and lands (Sniper.relocate). Waiting
-- is how it would stall, so the stuck rule (src/game/ai/skills/stuck.lua:
-- no shot for config.ai.stuckDelay) sends it out to strike the nearest
-- enemy wherever it is, taking Basic's best aimed shot, solved or not.
-- Dodging is Sniper's (Sniper.dodge).
--
-- Modes on `state.mode`: "hide" (landed, waiting), "strike" (in the air
-- after an enemy), "return" (flying back to hide), "dodge". Thinks every
-- `reactionDelay` seconds and holds the intent in between; levels differ
-- only by config numbers (predictionHorizon, dangerHorizon, flightHorizon,
-- hopTime). Tolerates a fresh, empty state at any time
-- (Schizo's switch).
local Bodies = require("src.sim.bodies")
local Lander = require("src.game.components.lander")
local Basic = require("src.game.ai.basic")
local Danger = require("src.game.ai.skills.danger")
local Flight = require("src.game.ai.skills.flight")
local Stuck = require("src.game.ai.skills.stuck")
local Vantage = require("src.game.ai.skills.vantage")
local Sniper = require("src.game.ai.sniper")
local Hunter = require("src.game.ai.hunter")

local Ambusher = {}

local IMPACT = { world = true, boundary = true }

-- A concealed position about config.ai.ambushHideRange px from an enemy,
-- well outside ambushRange.
local function concealedPick(ctx, ship, level)
	local far = setmetatable({ vantageRange = ctx.config.ai.ambushHideRange }, { __index = level })
	return Sniper.pick(ctx, ship, far, true)
end

local function liftOff(ctx, level, state, mode)
	state.mode = mode
	state.charging = false
	state.liftUntil = ctx.time + level.hopTime
	return Flight.liftOff()
end

local function hide(ctx, ship, body, level, state, target)
	local config = ctx.config
	if not state.hideTried and target and Vantage.inSight(ctx.level.worlds, body, target)
		and ship.fuel.amount >= config.ai.takeoffFuel then
		state.hideTried = true
		local pick = concealedPick(ctx, ship, level)
		if pick and not Basic.near(body, pick, config.ai.vantageArrive) then
			state.vantage, state.descending = pick, false
			return liftOff(ctx, level, state, "return")
		end
	end
	state.hideTried = true
	state.mode = "hide"
	state.charging = false
	return { rotate = 0, thrust = false, fire = false }
end

-- In the air after `target`: a solved shot when one lines up (any aimed
-- shot when stuck), else circling it.
local function strike(ctx, ship, body, level, state, target, threats)
	state.mode = "strike"
	local clear = not Danger.firstOf(threats, IMPACT, ctx.config.ai.attackClearance)
	local shellAlive = ship.weapon and ship.weapon.shell and Bodies.get(ctx.sim.bodies, ship.weapon.shell)
	if clear and (state.charging or not shellAlive) then
		local intent = Basic.shoot(ctx, ship, body, level, state)
		if state.aim and state.aim.solved or Stuck.cycles(ctx, state) >= 1 then
			return intent
		end
	end
	state.charging = false
	return Flight.flyWith(ctx, ship, body, level, Hunter.standoffGoal(ctx, body, target))
end

local function think(ctx, ship, body, level, state)
	local config = ctx.config
	local evade, threats = Sniper.dodge(ctx, ship, body, level, state)
	if evade then
		return evade
	end
	if ctx.time < (state.liftUntil or 0) then
		return Flight.liftOff()
	end

	local target = Basic.nearestEnemy(ctx, ship, body)
	local wanted = target and (target.dist <= config.ai.ambushRange or Stuck.cycles(ctx, state) >= 1)
	if Lander.isGrounded(ship) then
		if wanted and ship.fuel.amount >= config.ai.refuelFuel then
			return liftOff(ctx, level, state, "strike")
		end
		return hide(ctx, ship, body, level, state, target)
	end

	if wanted and ship.fuel.amount >= config.ai.refuelFuel then
		state.vantage = nil
		return strike(ctx, ship, body, level, state, target, threats)
	end
	local intent = Sniper.relocate(ctx, ship, body, level, state, threats, concealedPick)
	state.mode = "return"
	return intent
end

-- Writes ctx.intents[slot]. Re-thinks once ctx.time reaches state.nextThink;
-- otherwise the previous intent stays on ctx.intents.
function Ambusher.update(ctx, slot, ship, level, state)
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

return Ambusher
