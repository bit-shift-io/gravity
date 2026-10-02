-- HUD: one fuel bar per player, fixed to opposite top corners of the
-- 1280x720 virtual resolution (docs/ARCHITECTURE.md "Rules"). Also draws
-- a charge bar under each ship while charging. Reads record data only,
-- never mutates it (docs/ARCHITECTURE.md "Rendering"). `love.*` only --
-- this lives in src/app/ (docs/ARCHITECTURE.md "Layers").
local Bodies = require("src.sim.bodies")
local Fonts = require("src.app.render.fonts")
local Hud = {}

local BAR_WIDTH = 200
local BAR_HEIGHT = 16
local MARGIN = 16
local CHARGE_BAR_WIDTH = 200
local CHARGE_BAR_HEIGHT = 6
local HUD_FONT_SIZE = 24

local PIP_RADIUS = 6
local PIP_SPACING = 18

local SCREEN_WIDTH = 1280
local SCREEN_HEIGHT = 720

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

-- Draws a fixed charge bar under the fuel bar. Shows current charge level,
-- a vertical line at the previous charge level, and the turret angle in degrees.
local function drawChargeBar(ship, ctx)
	if not ship.weapon then
		return
	end

	local barX = barX(ship.player)
	local barY = MARGIN + BAR_HEIGHT + 8  -- 8 px gap below fuel bar

	local chargeTime = ctx.config.weapon.chargeTime
	local ratio = math.min(1, ship.weapon.charge / chargeTime)

	-- Draw bar outline (always visible)
	love.graphics.setColor(1, 1, 1, 0.3)
	love.graphics.rectangle("line", barX, barY, CHARGE_BAR_WIDTH, CHARGE_BAR_HEIGHT)

	-- Draw current charge fill
	love.graphics.setColor(PLAYER_COLOR[ship.player] or { 1, 1, 1, 1 })
	love.graphics.rectangle("fill", barX, barY, CHARGE_BAR_WIDTH * ratio, CHARGE_BAR_HEIGHT)

	-- Draw previous charge line (vertical line in player color)
	if ship.weapon.prevChargeThisRound > 0 then
		local prevRatio = math.min(1, ship.weapon.prevChargeThisRound / chargeTime)
		local lineX = barX + CHARGE_BAR_WIDTH * prevRatio
		love.graphics.setColor(PLAYER_COLOR[ship.player] or { 1, 1, 1, 1 })
		love.graphics.setLineWidth(2)
		love.graphics.line(lineX, barY, lineX, barY + CHARGE_BAR_HEIGHT)
		love.graphics.setLineWidth(1)
	end

	-- Draw turret angle in degrees
	local angleText = "0"
	if ship.turret and ship.turret.angle then
		local degrees = math.deg(ship.turret.angle)
		angleText = string.format("%.0f", degrees)
	end

	love.graphics.setColor(PLAYER_COLOR[ship.player] or { 1, 1, 1, 1 })
	if ship.player == 1 then
		-- Player 1: angle text to the right of the bar
		love.graphics.setFont(Fonts.get(HUD_FONT_SIZE))
		love.graphics.print(angleText, barX + CHARGE_BAR_WIDTH + 8, barY)
	else
		-- Player 2: angle text to the left of the bar (toward center)
		local font = Fonts.get(HUD_FONT_SIZE)
		love.graphics.setFont(font)
		local textWidth = font:getWidth(angleText)
		love.graphics.print(angleText, barX - textWidth - 8, barY)
	end
end

-- One pip per round win needed: filled for each win, outlined for the rest.
-- Sits under the charge bar, growing inward from the player's screen edge.
local function drawScorePips(ctx, player)
	local total = ctx.config.round.winsToWin
	local wins = ctx.round.score[player]
	local y = MARGIN + BAR_HEIGHT + 8 + CHARGE_BAR_HEIGHT + 12
	local color = PLAYER_COLOR[player]
	for i = 1, total do
		local x
		if player == 1 then
			x = MARGIN + PIP_RADIUS + (i - 1) * PIP_SPACING
		else
			x = 1280 - MARGIN - PIP_RADIUS - (i - 1) * PIP_SPACING
		end
		love.graphics.setColor(color)
		love.graphics.circle(i <= wins and "fill" or "line", x, y, PIP_RADIUS)
	end
end

function Hud.draw(ctx)
	for player = 1, 2 do
		drawScorePips(ctx, player)
	end
	for _, ship in ipairs(ctx.pools.ships) do
		drawFuelBar(ship.player, ship.fuel)
		drawChargeBar(ship, ctx)
	end

	love.graphics.setColor(1, 1, 1, 1)
end

return Hud
