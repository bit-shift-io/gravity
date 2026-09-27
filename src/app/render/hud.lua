-- HUD: one fuel bar per player, fixed to opposite top corners of the
-- 1280x720 virtual resolution (docs/ARCHITECTURE.md "Rules"). Reads record
-- data only, never mutates it (docs/ARCHITECTURE.md "Rendering"). `love.*`
-- only -- this lives in src/app/ (docs/ARCHITECTURE.md "Layers").
local Hud = {}

local BAR_WIDTH = 200
local BAR_HEIGHT = 16
local MARGIN = 16

local PLAYER_COLOR = {
	[1] = { 0.3, 0.8, 1, 1 },
	[2] = { 1, 0.6, 0.3, 1 },
}

local function barX(player)
	if player == 1 then
		return MARGIN
	end
	return 1280 - MARGIN - BAR_WIDTH
end

local function drawFuelBar(player, fuel)
	local x = barX(player)
	local y = MARGIN
	local ratio = fuel.amount / fuel.capacity

	love.graphics.setColor(1, 1, 1, 0.3)
	love.graphics.rectangle("line", x, y, BAR_WIDTH, BAR_HEIGHT)

	love.graphics.setColor(PLAYER_COLOR[player] or { 1, 1, 1, 1 })
	love.graphics.rectangle("fill", x, y, BAR_WIDTH * math.max(0, ratio), BAR_HEIGHT)
end

function Hud.draw(ctx)
	for _, ship in ipairs(ctx.pools.ships) do
		drawFuelBar(ship.player, ship.fuel)
	end

	love.graphics.setColor(1, 1, 1, 1)
end

return Hud
