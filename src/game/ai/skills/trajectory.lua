-- Shell flight prediction for AI aim (docs/CONTEXT.md "Projectile"): steps a
-- shell forward exactly as src/sim/step.lua's Sim.integrate would -- static
-- field plus boundary field sampled before the step, then
-- src/sim/integrate.lua's semi-implicit Euler at the same dt -- and stops
-- where Sim.collide would end the shell: world contact (the same swept test)
-- or the hard boundary. Pairwise gravity is skipped by design (faint at arena
-- scale). Pure: reads the sim's fields, never writes bodies. No `love.*`
-- (docs/ARCHITECTURE.md "Layers").
local Field = require("src.sim.field")
local Integrate = require("src.sim.integrate")
local Collide = require("src.sim.collide")
local Poly = require("src.core.poly")

local Trajectory = {}

-- Axis-aligned bounds per world, so a step only runs the swept edge test
-- against worlds its segment could touch.
local function bounds(worlds)
	local boxes = {}
	for i, world in ipairs(worlds) do
		local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
		for _, v in ipairs(world.vertices) do
			minX, maxX = math.min(minX, v.x), math.max(maxX, v.x)
			minY, maxY = math.min(minY, v.y), math.max(maxY, v.y)
		end
		boxes[i] = { minX = minX, minY = minY, maxX = maxX, maxY = maxY, vertices = world.vertices }
	end
	return boxes
end

-- The same contact rule as Collide.checkProjectileWorlds (an edge crossed,
-- or the step ends inside), as a boolean: it skips the contact point and
-- normal, which this runs too often to allocate.
local function crosses(vertices, p1, p2)
	local n = #vertices
	for i = 1, n do
		if Poly.segmentIntersect(p1, p2, vertices[i], vertices[i % n + 1]) then
			return true
		end
	end
	return Poly.pointInPolygon(vertices, p2)
end

local function hitsWorld(boxes, p1, p2)
	local minX, maxX = math.min(p1.x, p2.x), math.max(p1.x, p2.x)
	local minY, maxY = math.min(p1.y, p2.y), math.max(p1.y, p2.y)
	for _, box in ipairs(boxes) do
		if maxX >= box.minX and minX <= box.maxX and maxY >= box.minY and minY <= box.maxY then
			if crosses(box.vertices, p1, p2) then
				return true
			end
		end
	end
	return false
end

-- Returns `{ points = { {x, y}, ... }, stop = "world" | "boundary" | "horizon" }`:
-- one post-step position per step, for at most `steps` steps of `dt`.
-- `shell` is `{ x, y, vx, vy, radius }`. `push` (optional) is
-- `push(body, accel)`, called each step after the field is sampled: it may
-- add to `accel` (a ship's own thrust) and reads the flown `body`'s x, y,
-- vx, vy.
function Trajectory.simulate(sim, worlds, shell, dt, steps, push)
	local body = { x = shell.x, y = shell.y, vx = shell.vx, vy = shell.vy }
	local boxes = bounds(worlds or {})
	local hard = sim.boundaryField and sim.boundaryField.hardBoundary
	local points = {}
	local from = {}
	for i = 1, steps do
		local accel = Field.sample(sim.field, body.x, body.y)
		if sim.boundaryField then
			local boundary = Field.sample(sim.boundaryField, body.x, body.y)
			accel.x = accel.x + boundary.x
			accel.y = accel.y + boundary.y
		end
		if push then
			push(body, accel)
		end
		from.x, from.y = body.x, body.y
		Integrate.step(body, accel.x, accel.y, dt)
		local point = { x = body.x, y = body.y }
		points[i] = point

		if hitsWorld(boxes, from, point) then
			return { points = points, stop = "world" }
		end
		if hard and Collide.checkHardBoundary(body.x, body.y, shell.radius, hard) then
			return { points = points, stop = "boundary" }
		end
	end
	return { points = points, stop = "horizon" }
end

return Trajectory
