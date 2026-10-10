-- Trailer text: cards and captions in the game font, drawn in output pixels
-- (never world space, so camera moves do not drag them). Placement is pure;
-- the draw functions use `love.*`. Dev-only.
local Fonts = require("src.app.render.fonts")
local Timeline = require("tools.trailer.timeline")

local WHITE = { 1, 1, 1 }

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

-- Splits `text` into { text, colour|nil } parts. Each `//` becomes two slashes,
-- the first in colours[1] and the second in colours[2] (the GRAV//TY logo
-- colours); all other text is white (nil). Text without `//` is one part.
function Text.parts(text, colours)
	local c1 = colours and colours[1]
	local c2 = colours and colours[2]
	local parts = {}
	local rest = text
	local a, b = rest:find("//", 1, true)
	while a do
		if a > 1 then
			parts[#parts + 1] = { rest:sub(1, a - 1), nil }
		end
		parts[#parts + 1] = { "/", c1 }
		parts[#parts + 1] = { "/", c2 }
		rest = rest:sub(b + 1)
		a, b = rest:find("//", 1, true)
	end
	if rest ~= "" or #parts == 0 then
		parts[#parts + 1] = { rest, nil }
	end
	return parts
end

-- Prints one line (no wrapping) with its top-left at (x, y), centred within
-- `limit` px when `align` is "center". Each part takes its own colour, and
-- text outside the slashes takes `base`.
local function printLine(font, line, x, y, limit, align, alpha, colours, base)
	local parts = Text.parts(line, colours)
	local width = 0
	for _, part in ipairs(parts) do
		width = width + font:getWidth(part[1])
	end
	local left = align == "center" and x + (limit - width) / 2 or x
	for _, part in ipairs(parts) do
		local col = part[2] or base
		love.graphics.setColor(col[1], col[2], col[3], alpha)
		love.graphics.print(part[1], left, y)
		left = left + font:getWidth(part[1])
	end
end

-- Prints `text` (wrapped to `limit` px) with its box top-left at (x, y).
local function printBlock(font, text, x, y, limit, align, alpha, colours, base)
	love.graphics.setFont(font)
	local _, lines = font:getWrap(text, limit)
	local lineHeight = font:getHeight()
	for i, line in ipairs(lines) do
		local trimmed = (line:gsub("%s+$", ""))
		printLine(font, trimmed, x, y + (i - 1) * lineHeight, limit, align, alpha, colours, base)
	end
end

local function wrappedHeight(font, text, limit)
	local _, lines = font:getWrap(text, limit)
	return #lines * font:getHeight()
end

-- Draws one caption ({ text, anchor? }) at `alpha` on the current target,
-- `offset` pixels (of the 1920-wide frame, positive = right) from its anchor.
-- `colours` ({ c1, c2 }) colour the `//` slashes.
function Text.drawCaption(caption, alpha, width, height, offset, colours)
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
	x = x + (offset or 0) * width / Timeline.CAPTION_REF_WIDTH
	printBlock(font, caption.text, x, y, boxWidth + 1, Text.ANCHORS[anchor][3], alpha, colours, WHITE)
end

-- Draws a text card: `text` centred on the middle of the output, `//` coloured
-- by `colours` as for captions.
function Text.drawCard(text, width, height, colours)
	local font = fontFor(height, CARD_SIZE)
	local limit = width * (1 - 2 * SAFE_X)
	local boxHeight = wrappedHeight(font, text, limit)
	printBlock(font, text, width * SAFE_X, (height - boxHeight) / 2, limit, "center", 1, colours, WHITE)
end

-- Draws the one line under the logo on the end card.
function Text.drawSub(text, width, height)
	local font = fontFor(height, SUB_SIZE)
	printBlock(font, text, 0, height * 0.6, width, "center", 1, nil, { 0.85, 0.85, 0.85 })
end

return Text
