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
local GROUP_GAP = 80
local SIDE_MARGIN = 40
local TITLE_SIZE = 64
local LABEL_SIZE = 32

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

-- Gap between slot groups: the usual gap, tightened so `count` groups of
-- `width` plus labels still fit the screen. Pure.
function ScoreCard.groupGap(count, groupSpan)
	if count < 2 then
		return GROUP_GAP
	end
	return math.min(GROUP_GAP, (SCREEN_WIDTH - 2 * SIDE_MARGIN - count * groupSpan) / (count - 1))
end

-- "P1 ●●○  P2 ●○○ ...": a label then pips for every slot, the row centred at
-- height `y`. Shared by the score card and the match-over screen.
function ScoreCard.drawScores(ctx, y)
	local total = ctx.config.round.winsToWin
	local labelFont = Fonts.get(LABEL_SIZE)
	local count = #ctx.round.score
	local labelWidth = labelFont:getWidth("P1 ")
	local span = labelWidth + groupWidth(total)
	local gap = ScoreCard.groupGap(count, span)
	local x = (SCREEN_WIDTH - (count * span + (count - 1) * gap)) / 2
	for player = 1, count do
		love.graphics.setColor(PlayerColors.get(ctx, player))
		love.graphics.setFont(labelFont)
		love.graphics.print("P" .. player, x, y - labelFont:getHeight() / 2)
		local pipX = x + labelWidth + PIP_RADIUS
		for i, filled in ipairs(ScoreCard.pips(ctx.round.score[player], total)) do
			love.graphics.circle(filled and "fill" or "line", pipX + (i - 1) * PIP_SPACING, y, PIP_RADIUS)
		end
		x = x + span + gap
	end
end

function ScoreCard.draw(ctx)
	if not RoundSystem.cardVisible(ctx.round, ctx.config.round) then
		return
	end

	local titleFont = Fonts.get(TITLE_SIZE)
	local title = ScoreCard.resultText(ctx.round.result)
	local titleWidth = titleFont:getWidth(title)
	local titleY = SCREEN_HEIGHT / 2 - 60

	love.graphics.setColor(0, 0, 0, 0.6)
	love.graphics.rectangle("fill", 0, SCREEN_HEIGHT / 2 - 90, SCREEN_WIDTH, 180)

	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.setFont(titleFont)
	love.graphics.print(title, (SCREEN_WIDTH - titleWidth) / 2, titleY)

	ScoreCard.drawScores(ctx, SCREEN_HEIGHT / 2 + 40)

	love.graphics.setColor(1, 1, 1, 1)
end

return ScoreCard
