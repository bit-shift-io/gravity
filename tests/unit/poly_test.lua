local Poly = require("src.core.poly")
local Vec2 = require("src.core.vec2")

local function square()
	return {
		{ x = 0, y = 0 },
		{ x = 1, y = 0 },
		{ x = 1, y = 1 },
		{ x = 0, y = 1 },
	}
end

local function triangle()
	return {
		{ x = 0, y = 0 },
		{ x = 4, y = 0 },
		{ x = 0, y = 3 },
	}
end

-- An L-shape: a full-width band across the bottom, with a narrower leg
-- climbing the left side -- reflex vertex at (2, 2). The missing top-right
-- 2x2 square is the notch used by the pointInPolygon test below.
local function lShape()
	return {
		{ x = 0, y = 0 },
		{ x = 4, y = 0 },
		{ x = 4, y = 2 },
		{ x = 2, y = 2 },
		{ x = 2, y = 4 },
		{ x = 0, y = 4 },
	}
end

test("Poly.area returns a unit square's area", function()
	assertNear(1, math.abs(Poly.area(square())))
end)

test("Poly.area returns a right triangle's area", function()
	assertNear(6, math.abs(Poly.area(triangle())))
end)

test("Poly.area returns a concave L-shape's area", function()
	-- 4x4 bounding square (16) minus the 2x2 notch (4) = 12.
	assertNear(12, math.abs(Poly.area(lShape())))
end)

test("Poly.centroid returns a unit square's center", function()
	local c = Poly.centroid(square())
	assertNear(0.5, c.x)
	assertNear(0.5, c.y)
end)

test("Poly.centroid returns a right triangle's centroid", function()
	local c = Poly.centroid(triangle())
	assertNear(4 / 3, c.x, 0.0001)
	assertNear(1, c.y, 0.0001)
end)

test("Poly.pointInPolygon returns false for a point inside the concave notch", function()
	-- (3, 3) sits in the L-shape's missing top-right square -- inside the
	-- bounding box, but outside the actual polygon.
	assertFalse(Poly.pointInPolygon(lShape(), { x = 3, y = 3 }))
end)

test("Poly.pointInPolygon returns true for a point inside the L-shape's body", function()
	assertTrue(Poly.pointInPolygon(lShape(), { x = 1, y = 1 }))
end)

test("Poly.normalize orients vertices so Poly.area is positive", function()
	local pts = square()
	local reversed = {}
	for i = #pts, 1, -1 do
		table.insert(reversed, pts[i])
	end
	assertTrue(Poly.area(reversed) < 0, "expected the reversed square to start with negative area")

	local normalized = Poly.normalize(reversed)
	assertTrue(Poly.area(normalized) > 0)
end)

test("Poly.outwardNormals point away from the centroid on a convex shape", function()
	local normalized = Poly.normalize(square())
	local centroid = Poly.centroid(normalized)
	local normals = Poly.outwardNormals(normalized)
	local n = #normalized

	for i = 1, n do
		local p1 = normalized[i]
		local p2 = normalized[i % n + 1]
		local midpoint = Vec2.scale(Vec2.add(p1, p2), 0.5)
		local toMidpoint = Vec2.sub(midpoint, centroid)
		assertTrue(Vec2.dot(normals[i], toMidpoint) > 0, "expected normal " .. i .. " to point away from the centroid")
	end
end)

test("Poly.isSimple returns true for a plain square", function()
	assertTrue(Poly.isSimple(square()))
end)

test("Poly.isSimple returns false for a self-intersecting bowtie", function()
	local bowtie = {
		{ x = 0, y = 0 },
		{ x = 1, y = 1 },
		{ x = 1, y = 0 },
		{ x = 0, y = 1 },
	}
	assertFalse(Poly.isSimple(bowtie))
end)
