local Match = require("src.game.match")
local Config = require("src.game.config")
local Bodies = require("src.sim.bodies")
local SpawnPoints = require("src.game.spawn_points")
local LevelGen = require("src.game.level_gen")

test("Match.new builds a ctx with the shape systems expect", function()
	local level = { worlds = {} }
	local ctx = Match.new(level, Config)

	assertEqual(0, ctx.time)
	assertEqual(level, ctx.level)
	assertEqual(Config, ctx.config)
	assertTrue(ctx.pools ~= nil)
	assertTrue(ctx.sim ~= nil)
	assertTrue(ctx.intents ~= nil)
	assertTrue(ctx.events ~= nil)
end)

test("Match.new bakes the static gravity field into ctx.sim.field", function()
	local level = { worlds = {} }
	local ctx = Match.new(level, Config)

	assertTrue(ctx.sim.field ~= nil)
	assertTrue(ctx.sim.field.cols > 0)
	assertTrue(ctx.sim.field.rows > 0)
end)

test("Match.new bakes the boundary anti-gravity field into ctx.sim.boundaryField", function()
	local level = { worlds = {} }
	local ctx = Match.new(level, Config)

	assertTrue(ctx.sim.boundaryField ~= nil)
	assertTrue(ctx.sim.boundaryField.cols > 0)
	assertTrue(ctx.sim.boundaryField.rows > 0)
end)

test("Match.step exists and does not error on an empty ctx", function()
	local ctx = Match.new({ worlds = {} }, Config)
	ctx.dt = 1 / 60
	Match.step(ctx)
end)

-- A flat floor block with a spawn point on its top face (y = 0, outward
-- normal up). `spawn` is merged over the default top-face spawn.
local function floorLevel(spawn)
	local world = {
		vertices = { { x = -100, y = 0 }, { x = 100, y = 0 }, { x = 100, y = 40 }, { x = -100, y = 40 } },
		mass = 1000,
	}
	local point = { x = 0, y = 0, normal = { x = 0, y = -1 }, world = world }
	for k, v in pairs(spawn or {}) do
		point[k] = v
	end
	return { worlds = { world }, spawnPoints = { point } }
end

test("Match.new starts a ship with a spawn normal as a pinned upright tank", function()
	local ctx = Match.new(floorLevel(), Config)
	local ship = ctx.pools.ships[1]
	local body = Bodies.get(ctx.sim.bodies, ship.body)

	assertTrue(body.pinned)
	assertEqual("tank", ship.lander.state)
	assertEqual(ctx.level.worlds[1], ship.lander.host)
	assertEqual(0, ship.turret.angle)
	assertEqual(Config.ship.fuel.capacity, ship.fuel.amount)
	assertEqual(0, body.angle)
end)

test("Match.new lifts a tank ship so its hull sits on the surface, not in it", function()
	local ctx = Match.new(floorLevel(), Config)
	local body = Bodies.get(ctx.sim.bodies, ctx.pools.ships[1].body)

	assertTrue(body.y < 0, "ship centre should sit above the surface")
end)

test("Match.new starts a ship without a spawn normal flying and unpinned", function()
	local ctx = Match.new(floorLevel({ normal = false }), Config)
	local ship = ctx.pools.ships[1]
	local body = Bodies.get(ctx.sim.bodies, ship.body)

	assertTrue(not body.pinned)
	assertEqual("flying", ship.lander.state)
end)

