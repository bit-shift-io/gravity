local AsteroidShape = require("src.game.asteroid_shape")
local Poly = require("src.core.poly")
local Rng = require("src.core.rng")
local Config = require("src.game.config")

-- Independent convexity check (no such helper exists yet elsewhere in the
-- codebase) -- true when every triple of consecutive vertices turns the
-- same way, i.e. the cross product of consecutive edges never changes
-- sign. Winding-independent (checks consistency, not a particular sign).
local function isConvex(points)
	local n = #points
	if n < 3 then
		return false
	end

	local sign = 0
	for i = 1, n do
		local a = points[i]
		local b = points[i % n + 1]
		local c = points[(i + 1) % n + 1]
		local edge1 = { x = b.x - a.x, y = b.y - a.y }
		local edge2 = { x = c.x - b.x, y = c.y - b.y }
		local cross = edge1.x * edge2.y - edge1.y * edge2.x

		if cross ~= 0 then
			if sign == 0 then
				sign = cross > 0 and 1 or -1
			elseif (cross > 0 and sign < 0) or (cross < 0 and sign > 0) then
				return false
			end
		end
	end

	return true
end

test("AsteroidShape.generate produces a simple, convex polygon across many seeds", function()
	for seed = 1, 100 do
		local rng = Rng.new(seed)
		local shape = AsteroidShape.generate(rng, Config.asteroid)

		assertTrue(#shape.vertices >= 3, "expected at least 3 vertices")
		assertTrue(Poly.isSimple(shape.vertices), "expected a simple polygon for seed " .. seed)
		assertTrue(isConvex(shape.vertices), "expected a convex polygon for seed " .. seed)
	end
end)

test("AsteroidShape.generate returns a positive circumscribed radius", function()
	local rng = Rng.new(5)
	local shape = AsteroidShape.generate(rng, Config.asteroid)

	assertTrue(shape.radius > 0, "expected a positive radius")
end)

test("AsteroidShape.generate: the same seed produces the same shape", function()
	local shapeA = AsteroidShape.generate(Rng.new(123), Config.asteroid)
	local shapeB = AsteroidShape.generate(Rng.new(123), Config.asteroid)

	assertEqual(#shapeA.vertices, #shapeB.vertices)
	for i, v in ipairs(shapeA.vertices) do
		assertNear(v.x, shapeB.vertices[i].x, 0.0000001)
		assertNear(v.y, shapeB.vertices[i].y, 0.0000001)
	end
end)
