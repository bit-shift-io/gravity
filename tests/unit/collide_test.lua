local Collide = require("src.sim.collide")
local Poly = require("src.core.poly")
local Vec2 = require("src.core.vec2")

-- A flat square world spanning x:[0,100], y:[0,100] -- interior is below the
-- top edge, so the top edge's outward normal points up (negative y).
local function squareWorld()
	return {
		vertices = Poly.normalize({
			{ x = 0, y = 0 },
			{ x = 100, y = 0 },
			{ x = 100, y = 100 },
			{ x = 0, y = 100 },
		}),
	}
end

-- Same L-shape fixture as tests/unit/poly_test.lua's lShape(): a reflex
-- vertex at (2, 2), with a notch (the missing top-right 2x2 square) whose
-- inner edges are (4,2)-(2,2) and (2,2)-(2,4).
local function notchWorld()
	return {
		vertices = Poly.normalize({
			{ x = 0, y = 0 },
			{ x = 4, y = 0 },
			{ x = 4, y = 2 },
			{ x = 2, y = 2 },
			{ x = 2, y = 4 },
			{ x = 0, y = 4 },
		}),
	}
end

-- Finds the outward normal of the world edge running between `a` and `b`
-- (in either direction), regardless of how Poly.normalize wound the
-- vertices -- used to compute the "expected" normal for the notch test the
-- same way Collide.polygonContact does, rather than hand-deriving it.
local function normalOfEdge(world, a, b)
	local vertices = world.vertices
	local normals = Poly.outwardNormals(vertices)
	local n = #vertices

	for i = 1, n do
		local p1 = vertices[i]
		local p2 = vertices[i % n + 1]
		local matchesForward = p1.x == a.x and p1.y == a.y and p2.x == b.x and p2.y == b.y
		local matchesBackward = p1.x == b.x and p1.y == b.y and p2.x == a.x and p2.y == a.y
		if matchesForward or matchesBackward then
			return normals[i]
		end
	end

	error("no edge found between the given points")
end

test("Collide.polygonContact returns the flat edge's outward normal when a vertex touches it", function()
	local world = squareWorld()
	-- A small triangle poking 5 units into the world through its top edge.
	local triangle = {
		{ x = 50, y = -5 },
		{ x = 60, y = -5 },
		{ x = 55, y = 5 },
	}

	local contact = Collide.polygonContact(triangle, world)

	assertTrue(contact ~= nil, "expected a contact")
	assertNear(0, contact.normal.x, 0.0001)
	assertNear(-1, contact.normal.y, 0.0001)
	assertNear(55, contact.point.x, 0.0001)
	assertNear(0, contact.point.y, 0.0001)
end)

test("Collide.polygonContact returns nil when no vertex is inside the world", function()
	local world = squareWorld()
	local triangle = {
		{ x = 50, y = -20 },
		{ x = 60, y = -20 },
		{ x = 55, y = -10 },
	}

	local contact = Collide.polygonContact(triangle, world)

	assertTrue(contact == nil)
end)

test("Collide.polygonContact reports the notch edge for a vertex resting in a concave notch", function()
	local world = notchWorld()
	-- A single-point "poke" just inside the notch's vertical inner edge
	-- (x=2 from y=2 to y=4), well away from every outer edge.
	local point = { x = 1.9, y = 3 }
	local subject = { point, point, point }

	local contact = Collide.polygonContact(subject, world)
	local expectedNormal = normalOfEdge(world, { x = 2, y = 2 }, { x = 2, y = 4 })

	assertTrue(contact ~= nil, "expected a contact")
	assertNear(expectedNormal.x, contact.normal.x, 0.0001)
	assertNear(expectedNormal.y, contact.normal.y, 0.0001)
end)

test("Collide.checkShipWorlds returns a contact with relVel equal to the body's velocity", function()
	local world = squareWorld()
	local body = { x = 55, y = -2, vx = 3, vy = 40, angle = 0 }

	local contact = Collide.checkShipWorlds(body, { world })

	assertTrue(contact ~= nil, "expected the ship's nose (at body.y - 10) to be inside the world")
	assertNear(3, contact.relVel.x)
	assertNear(40, contact.relVel.y)
	assertEqual(world, contact.world)
end)

test("Collide.checkShipWorlds returns nil when the ship touches no world", function()
	local world = squareWorld()
	local body = { x = 55, y = -50, vx = 0, vy = 0, angle = 0 }

	local contact = Collide.checkShipWorlds(body, { world })

	assertTrue(contact == nil)
end)

test("Collide.transform rotates and translates the shape", function()
	local shape = { { x = 0, y = -1 } }
	local points = Collide.transform(shape, 10, 20, math.pi / 2)

	-- Rotating (0,-1) by +90 degrees under Vec2.rotate's convention.
	local expected = Vec2.rotate({ x = 0, y = -1 }, math.pi / 2)
	assertNear(10 + expected.x, points[1].x, 0.0001)
	assertNear(20 + expected.y, points[1].y, 0.0001)
end)

