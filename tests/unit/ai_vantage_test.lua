local Vantage = require("src.game.ai.skills.vantage")
local Aim = require("src.game.ai.skills.aim")
local Config = require("src.game.config")
local Field = require("src.sim.field")
local Bodies = require("src.sim.bodies")

local DT = 1 / 60
local UP = { x = 0, y = -1 }

-- A floor about as heavy as a generated world, top edge y = 100.
local function floorWorld()
	return {
		vertices = { { x = -400, y = 100 }, { x = 400, y = 100 }, { x = 400, y = 200 }, { x = -400, y = 200 } },
		mass = 40000,
	}
end

local function newSim(worlds)
	local field, boundaryField = Field.bake({ worlds = worlds }, Config)
	return { field = field, boundaryField = boundaryField, bodies = Bodies.new() }
end

local function point(x, y, world, normal)
	return { x = x, y = y, normal = normal or UP, world = world }
end

-- An enemy tank hovering up and to the right of the floor.
local TARGET = { x = 300, y = -150, radius = Config.ship.collisionRadius }

local function pick(worlds, opts)
	opts.dt = opts.dt or DT
	opts.horizon = opts.horizon or 3
	return Vantage.pick(newSim(worlds), worlds, { opts.target or TARGET }, Config, opts)
end

test("Vantage.pick returns the surface point whose distance to the enemy is nearest the range", function()
	local floor = floorWorld()
	local points = { point(-200, 100, floor), point(0, 100, floor), point(200, 100, floor) }

	-- Distances to the target: ~559, ~391, ~269.
	local near = pick({ floor }, { points = points, range = 250 })
	local mid = pick({ floor }, { points = points, range = 400 })
	local far = pick({ floor }, { points = points, range = 560 })

	assertEqual(points[3], near)
	assertEqual(points[2], mid)
	assertEqual(points[1], far)
	assertEqual(UP, mid.normal)
end)

test("Vantage.pick skips a point whose shot a world blocks", function()
	local floor = floorWorld()
	-- A light, tall wall between (0, 100) and the target; (200, 100) sees past it.
	local wall = {
		vertices = { { x = 100, y = -600 }, { x = 120, y = -600 }, { x = 120, y = 60 }, { x = 100, y = 60 } },
		mass = 500,
	}
	local points = { point(0, 100, floor), point(200, 100, floor) }

	local picked = pick({ floor, wall }, { points = points, range = 400 })

	assertEqual(points[2], picked)
end)

test("Vantage.pick never picks a point whose turret can't reach the enemy", function()
	local floor = floorWorld()
	-- On the floor's right face, facing +x: the target is up and behind it.
	local side = { point(400, 150, floor, { x = 1, y = 0 }) }

	assertEqual(nil, pick({ floor }, { points = side, range = 300 }))
	local reachable = { x = 600, y = 120, radius = TARGET.radius }
	assertEqual(side[1], pick({ floor }, { points = side, range = 300, target = reachable }))
end)

test("Vantage.pick returns nil when no point has a shot within the horizon", function()
	local floor = floorWorld()
	local points = { point(-200, 100, floor), point(0, 100, floor), point(200, 100, floor) }

	assertEqual(nil, pick({ floor }, { points = points, range = 400, horizon = 0.05 }))
end)

test("Vantage.pick by default rejects points without clear space above, as spawn points do", function()
	local floor = floorWorld()
	-- A light slab 20 px over (0, 100), inside the spawn clearance height.
	local slab = {
		vertices = { { x = -60, y = 60 }, { x = 60, y = 60 }, { x = 60, y = 80 }, { x = -60, y = 80 } },
		mass = 500,
	}
	local target = { x = 0, y = -290, radius = TARGET.radius }

	local open = pick({ floor }, { range = 390, target = target })
	local covered = pick({ floor, slab }, { range = 390, target = target })

	assertEqual(0, open.x, "fixture: (0, 100) is the best point without the slab")
	assertEqual(100, open.y)
	assertFalse(covered.x == 0 and covered.y == 100, "picked the point under the slab")
end)

