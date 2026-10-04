-- The Schizo personality (docs/CONTEXT.md "Personality"): plays one pool
-- personality at a time and switches to a different one each time it
-- launches a shot (a new shell on its weapon, not a charge start). The
-- switch target is never a meta kind (Schizo, Chaos). A switch clears the
-- slot's AI memory (ctx.ai[slot]) in place, keeping the ship, the airburst
-- track and the stuck clock, so the new personality starts fresh with the
-- shell still in flight.
-- Its own memory lives on ctx.schizo[slot] rather than ctx.ai[slot]: AI.fill
-- drops ctx.ai[slot] when the ship dies, and the score card still names the
-- personality being played. Randomness comes from an rng derived from
-- ctx.seed and the slot, never ctx.rng (docs/memory/
-- personality-draw-uses-its-own-rng.md).
local Rng = require("src.core.rng")

local Schizo = {}

-- Fields of ctx.ai[slot] that belong to the slot, not the personality.
local KEEP = { ship = true, airburst = true, firedAt = true }

-- Pool personalities that are not meta kinds and not `except`, sorted.
local function targets(except)
	-- Lazy: src.game.ai.init requires this module.
	local AI = require("src.game.ai.init")
	local names = {}
	for _, name in ipairs(AI.pool()) do
		if not AI.meta[name] and name ~= except then
			names[#names + 1] = name
		end
	end
	return names
end

local function pick(rng, except)
	local names = targets(except)
	return names[rng:int(1, #names)]
end

local function newMemory(ctx, slot)
	local rng = Rng.new(ctx.seed * 7919 + slot * 104729 + 7001)
	for _ = 1, 3 do
		rng:next()
	end
	return { rng = rng, current = pick(rng), switches = 0 }
end

local function reset(state)
	for key in pairs(state) do
		if not KEEP[key] then
			state[key] = nil
		end
	end
	state.nextThink = 0
end

-- Switches personality when a new shell has launched since the last call,
-- then lets the current personality write ctx.intents[slot].
function Schizo.update(ctx, slot, ship, level, state)
	ctx.schizo = ctx.schizo or {}
	local memory = ctx.schizo[slot] or newMemory(ctx, slot)
	ctx.schizo[slot] = memory
	local shell = ship.weapon and ship.weapon.shell
	if shell and shell ~= memory.shell then
		memory.current = pick(memory.rng, memory.current)
		memory.switches = memory.switches + 1
		reset(state)
	end
	memory.shell = shell or memory.shell
	require("src.game.ai.init").kinds[memory.current].update(ctx, slot, ship, level, state)
end

return Schizo
