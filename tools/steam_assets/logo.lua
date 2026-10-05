-- The GRAV//TY logo: the title-screen treatment (Kernel Panic, coloured
-- slashes) at any size, with the store subtitle as a small line beneath.
-- Placement and sizing are pure; `draw` uses `love.*`. Dev-only.
local Menu = require("src.app.render.menu")
local Fonts = require("src.app.render.fonts")

local Logo = {}

local TITLE = "GRAV//TY"
local SUBTITLE = "ORBITAL ARENA"
local SUBTITLE_SCALE = 0.4 -- subtitle font size, as a fraction of the title's
local SUBTITLE_GAP = 0.1 -- of the title font height
local SUBTITLE_TINT = 0.7 -- grey level, so the title stays the strongest element
local REFERENCE_SIZE = 72
local MARGIN = 0.04 -- of the shorter canvas side

-- Anchor name -> fraction of the free space along x and y.
Logo.anchors = {
	["top-left"] = { 0, 0 },
	top = { 0.5, 0 },
	["top-right"] = { 1, 0 },
	left = { 0, 0.5 },
	centre = { 0.5, 0.5 },
	right = { 1, 0.5 },
	["bottom-left"] = { 0, 1 },
	bottom = { 0.5, 1 },
	["bottom-right"] = { 1, 1 },
}

function Logo.margin(width, height)
	return math.min(width, height) * MARGIN
end

-- Font pixel size whose text is `targetWidth` wide, given the reference font
-- measured `referenceWidth` at `referenceSize`.
function Logo.fontSize(targetWidth, referenceSize, referenceWidth)
	return math.max(1, math.floor(referenceSize * targetWidth / referenceWidth + 0.5))
end

-- Top-left of a boxWidth x boxHeight logo inside a canvas, at `anchor`, kept
-- one margin from the edges it touches.
function Logo.place(width, height, anchor, boxWidth, boxHeight)
	local fraction = Logo.anchors[anchor]
	local margin = Logo.margin(width, height)
	return margin + fraction[1] * (width - boxWidth - 2 * margin), margin + fraction[2] * (height - boxHeight - 2 * margin)
end

-- Title plus subtitle as one box: its size, and where the subtitle sits in it
-- (centred under the title, one gap below it).
function Logo.stack(titleWidth, titleHeight, subtitleWidth, subtitleHeight)
	local gap = titleHeight * SUBTITLE_GAP
	local subtitleY = titleHeight + gap
	return {
		width = math.max(titleWidth, subtitleWidth),
		height = subtitleY + subtitleHeight,
		titleX = (math.max(titleWidth, subtitleWidth) - titleWidth) / 2,
		subtitleX = (math.max(titleWidth, subtitleWidth) - subtitleWidth) / 2,
		subtitleY = subtitleY,
	}
end

-- Draws the logo on the current target. `size` is the logo's width as a
-- fraction of `width`; `colors` ({ c1, c2 }) tint the slashes.
function Logo.draw(width, height, anchor, size, colors)
	local reference = Fonts.get(REFERENCE_SIZE)
	local fontSize = Logo.fontSize(width * size, REFERENCE_SIZE, reference:getWidth(TITLE))
	local font = Fonts.get(fontSize)
	local subFont = Fonts.get(math.max(1, math.floor(fontSize * SUBTITLE_SCALE + 0.5)))
	local box = Logo.stack(font:getWidth(TITLE), font:getHeight(), subFont:getWidth(SUBTITLE), subFont:getHeight())
	local left, top = Logo.place(width, height, anchor, box.width, box.height)
	local x = left + box.titleX
	love.graphics.setFont(font)
	for _, part in ipairs(Menu.titleParts(TITLE, colors)) do
		local colour = part[2] or { 1, 1, 1 }
		love.graphics.setColor(colour[1], colour[2], colour[3], 1)
		love.graphics.print(part[1], x, top)
		x = x + font:getWidth(part[1])
	end
	love.graphics.setFont(subFont)
	love.graphics.setColor(SUBTITLE_TINT, SUBTITLE_TINT, SUBTITLE_TINT, 1)
	love.graphics.print(SUBTITLE, left + box.subtitleX, top + box.subtitleY)
end

return Logo
