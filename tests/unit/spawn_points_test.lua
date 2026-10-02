local SpawnPoints = require("src.game.spawn_points")
local Config = require("src.game.config")
local Poly = require("src.core.poly")
local Vec2 = require("src.core.vec2")

-- Two squares (y down) well apart: a left block and a right block.
local function twoBlocks()
	return {
		{ vertices = { { x = -300, y = -50 }, { x = -200, y = -50 }, { x = -200, y = 50 }, { x = -300, y = 50 } } },
		{ vertices = { { x = 200, y = -50 }, { x = 300, y = -50 }, { x = 300, y = 50 }, { x = 200, y = 50 } } },
	}
end

local function distanceToSegment(p, a, b)
	local ab = Vec2.sub(b, a)
	local t = Vec2.dot(Vec2.sub(p, a), ab) / Vec2.dot(ab, ab)
	t = math.max(0, math.min(1, t))
	local closest = Vec2.add(a, Vec2.scale(ab, t))
	return Vec2.length(Vec2.sub(p, closest))
end

local function onSomeEdge(worlds, p)
	for _, world in ipairs(worlds) do
		local v = world.vertices
		for i = 1, #v do
			if distanceToSegment(p, v[i], v[i % #v + 1]) < 1e-6 then
				return true
			end
		end
	end
	return false
end

test("SpawnPoints.choose returns two points that lie on world edges", function()
	local worlds = twoBlocks()
	local points = SpawnPoints.choose(worlds, Config)

	assertEqual(2, #points)
	assertTrue(onSomeEdge(worlds, points[1]), "first point not on an edge")
	assertTrue(onSomeEdge(worlds, points[2]), "second point not on an edge")
end)

test("SpawnPoints.choose gives each point a unit normal pointing out of the world", function()
	local worlds = twoBlocks()
	local points = SpawnPoints.choose(worlds, Config)

	for _, p in ipairs(points) do
		assertTrue(math.abs(Vec2.length(p.normal) - 1) < 1e-6, "normal not unit length")
		local above = { x = p.x + p.normal.x * 5, y = p.y + p.normal.y * 5 }
		for _, world in ipairs(worlds) do
			assertTrue(not Poly.pointInPolygon(world.vertices, above), "normal points into a world")
		end
	end
end)

test("SpawnPoints.choose records the world each point sits on", function()
	local worlds = twoBlocks()
	local points = SpawnPoints.choose(worlds, Config)

	assertEqual(worlds[1], points[1].world)
	assertEqual(worlds[2], points[2].world)
end)

test("SpawnPoints.choose picks the farthest-apart pair of valid points", function()
	local points = SpawnPoints.choose(twoBlocks(), Config)

	-- The far corners' outer faces are the widest-separated valid samples:
	-- the left block's left face and the right block's right face.
	assertEqual(-300, points[1].x)
	assertEqual(300, points[2].x)
end)

-- A floor block with a hood world 20px above its top face.
local function floorUnderHood()
	return {
		{ vertices = { { x = 200, y = 0 }, { x = 400, y = 0 }, { x = 400, y = 50 }, { x = 200, y = 50 } } },
		{ vertices = { { x = 190, y = -40 }, { x = 410, y = -40 }, { x = 410, y = -20 }, { x = 190, y = -20 } } },
	}
end

test("SpawnPoints.hasClearance is false for a point under a low overhang", function()
	local point = { x = 300, y = 0, normal = { x = 0, y = -1 } }

	assertTrue(not SpawnPoints.hasClearance(floorUnderHood(), point, Config))
end)

test("SpawnPoints.hasClearance is false for a point at the bottom of a narrow notch", function()
	-- A 10px-wide slot cut down into a block; its floor is at y = 30.
	local worlds = {
		{
			vertices = {
				{ x = 0, y = 0 }, { x = 95, y = 0 }, { x = 95, y = 30 }, { x = 105, y = 30 },
				{ x = 105, y = 0 }, { x = 200, y = 0 }, { x = 200, y = 80 }, { x = 0, y = 80 },
			},
		},
	}
	local point = { x = 100, y = 30, normal = { x = 0, y = -1 } }

	assertTrue(not SpawnPoints.hasClearance(worlds, point, Config))
end)

test("SpawnPoints.hasClearance is true for a point in open space above a surface", function()
	local point = { x = 300, y = 50, normal = { x = 0, y = 1 } }

	assertTrue(SpawnPoints.hasClearance(floorUnderHood(), point, Config))
end)

test("SpawnPoints.hasClearance rejects a point on the wall of a narrow U gap", function()
	-- A U opening upward (y down): two 50-wide arms with a 30-wide slot between.
	local u = {
		{ x = -65, y = -100 }, { x = -15, y = -100 }, { x = -15, y = 0 }, { x = 15, y = 0 },
		{ x = 15, y = -100 }, { x = 65, y = -100 }, { x = 65, y = 50 }, { x = -65, y = 50 },
	}
	local worlds = { { vertices = u } }
	-- On the left arm's inner wall, normal pointing across the slot.
	local inWall = { x = -15, y = -50, normal = { x = 1, y = 0 } }
	assertTrue(not SpawnPoints.hasClearance(worlds, inWall, Config), "slot is narrower than the clear height")
	-- On the top of the left arm, open sky above.
	local onTop = { x = -40, y = -100, normal = { x = 0, y = -1 } }
	assertTrue(SpawnPoints.hasClearance(worlds, onTop, Config))
end)