test("Vantage.pick solves at most config.ai.vantageSolves candidates", function()
	local floor = floorWorld()
	local points = {}
	for x = -380, 380, 20 do
		points[#points + 1] = point(x, 100, floor)
	end
	local solve, calls = Aim.solve, 0
	Aim.solve = function(...)
		calls = calls + 1
		return solve(...)
	end

	local picked = pick({ floor }, { points = points, range = 400, horizon = 0.05 })
	Aim.solve = solve

	assertEqual(nil, picked)
	assertEqual(Config.ai.vantageSolves, calls)
end)

-- A 16-sided round world of radius `r` centred on (cx, cy).
local function blob(cx, cy, r, mass)
	local vertices = {}
	for i = 0, 15 do
		local a = i / 16 * 2 * math.pi
		vertices[#vertices + 1] = { x = cx + r * math.sin(a), y = cy - r * math.cos(a) }
	end
	return { vertices = vertices, mass = mass }
end

-- The surface vertex of a blob from `blob` at `deg` degrees clockwise from
-- its top, with its outward normal.
local function onBlob(cx, cy, r, deg, world)
	local a = math.rad(deg)
	local nx, ny = math.sin(a), -math.cos(a)
	return point(cx + r * nx, cy + r * ny, world, { x = nx, y = ny })
end

-- Three generated-size worlds in a row; the middle one hides much of the
-- left one's surface from an enemy on top of the right one. From 22.5 deg
-- round the left world the enemy is in plain sight; from 67.5 deg the
-- middle world blocks the line but a lob curves round it. From 157.5 deg
-- (the left world's underside) the only lob is past the turret's limit,
-- and from the middle world's left side there is none at all.
local function hillLevel()
	local left, middle, right = blob(-400, 0, 100, 25000), blob(0, 0, 100, 25000), blob(400, 0, 100, 25000)
	return {
		worlds = { left, middle, right },
		exposed = onBlob(-400, 0, 100, 22.5, left),
		hidden = onBlob(-400, 0, 100, 67.5, left),
		under = onBlob(-400, 0, 100, 157.5, left),
		behind = onBlob(0, 0, 100, -90, middle),
		target = { x = 400, y = -108, radius = Config.ship.collisionRadius },
	}
end

-- Ranges below are near the exposed point's distance (~759 px) and far
-- from the hidden one's (~703 px), so a plain pick prefers the exposed one.
test("fixture: the hill level's exposed point is the plain vantage pick", function()
	local hill = hillLevel()

	local picked = pick(hill.worlds, { points = { hill.exposed, hill.hidden }, range = 760, target = hill.target })

	assertEqual(hill.exposed, picked)
end)

test("Vantage.pick concealed skips a point with a direct line to the enemy for one with a lob", function()
	local hill = hillLevel()

	local picked = pick(hill.worlds, { points = { hill.exposed, hill.hidden }, range = 760, target = hill.target, concealed = true })

	assertEqual(hill.hidden, picked)
end)

test("Vantage.pick concealed returns nil when no hidden point has a lob the turret can fire", function()
	local hill = hillLevel()
	local points = { hill.exposed, hill.under, hill.behind }

	assertEqual(nil, pick(hill.worlds, { points = points, range = 760, target = hill.target, concealed = true }))
end)

test("Vantage.inSight is true for a clear line and false for one a world blocks", function()
	local hill = hillLevel()
	local function stand(p)
		return { x = p.x + p.normal.x * 8, y = p.y + p.normal.y * 8 }
	end

	assertTrue(Vantage.inSight(hill.worlds, stand(hill.exposed), hill.target))
	assertFalse(Vantage.inSight(hill.worlds, stand(hill.hidden), hill.target))
end)

test("Vantage.pick concealed solves at most config.ai.concealedSolves candidates", function()
	local hill = hillLevel()
	local points = {}
	for deg = 30, 150, 5 do
		points[#points + 1] = onBlob(-400, 0, 100, deg, hill.worlds[1])
	end
	local solve, calls = Aim.solve, 0
	Aim.solve = function(...)
		calls = calls + 1
		return solve(...)
	end

	local picked = pick(hill.worlds, { points = points, range = 760, target = hill.target, horizon = 0.05, concealed = true })
	Aim.solve = solve

	assertEqual(nil, picked)
	assertEqual(Config.ai.concealedSolves, calls)
end)
