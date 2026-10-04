-- Score card overlay: centred result text and score pips, drawn in screen
-- space over the 1280x720 virtual resolution (unaffected by camera zoom)
-- while RoundSystem.cardVisible says so. The text/pip helpers are pure; only
-- `draw` touches `love.*` (docs/ARCHITECTURE.md "Layers").
local Ease = require("src.core.ease")
local RoundSystem = require("src.game.systems.round_system")
local Fonts = require("src.app.render.fonts")
local PlayerColors = require("src.app.render.player_colors")

local ScoreCard = {}

local SCREEN_WIDTH = 1280
local SCREEN_HEIGHT = 720
local PANEL_MIN_HEIGHT = SCREEN_HEIGHT / 2
local PIP_RADIUS = 8
local PIP_SPACING = 24
local ROW_HEIGHT = 40
local TITLE_SIZE = 64
local LABEL_SIZE = 32
local TAG_SIZE = 18
local PANEL_PAD = 20
local TITLE_BLOCK = 100 -- panel top to the first score row
local HOLD = 1 -- seconds the result sits alone, centred
local SLIDE = 0.7 -- seconds the title moves up as the scores rise in
local FADE_IN = 0.4 -- seconds the title and panel fade in when the card appears
local FADE_OUT = 0.5 -- seconds the card fades before the next round
local SCORE_RISE = 60 -- px the score rows travel while revealing

function ScoreCard.resultText(result)
	if result.draw then
		return "DRAW"
	end
	return "P" .. result.winner .. " WINS"
end

-- Card timeline `elapsed` seconds after it appears, out of `duration`.
-- Returns reveal (0 while the result holds centred, eased to 1 as it slides
-- up and the scores come in), alpha (1, then fading to 0 at the end) and
-- intro (0 to 1 as the title and panel fade in at the start). Pure.
function ScoreCard.animation(elapsed, duration)
	local reveal = Ease.easeOut(math.max(0, math.min(1, (elapsed - HOLD) / SLIDE)))
	local alpha = math.max(0, math.min(1, (duration - elapsed) / FADE_OUT))
	local intro = math.max(0, math.min(1, elapsed / FADE_IN))
	return reveal, alpha, intro
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

-- "EASY BASIC" for an AI slot (level then personality), nil for a human. A
-- Schizo adds the personality it is playing: "HARD SCHIZO (SNIPER)". Pure.
function ScoreCard.aiLabel(ctx, slot)
	local binding = ctx.roster[slot].binding
	if binding.kind ~= "ai" then
		return nil
	end
	local name = (ctx.personalities and ctx.personalities[slot]) or "basic"
	local schizo = name == "schizo" and ctx.schizo and ctx.schizo[slot]
	if schizo then
		name = name .. " (" .. schizo.current .. ")"
	end
	return string.upper(binding.level .. " " .. name)
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
-- `alpha` (default 1) fades the rows.
function ScoreCard.drawScores(ctx, top, alpha)
	alpha = alpha or 1
	local total = ctx.config.round.winsToWin
	local labelFont = Fonts.get(LABEL_SIZE)
	local tagFont = Fonts.get(TAG_SIZE)
	local labelWidth = labelFont:getWidth("P6 ")
	local left = (SCREEN_WIDTH - (labelWidth + groupWidth(total))) / 2
	love.graphics.setFont(labelFont)
	for row, player in ipairs(ScoreCard.sortedSlots(ctx.round.score)) do
		local y = top + (row - 0.5) * ROW_HEIGHT
		local c = PlayerColors.get(ctx, player)
		love.graphics.setColor(c[1], c[2], c[3], (c[4] or 1) * alpha)
		love.graphics.print("P" .. player, left, y - labelFont:getHeight() / 2)
		local pipX = left + labelWidth + PIP_RADIUS
		for i, filled in ipairs(ScoreCard.pips(ctx.round.score[player], total)) do
			love.graphics.circle(filled and "fill" or "line", pipX + (i - 1) * PIP_SPACING, y, PIP_RADIUS)
		end
		local label = ScoreCard.aiLabel(ctx, player)
		if label then
			love.graphics.setFont(tagFont)
			love.graphics.print(label, left + labelWidth + groupWidth(total) + 12, y - tagFont:getHeight() / 2)
			love.graphics.setFont(labelFont)
		end
	end
end

-- Height and top of the centred panel for content `contentHeight` tall: half
-- the screen, or taller when the content needs it. Pure.
function ScoreCard.panelBounds(contentHeight)
	local height = math.max(PANEL_MIN_HEIGHT, contentHeight)
	return (SCREEN_HEIGHT - height) / 2, height
end

-- A full-screen tinted backdrop with a white inset outline, matching the
-- pause overlay. `alpha` fades both.
function ScoreCard.drawPanel(tint, alpha)
	love.graphics.setColor(0, 0, 0, tint * alpha)
	love.graphics.rectangle("fill", 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)
	love.graphics.setColor(1, 1, 1, alpha)
	love.graphics.setLineWidth(2)
	love.graphics.rectangle("line", 1, 1, SCREEN_WIDTH - 2, SCREEN_HEIGHT - 2)
	love.graphics.setLineWidth(1)
end

function ScoreCard.draw(ctx)
	local roundConfig = ctx.config.round
	if not RoundSystem.cardVisible(ctx.round, roundConfig) then
		return
	end

	local elapsed = ctx.round.timer - roundConfig.endDelay
	local reveal, fade, intro = ScoreCard.animation(elapsed, roundConfig.cardDuration)

	local titleFont = Fonts.get(TITLE_SIZE)
	local title = ScoreCard.resultText(ctx.round.result)
	local titleWidth = titleFont:getWidth(title)
	local listHeight = ScoreCard.listHeight(#ctx.round.score)
	local contentHeight = TITLE_BLOCK + listHeight + PANEL_PAD
	local panelTop, panelHeight = ScoreCard.panelBounds(contentHeight)
	local contentTop = panelTop + (panelHeight - contentHeight) / 2

	ScoreCard.drawPanel(0.6, intro * fade)

	local titleAlone = (SCREEN_HEIGHT - titleFont:getHeight()) / 2
	local titleSettled = contentTop + PANEL_PAD
	love.graphics.setColor(1, 1, 1, intro * fade)
	love.graphics.setFont(titleFont)
	love.graphics.print(title, (SCREEN_WIDTH - titleWidth) / 2, titleAlone + (titleSettled - titleAlone) * reveal)

	ScoreCard.drawScores(ctx, contentTop + TITLE_BLOCK + (1 - reveal) * SCORE_RISE, reveal * fade)

	love.graphics.setColor(1, 1, 1, 1)
end

return ScoreCard
