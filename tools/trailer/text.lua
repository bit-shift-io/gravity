-- Trailer text: cards and captions in the game font, drawn in output pixels
-- (never world space, so camera moves do not drag them). Placement is pure;
-- the draw functions use `love.*`. Dev-only.
local Fonts = require("src.app.render.fonts")

local Text = {}

-- Safe margins as fractions of the output. The HUD's score blocks sit in the
-- corners and, with five or six humans, in a row along the top, all within
-- 10% of the height of an edge; captions stay 16% clear of top and bottom.
local SAFE_X = 0.08
local SAFE_Y = 0.16
local CAPTION_SIZE = 0.045 -- font size, as a fraction of the output height
local CARD_SIZE = 0.08
local SUB_SIZE = 0.035

-- Anchor name -> { horizontal, vertical } as fractions of the safe area, and
-- the text alignment inside it.
Text.ANCHORS = {
	top = { 0.5, 0, "center" },
	center = { 0.5, 0.5, "center" },
	bottom = { 0.5, 1, "center" },
	lowerLeft = { 0, 1, "left" },
}
Text.DEFAULT_ANCHOR = "bottom"

-- Top-left of a boxWidth x boxHeight caption at `anchor` inside the safe area
-- of a width x height output.
function Text.place(width, height, anchor, boxWidth, boxHeight)
	local a = Text.ANCHORS[anchor]
	local left, top = width * SAFE_X, height * SAFE_Y
	return left + a[1] * (width - 2 * left - boxWidth), top + a[2] * (height - 2 * top - boxHeight)
end

local function fontFor(height, fraction)
	return Fonts.get(math.max(8, math.floor(height * fraction + 0.5)))
end

-- Prints `text` (wrapped to `limit` px) with its box top-left at (x, y).
local function printBlock(font, text, x, y, limit, align, alpha, colour)
	love.graphics.setFont(font)
	love.graphics.setColor(colour[1], colour[2], colour[3], alpha)
	love.graphics.printf(text, x, y, limit, align)
end

local function wrappedHeight(font, text, limit)
	local _, lines = font:getWrap(text, limit)
	return #lines * font:getHeight()
end

-- Draws one caption ({ text, anchor? }) at `alpha` on the current target.
function Text.drawCaption(caption, alpha, width, height)
	local anchor = caption.anchor or Text.DEFAULT_ANCHOR
	local font = fontFor(height, CAPTION_SIZE)
	local limit = width * (1 - 2 * SAFE_X) * 0.75
	local _, lines = font:getWrap(caption.text, limit)
	local boxWidth = 0
	for _, line in ipairs(lines) do
		boxWidth = math.max(boxWidth, font:getWidth(line))
	end
	local boxHeight = wrappedHeight(font, caption.text, limit)
	local x, y = Text.place(width, height, anchor, boxWidth, boxHeight)
	printBlock(font, caption.text, x, y, boxWidth + 1, Text.ANCHORS[anchor][3], alpha, { 1, 1, 1 })
end

-- Draws a text card: `text` centred on the middle of the output.
function Text.drawCard(text, width, height)
	local font = fontFor(height, CARD_SIZE)
	local limit = width * (1 - 2 * SAFE_X)
	local boxHeight = wrappedHeight(font, text, limit)
	printBlock(font, text, width * SAFE_X, (height - boxHeight) / 2, limit, "center", 1, { 1, 1, 1 })
end

-- Draws the one line under the logo on the end card.
function Text.drawSub(text, width, height)
	local font = fontFor(height, SUB_SIZE)
	printBlock(font, text, 0, height * 0.6, width, "center", 1, { 0.85, 0.85, 0.85 })
end

return Text
