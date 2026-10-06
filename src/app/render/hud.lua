-- HUD: one block per human slot, fixed to the screen corners of the
-- 1280x720 virtual resolution (docs/ARCHITECTURE.md "Rules"). Also draws
-- a charge bar under each ship while charging. Reads record data only,
-- never mutates it (docs/ARCHITECTURE.md "Rendering"). `love.*` only --
-- this lives in src/app/ (docs/ARCHITECTURE.md "Layers").
local Fonts = require("src.app.render.fonts")
local PlayerColors = require("src.app.render.player_colors")
local Roster = require("src.game.roster")
local Hud = {}

local BAR_WIDTH = 200
local BAR_HEIGHT = 16
local MARGIN = 16
local CHARGE_BAR_HEIGHT = 6
local HUD_FONT_SIZE = 24

local PIP_RADIUS = 6
local PIP_SPACING = 18

local SCREEN_WIDTH = 1280
local SCREEN_HEIGHT = 720

-- Each human's block (fuel bar, charge bar, pips) takes a screen corner in
-- human order: top-left, top-right, bottom-left, bottom-right. AI slots get
-- no block. `top` is the block's top edge; the block grows downward from it.
Hud.BLOCK_HEIGHT = MARGIN + BAR_HEIGHT + 8 + CHARGE_BAR_HEIGHT + 12 + PIP_RADIUS * 2 - MARGIN

-- Up to four blocks keep the corner layout. Five or six squeeze into one
-- row along the top: narrower bars and a small gap so each block (bar plus
-- the turret-angle text beside the charge bar) still fits.
local MAX_CORNER_BLOCKS = 4
local ANGLE_TEXT_RESERVE = 8 + 56 -- gap to the bar plus room for "-180"
local ROW_GAP = 8

local function rowBarWidth(count)
	local slot = (SCREEN_WIDTH - 2 * MARGIN - (count - 1) * ROW_GAP) / count
	return math.floor(slot - ANGLE_TEXT_RESERVE)
end

function Hud.blockLayout(index, count)
	count = count or MAX_CORNER_BLOCKS
	if count > MAX_CORNER_BLOCKS then
		local barWidth = rowBarWidth(count)
		local width = barWidth + ANGLE_TEXT_RESERVE
		return {
			left = true,
			top = MARGIN,
			x = MARGIN + (index - 1) * (width + ROW_GAP),
			barWidth = barWidth,
			width = width,
		}
	end
	local row = math.ceil(index / 2)
	local left = index % 2 == 1
	return {
		left = left,
		top = row == 1 and MARGIN or SCREEN_HEIGHT - MARGIN - Hud.BLOCK_HEIGHT,
		x = left and MARGIN or SCREEN_WIDTH - MARGIN - BAR_WIDTH,
		barWidth = BAR_WIDTH,
		width = BAR_WIDTH + ANGLE_TEXT_RESERVE,
	}
end

-- One { slot, layout } per slot of the chosen set, in slot order: "humans"
-- (default) or "all" slots.
function Hud.blocks(roster, which)
	local slots = {}
	if which == "all" then
		for slot = 1, #roster do
			slots[slot] = slot
		end
	else
		slots = Roster.humans(roster)
	end
	local blocks = {}
	for index, slot in ipairs(slots) do
		blocks[index] = { slot = slot, layout = Hud.blockLayout(index, #slots) }
	end
	return blocks
end

function Hud.humanBlocks(roster)
	return Hud.blocks(roster, "humans")
end

local function barX(layout)
	return layout.x
end

local function drawFuelBar(color, layout, fuel)
	local x = barX(layout)
	local y = layout.top
	local ratio = fuel.amount / fuel.capacity

	love.graphics.setColor(1, 1, 1, 0.3)
	love.graphics.rectangle("line", x, y, layout.barWidth, BAR_HEIGHT)

	love.graphics.setColor(color)
	love.graphics.rectangle("fill", x, y, layout.barWidth * math.max(0, ratio), BAR_HEIGHT)
end

-- Draws a fixed charge bar under the fuel bar. Shows current charge level,
-- a vertical line at the previous charge level, and the turret angle in degrees.
local function drawChargeBar(ship, ctx, color, layout)
	if not ship.weapon then
		return
	end

	local barX = barX(layout)
	local barY = layout.top + BAR_HEIGHT + 8  -- 8 px gap below fuel bar

	local chargeTime = ctx.config.weapon.chargeTime
	local ratio = math.min(1, ship.weapon.charge / chargeTime)

	-- Draw bar outline (always visible)
	love.graphics.setColor(1, 1, 1, 0.3)
	love.graphics.rectangle("line", barX, barY, layout.barWidth, CHARGE_BAR_HEIGHT)

	-- Draw current charge fill
	love.graphics.setColor(color)
	love.graphics.rectangle("fill", barX, barY, layout.barWidth * ratio, CHARGE_BAR_HEIGHT)

	-- Draw previous charge line (vertical line in player color)
	if ship.weapon.prevChargeThisRound > 0 then
		local prevRatio = math.min(1, ship.weapon.prevChargeThisRound / chargeTime)
		local lineX = barX + layout.barWidth * prevRatio
		love.graphics.setColor(color)
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

	love.graphics.setColor(color)
	if layout.left then
		-- Left block: angle text to the right of the bar
		love.graphics.setFont(Fonts.get(HUD_FONT_SIZE))
		love.graphics.print(angleText, barX + layout.barWidth + 8, barY)
	else
		-- Right block: angle text to the left of the bar (toward center)
		local font = Fonts.get(HUD_FONT_SIZE)
		love.graphics.setFont(font)
		local textWidth = font:getWidth(angleText)
		love.graphics.print(angleText, barX - textWidth - 8, barY)
	end
end

-- One pip per round win needed: filled for each win, outlined for the rest.
-- Sits under the charge bar, growing inward from the player's screen edge.
local function drawScorePips(ctx, player, color, layout)
	local total = ctx.config.round.winsToWin
	local wins = ctx.round.score[player]
	local y = layout.top + BAR_HEIGHT + 8 + CHARGE_BAR_HEIGHT + 12
	for i = 1, total do
		local x
		if layout.left then
			x = layout.x + PIP_RADIUS + (i - 1) * PIP_SPACING
		else
			x = layout.x + layout.barWidth - PIP_RADIUS - (i - 1) * PIP_SPACING
		end
		love.graphics.setColor(color)
		love.graphics.circle(i <= wins and "fill" or "line", x, y, PIP_RADIUS)
	end
end

-- opts.slots: "humans" (default) or "all" to draw a block for every slot.
function Hud.draw(ctx, opts)
	local shipsBySlot = {}
	for _, ship in ipairs(ctx.pools.ships) do
		if not ship.dead or not shipsBySlot[ship.player] then
			shipsBySlot[ship.player] = ship
		end
	end
	for _, block in ipairs(Hud.blocks(ctx.roster, opts and opts.slots)) do
		local color = PlayerColors.get(ctx, block.slot)
		drawScorePips(ctx, block.slot, color, block.layout)
		local ship = shipsBySlot[block.slot]
		if ship then
			drawFuelBar(color, block.layout, ship.fuel)
			drawChargeBar(ship, ctx, color, block.layout)
		end
	end

	love.graphics.setColor(1, 1, 1, 1)
end

return Hud
