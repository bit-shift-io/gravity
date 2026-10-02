-- Match-over overlay: winner, final pips and a rematch prompt, drawn in
-- screen space (virtual 1280x720) while the match is over. The text helpers
-- are pure; only `draw` touches `love.*` (docs/ARCHITECTURE.md "Layers").
local RoundSystem = require("src.game.systems.round_system")
local ScoreCard = require("src.app.render.score_card")
local Fonts = require("src.app.render.fonts")

local MatchOver = {}

local SCREEN_WIDTH = 1280
local SCREEN_HEIGHT = 720
local PIP_RADIUS = 8
local PIP_SPACING = 24
local GROUP_GAP = 80
local TITLE_SIZE = 56
local LABEL_SIZE = 32
local PROMPT_SIZE = 28

local PLAYER_COLOR = {
	[1] = { 0.3, 0.8, 1, 1 },
	[2] = { 1, 0.6, 0.3, 1 },
}

function MatchOver.title(winner)
	return "P" .. winner .. " WINS THE MATCH"
end

function MatchOver.prompt()
	return "PRESS ENTER FOR A REMATCH"
end

function MatchOver.draw(ctx)
	if not RoundSystem.matchOver(ctx.round) then
		return
	end

	local titleFont = Fonts.get(TITLE_SIZE)
	local labelFont = Fonts.get(LABEL_SIZE)
	local promptFont = Fonts.get(PROMPT_SIZE)
	local title = MatchOver.title(ctx.round.winner)
	local titleWidth = titleFont:getWidth(title)

	love.graphics.setColor(0, 0, 0, 0.7)
	love.graphics.rectangle("fill", 0, SCREEN_HEIGHT / 2 - 110, SCREEN_WIDTH, 240)

	love.graphics.setColor(PLAYER_COLOR[ctx.round.winner])
	love.graphics.setFont(titleFont)
	love.graphics.print(title, (SCREEN_WIDTH - titleWidth) / 2, SCREEN_HEIGHT / 2 - 80)

	local total = ctx.config.round.winsToWin
	local labelWidth = labelFont:getWidth("P1 ")
	local width = (total - 1) * PIP_SPACING + PIP_RADIUS * 2
	local x = (SCREEN_WIDTH - (2 * (labelWidth + width) + GROUP_GAP)) / 2
	local y = SCREEN_HEIGHT / 2 + 20
	for player = 1, 2 do
		love.graphics.setColor(PLAYER_COLOR[player])
		love.graphics.setFont(labelFont)
		love.graphics.print("P" .. player, x, y - labelFont:getHeight() / 2)
		local pipX = x + labelWidth + PIP_RADIUS
		for i, filled in ipairs(ScoreCard.pips(ctx.round.score[player], total)) do
			love.graphics.circle(filled and "fill" or "line", pipX + (i - 1) * PIP_SPACING, y, PIP_RADIUS)
		end
		x = x + labelWidth + width + GROUP_GAP
	end

	local prompt = MatchOver.prompt()
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.setFont(promptFont)
	love.graphics.print(prompt, (SCREEN_WIDTH - promptFont:getWidth(prompt)) / 2, SCREEN_HEIGHT / 2 + 70)
end

return MatchOver
