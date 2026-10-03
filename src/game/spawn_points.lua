-- Spawn point selection (docs/CONTEXT.md "Spawn point"): picks the two
-- surface points, one per player, that start their ships in tank mode.
local Poly = require("src.core.poly")
local Vec2 = require("src.core.vec2")

local SpawnPoints = {}

-- Candidate points: `edgeSamples` evenly spaced interior points on every
-- world edge (never the vertices, whose normals are ambiguous), each with
-- its edge's outward normal.
local function candidates(worlds, config)
	local samples = config.spawn.edgeSamples
	local result = {}
	for _, world in ipairs(worlds) do
		local vertices = Poly.normalize(world.vertices)
		local normals = Poly.outwardNormals(vertices)
		for i, a in ipairs(vertices) do
			local b = vertices[i % #vertices + 1]
			for k = 1, samples do
				local t = k / (samples + 1)
				result[#result + 1] = {
					x = a.x + (b.x - a.x) * t,
					y = a.y + (b.y - a.y) * t,
					normal = normals[i],
					world = world,
				}
			end
		end
	end
	return result
end

-- True when a ship standing at `point` (with its outward `normal`) has room:
-- a grid of probes from the surface up to config.spawn.clearHeight, spread
-- config.spawn.clearHalfWidth either side along the surface, must all be
-- outside every world.
function SpawnPoints.hasClearance(worlds, point, config)
	local spawn = config.spawn
	local tangent = Vec2.perp(point.normal)
	for step = 1, spawn.clearSteps do
		local height = spawn.clearHeight * step / spawn.clearSteps
		for _, side in ipairs({ -1, 0, 1 }) do
			local probe = {
				x = point.x + point.normal.x * height + tangent.x * side * spawn.clearHalfWidth,
				y = point.y + point.normal.y * height + tangent.y * side * spawn.clearHalfWidth,
			}
			for _, world in ipairs(worlds) do
				if Poly.pointInPolygon(world.vertices, probe) then
					return false
				end
			end
		end
	end
	return true
end

-- Every candidate point that has clearance above it. Stored on the level
-- (level.spawnCandidates) for later rounds' random respawns.
function SpawnPoints.cleared(worlds, config)
	local points = {}
	for _, candidate in ipairs(candidates(worlds, config)) do
		if SpawnPoints.hasClearance(worlds, candidate, config) then
			points[#points + 1] = candidate
		end
	end
	return points
end

-- Up to `n` distinct entries of `points` drawn with `rng` (src/core/rng.lua);
-- no minimum distance. Returns fewer when `points` has fewer than `n`.
function SpawnPoints.pick(points, n, rng)
	local pool = {}
	for i, point in ipairs(points) do
		pool[i] = point
	end
	local picked = {}
	for _ = 1, math.min(n, #pool) do
		picked[#picked + 1] = table.remove(pool, rng:int(1, #pool))
	end
	return picked
end

-- Returns two spawn points `{ x, y, normal = { x, y }, world }`, the farthest-apart
-- pair of candidates that have clearance above them.
function SpawnPoints.choose(worlds, config, points)
	points = points or SpawnPoints.cleared(worlds, config)
	local best, bestDistance = nil, -1
	for i = 1, #points - 1 do
		for j = i + 1, #points do
			local d = Vec2.length(Vec2.sub(points[i], points[j]))
			if d > bestDistance then
				best, bestDistance = { points[i], points[j] }, d
			end
		end
	end
	return best
end

return SpawnPoints
