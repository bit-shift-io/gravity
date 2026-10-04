-- The "G//" monogram: icon-sized rendering of the title with proper glyph
-- centering. Placement and sizing are pure; `draw` uses `love.*`.
-- Dev-only.
local Menu = require("src.app.render.menu")
local Fonts = require("src.app.render.fonts")

local Monogram = {}

local MONOGRAM = "G//"
local MAX_WIDTH_FRACTION = 0.8 -- text spans at most 80% of the square (10% margin a side)

-- Largest integer font size whose measured text width (`measure(fontSize)`)
-- fits in 80% of the square, optionally scaled by `glyphScale`. Uses real
-- measurements: glyph widths are not linear in font size.
function Monogram.fitSize(squareSize, measure, glyphScale)
	local limit = squareSize * MAX_WIDTH_FRACTION * (glyphScale or 1)
	local size = 1
	while measure(size + 1) <= limit and size < 4096 do
		size = size + 1
	end
	return size
end

-- Top-left draw position that centres a box of boxW x boxH in the square. The
-- optional offsets are where the visible ink starts inside the drawn text.
function Monogram.centre(squareSize, boxW, boxH, offsetX, offsetY)
	return (squareSize - boxW) / 2 - (offsetX or 0), (squareSize - boxH) / 2 - (offsetY or 0)
end

-- Visible ink bounds of the monogram at `font`, found by drawing it to a
-- scratch canvas and scanning alpha. Returns minX, minY, maxX, maxY (inclusive).
local function inkBounds(font, size)
	local Compat = require("src.app.compat")
	local canvas = Compat.newCanvas(size, size)
	love.graphics.push("all")
	love.graphics.setCanvas(canvas)
	love.graphics.clear(0, 0, 0, 0)
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.setFont(font)
	love.graphics.print(MONOGRAM, 0, 0)
	love.graphics.setCanvas()
	love.graphics.pop()
	local data = canvas:newImageData()
	canvas:release()
	local minX, minY, maxX, maxY = math.huge, math.huge, -1, -1
	for y = 0, size - 1 do
		for x = 0, size - 1 do
			local _, _, _, a = data:getPixel(x, y)
			if a > 0.05 then
				minX, minY = math.min(minX, x), math.min(minY, y)
				maxX, maxY = math.max(maxX, x), math.max(maxY, y)
			end
		end
	end
	return minX, minY, maxX, maxY
end

-- Draws the monogram centred (by visible ink) in a square canvas. `size` is the
-- square dimension, `colors` ({ c1, c2 }) tint the slashes, `glyphScale` is an
-- optional size fraction.
function Monogram.draw(size, colors, glyphScale)
	-- Fit by the visible ink width so the margin is real, not an advance guess.
	local fontSize = Monogram.fitSize(size, function(fs)
		local minX, _, maxX = inkBounds(Fonts.get(fs), size)
		if maxX < 0 then
			return 0
		end
		return maxX - minX + 1
	end, glyphScale)
	local font = Fonts.get(fontSize)

	local minX, minY, maxX, maxY = inkBounds(font, size)
	local x, y = Monogram.centre(size, maxX - minX + 1, maxY - minY + 1, minX, minY)

	love.graphics.setFont(font)
	for _, part in ipairs(Menu.titleParts(MONOGRAM, colors)) do
		local colour = part[2] or { 1, 1, 1 }
		love.graphics.setColor(colour[1], colour[2], colour[3], 1)
		love.graphics.print(part[1], x, y)
		x = x + font:getWidth(part[1])
	end
end

return Monogram
