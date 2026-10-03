-- The one palette lookup: a slot's colour is config.players.palette indexed by
-- the slot's `color` in ctx.roster. Pure (no `love.*`).
local PlayerColors = {}

local WHITE = { 1, 1, 1, 1 }

function PlayerColors.get(ctx, slot)
	local entry = ctx.roster and ctx.roster[slot]
	return (entry and ctx.config.players.palette[entry.color]) or WHITE
end

return PlayerColors