-- A local-space square asteroid, 100x100 centred on its own origin --
-- matches src/game/asteroid_shape.lua's convention of centring vertices on
-- the polygon's centroid.
local function squareAsteroidVertices()
	return Poly.normalize({
		{ x = -50, y = -50 },
		{ x = 50, y = -50 },
		{ x = 50, y = 50 },
		{ x = -50, y = 50 },
	})
end

test("Collide.checkShipAsteroids finds a contact against a moved/rotated asteroid body", function()
	local asteroid = { x = 200, y = 200, angle = 0, vx = 0, vy = 0, vertices = squareAsteroidVertices() }
	-- Ship's nose (local (0,-10)) sits at world (200, 152), well inside the
	-- asteroid's square (world y from 150 to 250) when the ship body is at
	-- (200, 160).
	local body = { x = 200, y = 160, vx = 5, vy = 7, angle = 0 }

	local contact = Collide.checkShipAsteroids(body, { asteroid })

	assertTrue(contact ~= nil, "expected a contact against the asteroid")
	assertEqual(asteroid, contact.asteroid)
	assertNear(5, contact.relVel.x)
	assertNear(7, contact.relVel.y)
end)

test("Collide.checkShipAsteroids returns nil when the ship touches no asteroid", function()
	local asteroid = { x = 200, y = 200, angle = 0, vx = 0, vy = 0, vertices = squareAsteroidVertices() }
	local body = { x = 900, y = 900, vx = 0, vy = 0, angle = 0 }

	assertTrue(Collide.checkShipAsteroids(body, { asteroid }) == nil)
end)

test("Collide.checkAsteroidWorlds finds a contact when the asteroid overlaps a world", function()
	local world = squareWorld()
	local asteroid = { x = 50, y = -20, angle = 0, vertices = squareAsteroidVertices() }

	local hit = Collide.checkAsteroidWorlds(asteroid, { world })

	assertTrue(hit ~= nil, "expected the asteroid (spanning y -70..30) to overlap the world (y 0..100)")
	assertEqual(world, hit.world)
end)

test("Collide.checkAsteroidWorlds returns nil when the asteroid touches no world", function()
	local world = squareWorld()
	local asteroid = { x = 5000, y = 5000, angle = 0, vertices = squareAsteroidVertices() }

	assertTrue(Collide.checkAsteroidWorlds(asteroid, { world }) == nil)
end)

test("Collide.checkProjectileAsteroid finds a contact when the projectile's centre is inside the asteroid", function()
	local asteroid = { x = 200, y = 200, angle = 0, vertices = squareAsteroidVertices() }
	local projectile = { x = 210, y = 210 }

	local hit = Collide.checkProjectileAsteroid(projectile, asteroid)

	assertTrue(hit ~= nil, "expected the projectile's centre to be inside the asteroid")
end)

test("Collide.checkProjectileAsteroid returns nil when the projectile's centre is outside the asteroid", function()
	local asteroid = { x = 200, y = 200, angle = 0, vertices = squareAsteroidVertices() }
	local projectile = { x = 9000, y = 9000 }

	assertTrue(Collide.checkProjectileAsteroid(projectile, asteroid) == nil)
end)

test("Collide.checkHardBoundary returns nil when a body is inside the hard boundary", function()
	local boundaryRadius = 1280
	-- Body at distance 1000 with radius 10, inside boundary (1000 + 10 = 1010 < 1280)
	local hit = Collide.checkHardBoundary(1000, 0, 10, boundaryRadius)
	assertTrue(hit == nil, "expected a body inside the boundary to return nil")
end)

test("Collide.checkHardBoundary returns a contact when a body crosses the hard boundary", function()
	local boundaryRadius = 1280
	-- Body at distance 1290 with radius 10, just outside boundary (1290 - 10 = 1280, so it's at the threshold)
	-- Let's use distance 1300 to be clearly outside: 1300 > 1280 - 10 = 1270
	local hit = Collide.checkHardBoundary(1300, 0, 10, boundaryRadius)
	assertTrue(hit ~= nil, "expected a body outside the boundary to return a contact")
	assertNear(0, hit.normal.y, 0.0001, "expected normal to point outward (along positive x)")
	assertNear(1, hit.normal.x, 0.0001, "expected normal to point rightward")
end)

test("Collide.checkHardBoundary returns the correct normal for a body outside the boundary at an angle", function()
	local boundaryRadius = 1280
	-- Body at 45 degrees, distance 1500 from origin with radius 10
	-- Distance 1500 > 1280, so it's outside; plus radius 10 makes it definitely outside
	local dist = 1500
	local x = dist / math.sqrt(2)
	local y = dist / math.sqrt(2)
	local hit = Collide.checkHardBoundary(x, y, 10, boundaryRadius)
	assertTrue(hit ~= nil, "expected a body outside the boundary to return a contact")
	-- Normal should point along the direction from origin to body: (x/dist, y/dist)
	local expectedNx = x / dist
	local expectedNy = y / dist
	assertNear(expectedNx, hit.normal.x, 0.0001, "expected normal x component")
	assertNear(expectedNy, hit.normal.y, 0.0001, "expected normal y component")
end)
