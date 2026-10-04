-- The GRAV//TY logo: the title-screen treatment (Kernel Panic, coloured
-- slashes) at any size. Placement and sizing are pure; `draw` uses `love.*`.
-- Dev-only.
local Menu = require("src.app.render.menu")
local Fonts = require("src.app.render.fonts")

local Logo = {}

local TITLE = "GRAV//TY"
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

-- Draws the logo on the current target. `size` is the logo's width as a
-- fraction of `width`; `colors` ({ c1, c2 }) tint the slashes.
function Logo.draw(width, height, anchor, size, colors)
	local reference = Fonts.get(REFERENCE_SIZE)
	local fontSize = Logo.fontSize(width * size, REFERENCE_SIZE, reference:getWidth(TITLE))
	local font = Fonts.get(fontSize)
	local x, y = Logo.place(width, height, anchor, font:getWidth(TITLE), font:getHeight())
	love.graphics.setFont(font)
	for _, part in ipairs(Menu.titleParts(TITLE, colors)) do
		local colour = part[2] or { 1, 1, 1 }
		love.graphics.setColor(colour[1], colour[2], colour[3], 1)
		love.graphics.print(part[1], x, y)
		x = x + font:getWidth(part[1])
	end
end

return Logo
