-- Match-over overlay: winner, final pips and a rematch prompt, drawn in
-- screen space (virtual 1280x720) while the match is over. The text helpers
-- are pure; only `draw` touches `love.*` (docs/ARCHITECTURE.md "Layers").
local RoundSystem = require("src.game.systems.round_system")
local ScoreCard = require("src.app.render.score_card")
local Fonts = require("src.app.render.fonts")
local PlayerColors = require("src.app.render.player_colors")

local MatchOver = {}

local SCREEN_WIDTH = 1280
local SCREEN_HEIGHT = 720
local TITLE_SIZE = 56
local PROMPT_SIZE = 28
local TITLE_BLOCK = 100 -- panel top to the first score row
local PROMPT_BLOCK = 70 -- room for the prompt under the list

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
	local promptFont = Fonts.get(PROMPT_SIZE)
	local title = MatchOver.title(ctx.round.winner)
	local titleWidth = titleFont:getWidth(title)

	local listHeight = ScoreCard.listHeight(#ctx.round.score)
	local panelHeight = TITLE_BLOCK + listHeight + PROMPT_BLOCK
	local panelTop = (SCREEN_HEIGHT - panelHeight) / 2

	love.graphics.setColor(0, 0, 0, 0.7)
	love.graphics.rectangle("fill", 0, panelTop, SCREEN_WIDTH, panelHeight)

	love.graphics.setColor(PlayerColors.get(ctx, ctx.round.winner))
	love.graphics.setFont(titleFont)
	love.graphics.print(title, (SCREEN_WIDTH - titleWidth) / 2, panelTop + 25)

	ScoreCard.drawScores(ctx, panelTop + TITLE_BLOCK)

	local prompt = MatchOver.prompt()
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.setFont(promptFont)
	love.graphics.print(prompt, (SCREEN_WIDTH - promptFont:getWidth(prompt)) / 2, panelTop + TITLE_BLOCK + listHeight + 15)
end

return MatchOver
