-- AI players (docs/CONTEXT.md "AI player"): a slot bound to an AI level writes
-- ctx.intents[slot] exactly as a human's input would, so ships never know the
-- difference. AI.fill(ctx) runs in Match.step's step 1. Behaviour kinds
-- register by name (binding.behavior picks any; "basic" is the fallback but
-- not in the personality pool); a kind is a table with
-- `update(ctx, slot, ship, levelConfig, state)` that writes the slot's intent.
-- Every kind then shares the airburst skill (src/game/ai/skills/airburst.lua),
-- which may override that intent's fire to remote-detonate its shell.
-- Each AI slot's personality is drawn at Match.new into ctx.personalities
-- (binding.behavior, when set, overrides it). Per-slot AI memory lives on ctx.ai[slot], never on the ship record.
local Roster = require("src.game.roster")
local Rng = require("src.core.rng")
local Airburst = require("src.game.ai.skills.airburst")

local AI = { kinds = {}, unpooled = {}, meta = {} }

-- `opts.pool = false` registers a kind a binding can name (binding.behavior)
-- but the personality draw never picks.
-- `opts.meta = true` marks a kind that wraps or switches between other
-- kinds (Chaos, Schizo); a kind that picks from the pool (Schizo's switch)
-- skips AI.meta[name] entries.
function AI.register(name, kind, opts)
	AI.kinds[name] = kind
	AI.unpooled[name] = (opts and opts.pool == false) or nil
	AI.meta[name] = (opts and opts.meta) or nil
end

AI.register("ambusher", require("src.game.ai.ambusher"))
AI.register("artillery", require("src.game.ai.artillery"))
AI.register("basic", require("src.game.ai.basic"), { pool = false })
AI.register("chaos", require("src.game.ai.chaos"), { meta = true })
AI.register("hopper", require("src.game.ai.hopper"))
AI.register("hunter", require("src.game.ai.hunter"))
AI.register("kamikaze", require("src.game.ai.kamikaze"))
AI.register("schizo", require("src.game.ai.schizo"), { meta = true })
AI.register("skirmisher", require("src.game.ai.skirmisher"))
AI.register("sniper", require("src.game.ai.sniper"))

-- The personality pool: every registered kind name not registered with
-- `pool = false`, sorted so the same seed draws the same names whatever the
-- registration order.
function AI.pool()
	local names = {}
	for name in pairs(AI.kinds) do
		if not AI.unpooled[name] then
			names[#names + 1] = name
		end
	end
	table.sort(names)
	return names
end

-- Draws one personality per AI slot from the pool; human slots get none. The
-- rng is derived from `seed` and the slot, never ctx.rng (a draw from that
-- would shift level generation and asteroid spawns). An LCG's first outputs
-- for neighbouring seeds are near-identical, so a few are discarded.
function AI.draw(seed, roster)
	local pool = AI.pool()
	local personalities = {}
	for slot = 1, #roster do
		if not Roster.isHuman(roster, slot) then
			local rng = Rng.new(seed * 7919 + slot * 104729 + 17)
			for _ = 1, 3 do
				rng:next()
			end
			personalities[slot] = pool[rng:int(1, #pool)]
		end
	end
	return personalities
end

local function livingShip(ctx, slot)
	for _, ship in ipairs(ctx.pools.ships) do
		if ship.player == slot and not ship.dead then
			return ship
		end
	end
	return nil
end

function AI.neutral()
	return { rotate = 0, thrust = false, fire = false }
end

function AI.fill(ctx)
	ctx.ai = ctx.ai or {}
	ctx.personalities = ctx.personalities or {}
	for slot, entry in ipairs(ctx.roster) do
		if not Roster.isHuman(ctx.roster, slot) then
			local binding = entry.binding
			local ship = livingShip(ctx, slot)
			if not ship then
				ctx.intents[slot] = AI.neutral()
				ctx.ai[slot] = nil
			else
				local state = ctx.ai[slot]
				if not state or state.ship ~= ship then
					state = { ship = ship, nextThink = 0 }
					ctx.ai[slot] = state
				end
				local kind = AI.kinds[binding.behavior or ctx.personalities[slot] or "basic"]
				kind.update(ctx, slot, ship, ctx.config.ai.levels[binding.level], state)
				Airburst.update(ctx, slot, ship, state)
			end
		end
	end
end

return AI
