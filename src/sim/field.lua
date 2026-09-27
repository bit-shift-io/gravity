-- Baked static gravity field (docs/CONTEXT.md "Gravity field", "Static
-- field"): worlds are rasterised into mass cells once, at match start, and
-- every grid cell's field vector is summed once from those mass cells.
-- Dynamic bodies never touch this grid -- they add pairwise gravity
-- separately (docs/adr/0002-hybrid-gravity-field.md). Pure math -- no
-- `love.*` (docs/ARCHITECTURE.md "Layers"). Keeping the whole bake behind
-- `Field.bake` is deliberate: moving/rotating worlds later replace only
-- this function, per the ADR's consequences.
local Poly = require("src.core.poly")
local Gravity = require("src.sim.gravity")

local Field = {}

local function cellCenter(minX, minY, cellSize, col, row)
	return minX + (col + 0.5) * cellSize, minY + (row + 0.5) * cellSize
end

-- Rasterises `level.worlds` into mass cells on a grid covering the virtual
-- resolution (1280x720, docs/ARCHITECTURE.md "Rules") plus
-- `config.boundary.margin` on every side, then bakes the field vector at
-- every grid cell by summing softened point-mass gravity (src/sim/gravity.lua)
-- from every mass cell.
function Field.bake(level, config)
	local cellSize = config.field.cellSize
	local margin = config.boundary.margin
	local G = config.gravity.G
	local eps = config.gravity.softening

	local minX = -margin
	local minY = -margin
	local width = 1280 + 2 * margin
	local height = 720 + 2 * margin
	local cols = math.ceil(width / cellSize)
	local rows = math.ceil(height / cellSize)

	local field = {
		cellSize = cellSize,
		cols = cols,
		rows = rows,
		minX = minX,
		minY = minY,
		cells = {},
	}

	-- Each world's mass-per-cell (Gotcha: mass per cell = world mass x (cell
	-- area inside world / world area); v1 approximates "inside" with
	-- cell-centre inclusion rather than exact overlap area -- supersampling
	-- is a later refinement).
	local cellArea = cellSize * cellSize
	local worldMassPerCell = {}
	for i, world in ipairs(level.worlds) do
		local area = math.abs(Poly.area(world.vertices))
		worldMassPerCell[i] = (area > 0) and (world.mass * cellArea / area) or 0
	end

	-- Pass 1: rasterise mass, remembering which cells are non-empty so pass
	-- 2 only sums over those instead of every grid cell.
	local massIndices = {}
	for row = 0, rows - 1 do
		for col = 0, cols - 1 do
			local idx = row * cols + col + 1
			local cx, cy = cellCenter(minX, minY, cellSize, col, row)
			local mass = 0
			for i, world in ipairs(level.worlds) do
				if Poly.pointInPolygon(world.vertices, { x = cx, y = cy }) then
					mass = mass + worldMassPerCell[i]
				end
			end
			field.cells[idx] = { x = cx, y = cy, mass = mass, ax = 0, ay = 0 }
			if mass > 0 then
				table.insert(massIndices, idx)
			end
		end
	end

	-- Pass 2: every grid cell -- including ones inside a world (Gotcha:
	-- "cells inside a world still get a field value") -- sums gravity from
	-- every mass cell, skipping a mass cell's pull on itself (Gotcha: "must
	-- not include itself in its own cell's field sum").
	local cellCount = cols * rows
	for idx = 1, cellCount do
		local cell = field.cells[idx]
		local ax, ay = 0, 0
		for _, massIdx in ipairs(massIndices) do
			if massIdx ~= idx then
				local massCell = field.cells[massIdx]
				local dx = cell.x - massCell.x
				local dy = cell.y - massCell.y
				local fx, fy = Gravity.pointMass(dx, dy, massCell.mass, G, eps)
				ax = ax + fx
				ay = ay + fy
			end
		end
		cell.ax = ax
		cell.ay = ay
	end

	return field
end

local function cellAt(field, col, row)
	return field.cells[row * field.cols + col + 1]
end

-- Bilinearly interpolated acceleration vector at world position (x, y).
-- Sampling outside the grid clamps to the nearest edge cell (the fractional
-- grid coordinate is clamped before interpolating, so the blend weight
-- against the next cell is exactly zero right at the edge) rather than
-- extrapolating past it.
function Field.sample(field, x, y)
	local gx = (x - field.minX) / field.cellSize - 0.5
	local gy = (y - field.minY) / field.cellSize - 0.5

	gx = math.max(0, math.min(field.cols - 1, gx))
	gy = math.max(0, math.min(field.rows - 1, gy))

	local c0 = math.floor(gx)
	local r0 = math.floor(gy)
	local c1 = math.min(c0 + 1, field.cols - 1)
	local r1 = math.min(r0 + 1, field.rows - 1)
	local tx = gx - c0
	local ty = gy - r0

	local q00, q10 = cellAt(field, c0, r0), cellAt(field, c1, r0)
	local q01, q11 = cellAt(field, c0, r1), cellAt(field, c1, r1)

	local ax0 = q00.ax + (q10.ax - q00.ax) * tx
	local ax1 = q01.ax + (q11.ax - q01.ax) * tx
	local ay0 = q00.ay + (q10.ay - q00.ay) * tx
	local ay1 = q01.ay + (q11.ay - q01.ay) * tx

	return {
		x = ax0 + (ax1 - ax0) * ty,
		y = ay0 + (ay1 - ay0) * ty,
	}
end

return Field
