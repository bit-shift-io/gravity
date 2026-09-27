-- Convex polygon generator for asteroids (slice 09). Guarantees convexity
-- by construction: draw a handful of random candidate points, then take
-- their convex hull (Andrew's monotone chain) -- far more reliable than
-- jittering points around a circle and hoping the result stays convex,
-- which is easy to get subtly wrong. Pure -- no `love.*` (docs/
-- ARCHITECTURE.md "Layers"). Draws only from the `rng` passed in, never
-- `math.random` (this slice's Gotcha: "same seed -> same asteroid
-- sequence").
local Vec2 = require("src.core.vec2")
local Poly = require("src.core.poly")

local AsteroidShape = {}

-- Cross product of (a - o) and (b - o); sign tells which way b turns
-- relative to o->a.
local function cross(o, a, b)
	return (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x)
end

-- Andrew's monotone chain: sorts `points` (mutates the given array via
-- table.sort) and returns their convex hull, without the sort's last
-- (duplicate) point in either chain.
local function convexHull(points)
	table.sort(points, function(a, b)
		if a.x == b.x then
			return a.y < b.y
		end
		return a.x < b.x
	end)

	local lower = {}
	for _, p in ipairs(points) do
		while #lower >= 2 and cross(lower[#lower - 1], lower[#lower], p) <= 0 do
			table.remove(lower)
		end
		table.insert(lower, p)
	end

	local upper = {}
	for i = #points, 1, -1 do
		local p = points[i]
		while #upper >= 2 and cross(upper[#upper - 1], upper[#upper], p) <= 0 do
			table.remove(upper)
		end
		table.insert(upper, p)
	end

	table.remove(lower)
	table.remove(upper)

	local hull = {}
	for _, p in ipairs(lower) do
		table.insert(hull, p)
	end
	for _, p in ipairs(upper) do
		table.insert(hull, p)
	end
	return hull
end

-- A guaranteed-valid fallback shape (a small diamond) used only if the
-- random draw below somehow produces a degenerate hull (fewer than 3
-- points) -- a bounded number of retries beats an unbounded one (Guard
-- Against Hangs), and this fallback guarantees the function always
-- terminates with a valid convex polygon.
local function fallbackHull(minRadius, maxRadius)
	local r = (minRadius + maxRadius) / 2
	return {
		{ x = r, y = 0 },
		{ x = 0, y = r },
		{ x = -r, y = 0 },
		{ x = 0, y = -r },
	}
end

local MAX_ATTEMPTS = 5

-- Generates one asteroid's local-space convex polygon plus its approximate
-- circumscribed radius, drawing candidate points from `config.asteroid`'s
-- `minRadius`/`maxRadius`/`pointCount`, all via `rng` (never `math.random`).
-- The returned vertices are re-centred on the polygon's own centroid, so
-- `{x=0, y=0}` in local space is the asteroid's centre of mass -- the
-- natural origin for a spinning body. Returns
-- `{ vertices = {...}, radius = number }`.
function AsteroidShape.generate(rng, asteroidConfig)
	local minRadius = asteroidConfig.minRadius
	local maxRadius = asteroidConfig.maxRadius
	local pointCount = asteroidConfig.pointCount or 10

	local hull
	for _ = 1, MAX_ATTEMPTS do
		local points = {}
		for _ = 1, pointCount do
			local angle = rng:range(0, 2 * math.pi)
			local radius = rng:range(minRadius, maxRadius)
			table.insert(points, { x = math.cos(angle) * radius, y = math.sin(angle) * radius })
		end

		local candidate = convexHull(points)
		if #candidate >= 3 then
			hull = candidate
			break
		end
	end

	hull = hull or fallbackHull(minRadius, maxRadius)
	hull = Poly.normalize(hull)

	local centroid = Poly.centroid(hull)
	local vertices = {}
	local radius = 0
	for i, p in ipairs(hull) do
		local local_ = { x = p.x - centroid.x, y = p.y - centroid.y }
		vertices[i] = local_
		radius = math.max(radius, Vec2.length(local_))
	end

	return { vertices = vertices, radius = radius }
end

return AsteroidShape
