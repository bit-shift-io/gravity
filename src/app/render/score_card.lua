-- Score card overlay: centred result text and score pips, drawn in screen
-- space over the 1280x720 virtual resolution (unaffected by camera zoom)
-- while RoundSystem.cardVisible says so. The text/pip helpers are pure; only
-- `draw` touches `love.*` (docs/ARCHITECTURE.md "Layers").
local RoundSystem = require("src.game.systems.round_system")
local Fonts = require("src.app.render.fonts")
local PlayerColors = require("src.app.render.player_colors")

local ScoreCard = {}

local SCREEN_WIDTH = 1280
local SCREEN_HEIGHT = 720
local PIP_RADIUS = 8
local PIP_SPACING = 24
local ROW_HEIGHT = 40
local TITLE_SIZE = 64
local LABEL_SIZE = 32
local PANEL_PAD = 20
local TITLE_BLOCK = 100 -- panel top to the first score row

function ScoreCard.resultText(result)
	if result.draw then
		return "DRAW"
	end
	return "P" .. result.winner .. " WINS"
end

-- One boolean per pip: filled for each win, empty for the rest.
function ScoreCard.pips(wins, total)
	local pips = {}
	for i = 1, total do
		pips[i] = i <= wins
	end
	return pips
end

local function groupWidth(total)
	return (total - 1) * PIP_SPACING + PIP_RADIUS * 2
end

-- Slot indexes ordered by wins, most first; ties keep slot order. Pure, and
-- leaves `score` alone.
function ScoreCard.sortedSlots(score)
	local order = {}
	for slot = 1, #score do
		order[slot] = slot
	end
	table.sort(order, function(a, b)
		if score[a] ~= score[b] then
			return score[a] > score[b]
		end
		return a < b
	end)
	return order
end

-- Height of the stacked score list for `count` slots. Pure.
function ScoreCard.listHeight(count)
	return count * ROW_HEIGHT
end

-- "P3 ●●○" one row per slot, stacked from `top` and sorted by wins (most at
-- the top). Rows share one left edge so the pips line up, and the block is
-- centred on the screen. Shared by the score card and the match-over screen.
function ScoreCard.drawScores(ctx, top)
	local total = ctx.config.round.winsToWin
	local labelFont = Fonts.get(LABEL_SIZE)
	local labelWidth = labelFont:getWidth("P6 ")
	local left = (SCREEN_WIDTH - (labelWidth + groupWidth(total))) / 2
	love.graphics.setFont(labelFont)
	for row, player in ipairs(ScoreCard.sortedSlots(ctx.round.score)) do
		local y = top + (row - 0.5) * ROW_HEIGHT
		love.graphics.setColor(PlayerColors.get(ctx, player))
		love.graphics.print("P" .. player, left, y - labelFont:getHeight() / 2)
		local pipX = left + labelWidth + PIP_RADIUS
		for i, filled in ipairs(ScoreCard.pips(ctx.round.score[player], total)) do
			love.graphics.circle(filled and "fill" or "line", pipX + (i - 1) * PIP_SPACING, y, PIP_RADIUS)
		end
	end
end

function ScoreCard.draw(ctx)
	if not RoundSystem.cardVisible(ctx.round, ctx.config.round) then
		return
	end

	local titleFont = Fonts.get(TITLE_SIZE)
	local title = ScoreCard.resultText(ctx.round.result)
	local titleWidth = titleFont:getWidth(title)
	local listHeight = ScoreCard.listHeight(#ctx.round.score)
	local panelHeight = TITLE_BLOCK + listHeight + PANEL_PAD
	local panelTop = (SCREEN_HEIGHT - panelHeight) / 2

	love.graphics.setColor(0, 0, 0, 0.6)
	love.graphics.rectangle("fill", 0, panelTop, SCREEN_WIDTH, panelHeight)

	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.setFont(titleFont)
	love.graphics.print(title, (SCREEN_WIDTH - titleWidth) / 2, panelTop + PANEL_PAD)

	ScoreCard.drawScores(ctx, panelTop + TITLE_BLOCK)

	love.graphics.setColor(1, 1, 1, 1)
end

return ScoreCard
