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
