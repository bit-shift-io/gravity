-- AI players (docs/CONTEXT.md "AI player"): a slot bound to an AI level writes
-- ctx.intents[slot] exactly as a human's input would, so ships never know the
-- difference. AI.fill(ctx) runs in Match.step's step 1. Behaviour kinds
-- register by name (binding.behavior, default "basic"); a kind is a table with
-- `update(ctx, slot, ship, levelConfig, state)` that writes the slot's intent.
-- Per-slot AI memory lives on ctx.ai[slot], never on the ship record.
local Roster = require("src.game.roster")

local AI = { kinds = {} }

function AI.register(name, kind)
	AI.kinds[name] = kind
end

AI.register("basic", require("src.game.ai.basic"))

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
				local kind = AI.kinds[binding.behavior or "basic"]
				kind.update(ctx, slot, ship, ctx.config.ai.levels[binding.level], state)
			end
		end
	end
end

return AI