test("Match.step keeps chosen-spawn tanks alive and landed for 120 steps with no input", function()
	local level = {
		worlds = {
			{ vertices = { { x = -300, y = 0 }, { x = -200, y = 0 }, { x = -200, y = 100 }, { x = -300, y = 100 } }, mass = 20000 },
			{ vertices = { { x = 200, y = 0 }, { x = 300, y = 0 }, { x = 300, y = 100 }, { x = 200, y = 100 } }, mass = 20000 },
		},
	}
	level.spawnPoints = SpawnPoints.choose(level.worlds, Config)
	local ctx = Match.new(level, Config)
	ctx.dt = 1 / 60

	for _ = 1, 120 do
		Match.step(ctx)
	end

	assertEqual(2, #ctx.pools.ships)
	for _, ship in ipairs(ctx.pools.ships) do
		assertTrue(not ship.dead)
		assertEqual("tank", ship.lander.state)
	end
end)

test("Match.step keeps both ships alive as tanks for 120 steps on generated levels", function()
	for seed = 1, 20 do
		local ctx = Match.new(LevelGen.generate(seed, Config), Config)
		ctx.dt = 1 / 60

		for _ = 1, 120 do
			Match.step(ctx)
		end

		assertEqual(2, #ctx.pools.ships)
		for _, ship in ipairs(ctx.pools.ships) do
			assertTrue(not ship.dead, "seed " .. seed .. " ship died")
			assertEqual("tank", ship.lander.state, "seed " .. seed)
		end
	end
end)

test("Match.step keeps both ships alive as tanks for 120 steps on snake-only levels", function()
	local config = {}
	for k, v in pairs(Config) do
		config[k] = v
	end
	config.levelGen = {}
	for k, v in pairs(Config.levelGen) do
		config.levelGen[k] = v
	end
	config.levelGen.snakeChance = 1
	for seed = 1, 20 do
		local ctx = Match.new(LevelGen.generate(seed, config), config)
		ctx.dt = 1 / 60

		for _ = 1, 120 do
			Match.step(ctx)
		end

		assertEqual(2, #ctx.pools.ships)
		for _, ship in ipairs(ctx.pools.ships) do
			assertTrue(not ship.dead, "seed " .. seed .. " ship died")
			assertEqual("tank", ship.lander.state, "seed " .. seed)
		end
	end
end)

local function sixPointLevel(candidateCount)
	local world = {
		vertices = { { x = -400, y = 0 }, { x = 400, y = 0 }, { x = 400, y = 40 }, { x = -400, y = 40 } },
		mass = 1000,
	}
	local candidates = {}
	for i = 1, candidateCount do
		candidates[i] = { x = -350 + i * 60, y = 0, normal = { x = 0, y = -1 }, world = world }
	end
	return { worlds = { world }, spawnPoints = { candidates[1], candidates[candidateCount] }, spawnCandidates = candidates }
end

local function aiRoster(n)
	local roster = {}
	for i = 1, n do
		roster[i] = { color = i, binding = { kind = "ai", level = "easy" } }
	end
	return roster
end

test("Match.new defaults to a two-slot roster", function()
	local ctx = Match.new(sixPointLevel(8), Config, 1)
	assertEqual(2, #ctx.roster)
	assertEqual(2, #ctx.pools.ships)
	assertEqual(2, #ctx.round.score)
end)

test("Match.new spawns one ship per roster slot on distinct points, slot index as player", function()
	local ctx = Match.new(sixPointLevel(8), Config, 5, { roster = aiRoster(6) })
	assertEqual(6, #ctx.pools.ships)
	local seen = {}
	for i, ship in ipairs(ctx.pools.ships) do
		assertEqual(i, ship.player)
		local body = Bodies.get(ctx.sim.bodies, ship.body)
		assertTrue(not seen[body.x], "two ships share a point")
		seen[body.x] = true
	end
end)

test("Match.new draws round 1 spawns from the level's spawn candidates", function()
	local level = sixPointLevel(8)
	local ctx = Match.new(level, Config, 5, { roster = aiRoster(4) })
	local isCandidate = {}
	for _, point in ipairs(level.spawnCandidates) do
		isCandidate[point.x] = true
	end
	for _, ship in ipairs(ctx.pools.ships) do
		assertTrue(isCandidate[Bodies.get(ctx.sim.bodies, ship.body).x], "ship is not on a candidate")
	end
end)

test("Match.new spawns no more ships than the level has spawn candidates", function()
	local ctx = Match.new(sixPointLevel(4), Config, 5, { roster = aiRoster(6) })
	assertEqual(4, #ctx.pools.ships)
end)

test("the camera frames a living ship that is far from the others", function()
	local ctx = Match.new(sixPointLevel(8), Config, 5, { roster = aiRoster(3) })
	ctx.dt = 1 / 60
	local body = Bodies.get(ctx.sim.bodies, ctx.pools.ships[3].body)
	body.x, body.y = 0, -900
	ctx.camera.zoom = 1
	Match.step(ctx)
	assertTrue(ctx.camera.zoom < 1, "zoom must back off to keep the far ship in frame")
end)
