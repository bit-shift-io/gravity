-- Score card overlay: centred result text and score pips, drawn in screen
-- space over the 1280x720 virtual resolution (unaffected by camera zoom)
-- while RoundSystem.cardVisible says so. The text/pip helpers are pure; only
-- `draw` touches `love.*` (docs/ARCHITECTURE.md "Layers").
local RoundSystem = require("src.game.systems.round_system")

local ScoreCard = {}

local SCREEN_WIDTH = 1280
local SCREEN_HEIGHT = 720
local PIP_RADIUS = 8
local PIP_SPACING = 24
local GROUP_GAP = 80
local TITLE_SCALE = 4

local PLAYER_COLOR = {
	[1] = { 0.3, 0.8, 1, 1 },
	[2] = { 1, 0.6, 0.3, 1 },
}

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

function ScoreCard.draw(ctx)
	if not RoundSystem.cardVisible(ctx.round, ctx.config.round) then
		return
	end

	local font = love.graphics.getFont()
	local title = ScoreCard.resultText(ctx.round.result)
	local titleWidth = font:getWidth(title) * TITLE_SCALE
	local titleY = SCREEN_HEIGHT / 2 - 60

	love.graphics.setColor(0, 0, 0, 0.6)
	love.graphics.rectangle("fill", 0, SCREEN_HEIGHT / 2 - 90, SCREEN_WIDTH, 180)

	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.print(title, (SCREEN_WIDTH - titleWidth) / 2, titleY, 0, TITLE_SCALE, TITLE_SCALE)

	-- "P1 ●●○  P2 ●○○": a label then pips per player, the pair centred.
	local total = ctx.config.round.winsToWin
	local labelWidth = font:getWidth("P1 ") * 2
	local width = groupWidth(total)
	local x = (SCREEN_WIDTH - (2 * (labelWidth + width) + GROUP_GAP)) / 2
	local y = SCREEN_HEIGHT / 2 + 40
	for player = 1, 2 do
		love.graphics.setColor(PLAYER_COLOR[player])
		love.graphics.print("P" .. player, x, y - font:getHeight(), 0, 2, 2)
		local pipX = x + labelWidth + PIP_RADIUS
		for i, filled in ipairs(ScoreCard.pips(ctx.round.score[player], total)) do
			love.graphics.circle(filled and "fill" or "line", pipX + (i - 1) * PIP_SPACING, y, PIP_RADIUS)
		end
		x = x + labelWidth + width + GROUP_GAP
	end

	love.graphics.setColor(1, 1, 1, 1)
end

return ScoreCard
