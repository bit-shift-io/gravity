-- Debug overlay for the baked gravity field: 1 draws one arrow per grid
-- cell (direction, with length and colour by magnitude); 2 draws the field
-- grid lines plus the worlds' collision outlines in a debug colour. Reads
-- ctx only, never mutates it (docs/ARCHITECTURE.md "Rendering"). `love.*`
-- only -- this lives in src/app/ (docs/ARCHITECTURE.md "Layers").
local DebugOverlay = {}

-- An arrow's length approaches this as magnitude grows, so cells right next
-- to a world (huge magnitude) don't draw arrows that swamp their neighbours;
-- it comfortably fits inside one 16px field cell.
local ARROW_MAX_LENGTH = 7

-- Half-saturation point for both the length and colour ramps: a cell whose
-- magnitude equals this value draws at half the maximum length/brightness.
-- Gravity magnitudes here range from near-zero (far corners of the grid) to
-- very large (a cell touching a world's edge, near-singular under the
-- softening term), so a fixed linear scale would make everywhere but the
-- immediate edge of a world look black; this makes the falloff visible
-- across that whole range instead.
local MAGNITUDE_HALF_SATURATION = 400

local GRID_COLOR = { 1, 1, 1, 0.08 }
local WORLD_OUTLINE_COLOR = { 1, 0.8, 0.2, 1 }

-- Cells inside a world (mass > 0) have a baked field value (Gotcha: "cells
-- inside a world still get a field value") but nothing ever samples there
-- in play, so the overlay skips them rather than drawing a meaningless
-- arrow inside solid ground.
local function isInsideWorld(cell)
	return cell.mass > 0
end

local function magnitudeRatio(magnitude)
	return magnitude / (magnitude + MAGNITUDE_HALF_SATURATION)
end

local function drawArrow(cell)
	local magnitude = math.sqrt(cell.ax * cell.ax + cell.ay * cell.ay)
	if magnitude <= 0 then
		return
	end

	local ratio = magnitudeRatio(magnitude)
	local length = ratio * ARROW_MAX_LENGTH
	local dirX, dirY = cell.ax / magnitude, cell.ay / magnitude

	love.graphics.setColor(ratio, 0.3 + 0.7 * (1 - ratio), 1 - ratio, 1)

	local tipX, tipY = cell.x + dirX * length, cell.y + dirY * length
	love.graphics.line(cell.x, cell.y, tipX, tipY)

	-- Minimal arrowhead: two short backward-angled ticks at the tip, so the
	-- overlay reads as directional arrows rather than plain line segments.
	local headLength = math.min(2.5, length)
	local perpX, perpY = -dirY, dirX
	love.graphics.line(
		tipX,
		tipY,
		tipX - dirX * headLength + perpX * headLength * 0.5,
		tipY - dirY * headLength + perpY * headLength * 0.5
	)
	love.graphics.line(
		tipX,
		tipY,
		tipX - dirX * headLength - perpX * headLength * 0.5,
		tipY - dirY * headLength - perpY * headLength * 0.5
	)
end

-- One arrow per non-world grid cell: direction, with length and colour by
-- magnitude.
function DebugOverlay.drawFieldArrows(field)
	for _, cell in ipairs(field.cells) do
		if not isInsideWorld(cell) then
			drawArrow(cell)
		end
	end
end

-- Faint lines along every grid cell boundary.
function DebugOverlay.drawGrid(field)
	love.graphics.setColor(GRID_COLOR)

	for col = 0, field.cols do
		local x = field.minX + col * field.cellSize
		love.graphics.line(x, field.minY, x, field.minY + field.rows * field.cellSize)
	end

	for row = 0, field.rows do
		local y = field.minY + row * field.cellSize
		love.graphics.line(field.minX, y, field.minX + field.cols * field.cellSize, y)
	end
end

-- World collision outlines in the debug colour, redrawn over the normal
-- render so they read as part of the debug overlay even where they overlap
-- the always-on world render (src/app/render/worlds.lua).
function DebugOverlay.drawWorldOutlines(level)
	love.graphics.setColor(WORLD_OUTLINE_COLOR)

	for _, world in ipairs(level.worlds) do
		local vertices = world.vertices
		local points = {}

		for _, v in ipairs(vertices) do
			table.insert(points, v.x)
			table.insert(points, v.y)
		end

		table.insert(points, vertices[1].x)
		table.insert(points, vertices[1].y)

		love.graphics.line(points)
	end
end

function DebugOverlay.draw(ctx)
	local debug = ctx.debug
	local field = ctx.sim and ctx.sim.field
	if not debug or not field then
		return
	end

	if debug.showGrid then
		DebugOverlay.drawGrid(field)
		DebugOverlay.drawWorldOutlines(ctx.level)
	end

	if debug.showField then
		DebugOverlay.drawFieldArrows(field)
	end

	love.graphics.setColor(1, 1, 1, 1)
end

return DebugOverlay
