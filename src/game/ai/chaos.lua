-- The Chaos personality (docs/CONTEXT.md "Personality"): a Hunter core with
-- random actions injected over its intent. Every config.ai.chaosInterval
-- seconds it rolls config.ai.chaosRate; on a hit it picks one action that
-- fits the moment and holds it config.ai.chaosHold seconds:
--   "thrust"  -- a thrust burst (airborne)
--   "liftoff" -- lift off (grounded)
--   "shot"    -- a shot in a random direction (no live shell)
--   "detonate" -- a fire press on its own armed shell
-- Randomness comes from an rng derived from ctx.seed and the slot, kept on
-- state.chaos (ctx.ai[slot]), never ctx.rng (docs/memory/
-- personality-draw-uses-its-own-rng.md). Registered as a meta kind, so a
-- switching personality leaves it out of its pool.
local Bodies = require("src.sim.bodies")
local Rng = require("src.core.rng")
local Lander = require("src.game.components.lander")
local Hunter = require("src.game.ai.hunter")
local Stuck = require("src.game.ai.skills.stuck")

local Chaos = {}

local function newChaos(ctx, slot)
	local rng = Rng.new(ctx.seed * 7919 + slot * 104729 + 5003)
	for _ = 1, 3 do
		rng:next()
	end
	return { rng = rng, nextRoll = ctx.time, rolls = 0, injected = 0 }
end

local function options(ctx, ship)
	local weapon = ship.weapon
	local shell = weapon and weapon.shell and Bodies.get(ctx.sim.bodies, weapon.shell)
	local list = { Lander.isGrounded(ship) and "liftoff" or "thrust" }
	if not shell then
		list[#list + 1] = "shot"
	elseif shell.armed then
		list[#list + 1] = "detonate"
	end
	return list
end

local function roll(ctx, ship, state)
	local chaos = state.chaos
	local config = ctx.config.ai
	chaos.nextRoll = ctx.time + config.chaosInterval
	chaos.rolls = chaos.rolls + 1
	if chaos.rng:next() >= config.chaosRate then
		return
	end
	local list = options(ctx, ship)
	local kind = list[chaos.rng:int(1, #list)]
	chaos.injected = chaos.injected + 1
	chaos.action = {
		kind = kind,
		until_ = ctx.time + config.chaosHold,
		rotate = chaos.rng:next() < 0.5 and -1 or 1,
	}
	if kind == "shot" then
		Stuck.fired(ctx, state)
	end
end

local function apply(ctx, ship, intent, action)
	if action.kind == "thrust" or action.kind == "liftoff" then
		intent.thrust = true
	elseif action.kind == "shot" then
		intent.rotate = action.rotate
		intent.fire = true
	elseif action.kind == "detonate" then
		local weapon = ship.weapon
		local shell = weapon and weapon.shell and Bodies.get(ctx.sim.bodies, weapon.shell)
		if shell and shell.armed and not weapon.prevFire then
			intent.fire = true
			return false
		end
		-- Fire is still held (releases this step) or the shell is gone.
		return shell ~= nil
	end
	return true
end

-- Writes ctx.intents[slot]: the Hunter's intent with any active chaos
-- action laid over it.
function Chaos.update(ctx, slot, ship, level, state)
	Hunter.update(ctx, slot, ship, level, state)
	state.chaos = state.chaos or newChaos(ctx, slot)
	local chaos = state.chaos
	if ctx.time >= chaos.nextRoll then
		roll(ctx, ship, state)
	end
	local action = chaos.action
	if action and ctx.time >= action.until_ then
		chaos.action = nil
		action = nil
	end
	if action then
		local intent = ctx.intents[slot]
		if not apply(ctx, ship, intent, action) then
			chaos.action = nil
		end
	end
end

return Chaos
