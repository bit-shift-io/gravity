-- Match-over overlay: winner, final pips and a rematch prompt, drawn in
-- screen space (virtual 1280x720) while the match is over. The text helpers
-- are pure; only `draw` touches `love.*` (docs/ARCHITECTURE.md "Layers").
local RoundSystem = require("src.game.systems.round_system")
local ScoreCard = require("src.app.render.score_card")

local MatchOver = {}

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

	local font = love.graphics.getFont()
	local title = MatchOver.title(ctx.round.winner)
	local titleWidth = font:getWidth(title) * TITLE_SCALE

	love.graphics.setColor(0, 0, 0, 0.7)
	love.graphics.rectangle("fill", 0, SCREEN_HEIGHT / 2 - 110, SCREEN_WIDTH, 240)

	love.graphics.setColor(PLAYER_COLOR[ctx.round.winner])
	love.graphics.print(title, (SCREEN_WIDTH - titleWidth) / 2, SCREEN_HEIGHT / 2 - 80, 0, TITLE_SCALE, TITLE_SCALE)

	local total = ctx.config.round.winsToWin
	local labelWidth = font:getWidth("P1 ") * 2
	local width = (total - 1) * PIP_SPACING + PIP_RADIUS * 2
	local x = (SCREEN_WIDTH - (2 * (labelWidth + width) + GROUP_GAP)) / 2
	local y = SCREEN_HEIGHT / 2 + 20
	for player = 1, 2 do
		love.graphics.setColor(PLAYER_COLOR[player])
		love.graphics.print("P" .. player, x, y - font:getHeight(), 0, 2, 2)
		local pipX = x + labelWidth + PIP_RADIUS
		for i, filled in ipairs(ScoreCard.pips(ctx.round.score[player], total)) do
			love.graphics.circle(filled and "fill" or "line", pipX + (i - 1) * PIP_SPACING, y, PIP_RADIUS)
		end
		x = x + labelWidth + width + GROUP_GAP
	end

	local prompt = MatchOver.prompt()
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.print(prompt, (SCREEN_WIDTH - font:getWidth(prompt) * 2) / 2, SCREEN_HEIGHT / 2 + 70, 0, 2, 2)
end

return MatchOver
