-- Pure geometry for splitting an asteroid (docs/CONTEXT.md "Split"): three
-- radial cuts from the polygon's centroid, the first toward the impact,
-- 120 degrees apart. Each cut is clipped to the boundary and the three
-- resulting sectors become the fragments. No `love.*`, no randomness.
local Poly = require("src.core.poly")

local AsteroidSplit = {}

local TWO_PI = 2 * math.pi
local SECTOR = TWO_PI / 3
local EPS = 1e-9

-- Where the ray from `origin` along `dir` leaves the (convex) polygon.
local function boundaryHit(points, origin, dir)
	local n = #points
	local best, bestT = nil, -math.huge
	for i = 1, n do
		local p, q = points[i], points[i % n + 1]
		local ex, ey = q.x - p.x, q.y - p.y
		local denom = dir.x * ey - dir.y * ex
		if math.abs(denom) > 1e-12 then
			local wx, wy = p.x - origin.x, p.y - origin.y
			local t = (wx * ey - wy * ex) / denom
			local s = (wx * dir.y - wy * dir.x) / denom
			if t > 0 and s >= -EPS and s <= 1 + EPS and t > bestT then
				bestT = t
				best = { x = origin.x + dir.x * t, y = origin.y + dir.y * t }
			end
		end
	end
	return best
end

local function pushDistinct(list, p)
	local last = list[#list]
	if last and math.abs(last.x - p.x) < EPS and math.abs(last.y - p.y) < EPS then
		return
	end
	list[#list + 1] = p
end

-- `vertices`: convex polygon in the parent's local space. `impactDir`: a
-- direction vector (need not be unit length). Returns 3 fragments:
-- `{ vertices = <re-centred on own centroid>, offset = <own centroid in the
-- parent's local space>, area = number, radius = number }`. The first
-- fragment's sector starts on the impact ray.
function AsteroidSplit.carve(vertices, impactDir)
	local points = Poly.normalize(vertices)
	local centre = Poly.centroid(points)
	local base = math.atan2(impactDir.y, impactDir.x)

	local hits, relAngles = {}, {}
	for k = 0, 2 do
		local a = base + k * SECTOR
		hits[k + 1] = boundaryHit(points, centre, { x = math.cos(a), y = math.sin(a) })
	end
	for i, v in ipairs(points) do
		relAngles[i] = (math.atan2(v.y - centre.y, v.x - centre.x) - base) % TWO_PI
	end

	local fragments = {}
	for k = 0, 2 do
		local lo, hi = k * SECTOR, (k + 1) * SECTOR
		local between = {}
		for i, v in ipairs(points) do
			local rel = relAngles[i]
			if rel > lo + EPS and rel < hi - EPS then
				between[#between + 1] = { rel = rel, v = v }
			end
		end
		table.sort(between, function(a, b)
			return a.rel < b.rel
		end)

		local poly = {}
		pushDistinct(poly, centre)
		pushDistinct(poly, hits[k + 1])
		for _, e in ipairs(between) do
			pushDistinct(poly, e.v)
		end
		pushDistinct(poly, hits[(k + 1) % 3 + 1])

		local c = Poly.centroid(poly)
		local local_, radius = {}, 0
		for i, p in ipairs(poly) do
			local_[i] = { x = p.x - c.x, y = p.y - c.y }
			radius = math.max(radius, math.sqrt(local_[i].x ^ 2 + local_[i].y ^ 2))
		end
		fragments[k + 1] = { vertices = local_, offset = c, area = Poly.area(poly), radius = radius }
	end

	return fragments
end

return AsteroidSplit
