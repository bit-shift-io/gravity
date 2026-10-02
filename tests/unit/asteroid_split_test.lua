local AsteroidSplit = require("src.game.asteroid_split")
local AsteroidShape = require("src.game.asteroid_shape")
local Poly = require("src.core.poly")
local Rng = require("src.core.rng")
local Config = require("src.game.config")

local function generated(seed)
	return AsteroidShape.generate(Rng.new(seed), Config.asteroid).vertices
end

test("AsteroidSplit.carve returns 3 fragments whose areas sum to the parent area", function()
	local vertices = generated(7)
	local fragments = AsteroidSplit.carve(vertices, { x = 1, y = 0 })

	assertEqual(3, #fragments)
	local sum = 0
	for _, f in ipairs(fragments) do
		sum = sum + f.area
	end
	assertNear(math.abs(Poly.area(vertices)), sum, 1e-6)
end)

local function isConvex(points)
	local n = #points
	local sign = 0
	for i = 1, n do
		local a, b, c = points[i], points[i % n + 1], points[(i + 1) % n + 1]
		local cross = (b.x - a.x) * (c.y - b.y) - (b.y - a.y) * (c.x - b.x)
		if math.abs(cross) > 1e-9 then
			local s = cross > 0 and 1 or -1
			if sign == 0 then
				sign = s
			elseif s ~= sign then
				return false
			end
		end
	end
	return n >= 3
end

local function assertValid(vertices, impact, label)
	local fragments = AsteroidSplit.carve(vertices, impact)
	assertEqual(3, #fragments, label)
	local sum = 0
	for _, f in ipairs(fragments) do
		assertTrue(#f.vertices >= 3, label .. ": fragment needs >= 3 vertices")
		assertTrue(isConvex(f.vertices), label .. ": fragment must be convex")
		assertTrue(f.area > 0 and f.radius > 0, label .. ": positive area and radius")
		sum = sum + f.area
	end
	assertNear(math.abs(Poly.area(vertices)), sum, 1e-6, label .. ": area conserved")
	return fragments
end

test("AsteroidSplit.carve gives convex fragments for random generated asteroids and impact directions", function()
	for seed = 1, 100 do
		local angle = seed * 0.37
		assertValid(generated(seed), { x = math.cos(angle), y = math.sin(angle) }, "seed " .. seed)
	end
end)

test("AsteroidSplit.carve places the first fragment's boundary on the impact direction", function()
	local vertices = generated(3)
	local angle = 2.1
	local fragments = AsteroidSplit.carve(vertices, { x = math.cos(angle), y = math.sin(angle) })
	local first = fragments[1]
	local centre = Poly.centroid(vertices)

	-- Some vertex of the first fragment (in parent space) lies on the impact ray.
	local found = false
	for _, v in ipairs(first.vertices) do
		local px, py = v.x + first.offset.x - centre.x, v.y + first.offset.y - centre.y
		local cross = px * math.sin(angle) - py * math.cos(angle)
		local dot = px * math.cos(angle) + py * math.sin(angle)
		if math.abs(cross) < 1e-6 and dot > 0 then
			found = true
		end
	end
	assertTrue(found, "expected a first-fragment vertex on the impact ray")
end)

local square = {
	{ x = -10, y = -10 },
	{ x = 10, y = -10 },
	{ x = 10, y = 10 },
	{ x = -10, y = 10 },
}

test("AsteroidSplit.carve handles an impact exactly through a vertex", function()
	assertValid(square, { x = 1, y = 1 }, "vertex")
end)

test("AsteroidSplit.carve handles an impact through an edge midpoint", function()
	assertValid(square, { x = 1, y = 0 }, "edge midpoint")
end)

test("AsteroidSplit.carve handles a thin polygon", function()
	local thin = {
		{ x = -40, y = 0 },
		{ x = -20, y = -2 },
		{ x = 20, y = -2 },
		{ x = 40, y = 0 },
		{ x = 20, y = 2 },
		{ x = -20, y = 2 },
	}
	for _, d in ipairs({ { 1, 0 }, { 0, 1 }, { 1, 0.05 }, { -1, 1 } }) do
		assertValid(thin, { x = d[1], y = d[2] }, "thin " .. d[1] .. "," .. d[2])
	end
end)

test("AsteroidSplit.carve includes vertices lying between two rays in the sector", function()
	-- Impact along +x on a square: the sector from +x to +120deg spans the
	-- (10,10) vertex, so that fragment must be a quad-or-more, not a triangle.
	local fragments = AsteroidSplit.carve(square, { x = 1, y = 0 })
	local total = 0
	for _, f in ipairs(fragments) do
		total = total + #f.vertices
	end
	assertTrue(total >= 3 + 3 + 3 + 4, "square corners must be distributed to fragments")
end)

test("AsteroidSplit.carve offsets re-centre each fragment on the parent frame", function()
	local fragments = AsteroidSplit.carve(square, { x = 1, y = 0 })
	local wx, wy = 0, 0
	for _, f in ipairs(fragments) do
		local c = Poly.centroid(f.vertices)
		assertNear(0, c.x, 1e-9)
		assertNear(0, c.y, 1e-9)
		wx = wx + f.offset.x * f.area
		wy = wy + f.offset.y * f.area
	end
	-- Area-weighted offsets recover the parent centroid (origin here).
	assertNear(0, wx, 1e-6)
	assertNear(0, wy, 1e-6)
end)
