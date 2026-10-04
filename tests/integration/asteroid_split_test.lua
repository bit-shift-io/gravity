-- Large asteroids split into 3 fragments on world contact (docs/CONTEXT.md
-- "Split"); small ones are destroyed. Driven through the real frame order.
local GameHarness = require("tests.support.game_harness")
local FrameStepper = require("tests.support.frame_stepper")
local Bodies = require("src.sim.bodies")
local Poly = require("src.core.poly")
local Config = require("src.game.config")
local AsteroidSystem = require("src.game.systems.asteroid_system")
local Collide = require("src.sim.collide")

-- A wide flat platform, top surface at y = 500 (outward normal (0, -1)).
local function floorLevel()
	return {
		worlds = {
			{
				vertices = {
					{ x = -400, y = 500 },
					{ x = 1700, y = 500 },
					{ x = 1700, y = 600 },
					{ x = -400, y = 600 },
				},
				mass = 1,
			},
		},
		spawnPoints = { { x = -1000000, y = 100 }, { x = -1000000, y = 200 } },
		asteroids = { maxAlive = 0 },
	}
end

local function squareVertices(half)
	return Poly.normalize({
		{ x = -half, y = -half },
		{ x = half, y = -half },
		{ x = half, y = half },
		{ x = -half, y = half },
	})
end

local function injectAsteroid(ctx, fields)
	local vertices = fields.vertices or squareVertices(fields.half or 60)
	local body = {
		x = fields.x,
		y = fields.y,
		vx = fields.vx or 0,
		vy = fields.vy or 0,
		angle = fields.angle or 0,
		angularVelocity = fields.angularVelocity or 0,
		mass = Config.asteroid.density * math.abs(Poly.area(vertices)),
		kind = "asteroid",
		radius = fields.radius or (fields.half or 60) * 1.42,
		vertices = vertices,
	}
	local bodyId = Bodies.add(ctx.sim.bodies, body)
	local asteroid = { id = bodyId, body = bodyId, dead = false, kind = "asteroid" }
	table.insert(ctx.pools.asteroids, asteroid)
	return asteroid, body
end

local function liveAsteroids(ctx)
	local live = {}
	for _, asteroid in ipairs(ctx.pools.asteroids) do
		if not asteroid.dead then
			table.insert(live, asteroid)
		end
	end
	return live
end

test("a large asteroid driven into a world is replaced by 3 live fragments", function()
	local game = GameHarness.startMatch(floorLevel())
	local ctx = game.ctx

	-- 120x120 square (area 14400): well above the split threshold. Its
	-- bottom edge (y = 460 + 60) already dips 20px into the platform.
	local parent = injectAsteroid(ctx, { x = 800, y = 460, vx = 0, vy = 40 })

	FrameStepper.step(game, 1)

	assertTrue(parent.dead, "expected the parent asteroid to be dead")
	assertEqual(3, #liveAsteroids(ctx), "expected exactly 3 live fragments")
end)

test("a small asteroid driven into a world is destroyed without fragments", function()
	local game = GameHarness.startMatch(floorLevel())
	local ctx = game.ctx

	-- 40x40 square (area 1600): below the split threshold.
	local small = injectAsteroid(ctx, { x = 800, y = 480, half = 20, vy = 40 })

	FrameStepper.step(game, 1)

	assertTrue(small.dead, "expected the small asteroid to be dead")
	assertEqual(0, #liveAsteroids(ctx), "expected no fragments")
end)

test("fragments carry density x area mass, own radius, and parent velocity plus nudge", function()
	local game = GameHarness.startMatch(floorLevel())
	local ctx = game.ctx

	local _, parentBody = injectAsteroid(ctx, {
		x = 800,
		y = 460,
		vx = 30,
		vy = 40,
		angularVelocity = 0.25,
	})
	local origin = { x = parentBody.x, y = parentBody.y }
	local parentVx, parentVy = parentBody.vx, parentBody.vy

	FrameStepper.step(game, 1)

	local live = liveAsteroids(ctx)
	assertEqual(3, #live)
	for _, asteroid in ipairs(live) do
		local body = Bodies.get(ctx.sim.bodies, asteroid.body)
		assertEqual("asteroid", body.kind)
		assertNear(Config.asteroid.density * math.abs(Poly.area(body.vertices)), body.mass, 1e-6)
		local radius = 0
		for _, v in ipairs(body.vertices) do
			radius = math.max(radius, math.sqrt(v.x * v.x + v.y * v.y))
		end
		assertNear(radius, body.radius, 1e-6)
		assertNear(0.25, body.angularVelocity, 1e-9)

		-- Tangential velocity is parent velocity + nudge along centre ->
		-- fragment; the component into the floor is replaced by a shove off it.
		local away = { x = body.x - origin.x, y = body.y - origin.y }
		if math.abs(away.x) > 1 then
			assertTrue((body.vx - parentVx) * away.x > 0, "expected nudge along centre -> fragment")
		end
		assertTrue(body.vy < 0, "expected fragment moving off the floor")
	end
end)

test("fragments no longer overlap the world after the split", function()
	local game = GameHarness.startMatch(floorLevel())
	local ctx = game.ctx
	injectAsteroid(ctx, { x = 800, y = 460, vy = 40 })

	FrameStepper.step(game, 1)

	local world = ctx.level.worlds[1]
	for _, asteroid in ipairs(liveAsteroids(ctx)) do
		local body = Bodies.get(ctx.sim.bodies, asteroid.body)
		assertEqual(nil, Collide.checkAsteroidWorlds(body, { world }), "fragment still overlaps the world")
	end
end)

test("an asteroid named by two contacts in one step splits at most once", function()
	local game = GameHarness.startMatch(floorLevel())
	local ctx = game.ctx
	local _, body = injectAsteroid(ctx, { x = 800, y = 460 })
	local world = ctx.level.worlds[1]
	local contact = {
		kind = "asteroidWorld",
		a = body,
		b = world,
		point = { x = 800, y = 500 },
		normal = { x = 0, y = -1 },
	}

	AsteroidSystem.handleContacts(ctx, { contact, contact })

	assertEqual(3, #liveAsteroids(ctx), "expected one split only")
	assertEqual(4, #ctx.pools.asteroids)
end)

test("a contact at the parent centre falls back to the reversed normal", function()
	local game = GameHarness.startMatch(floorLevel())
	local ctx = game.ctx
	local _, body = injectAsteroid(ctx, { x = 800, y = 460 })
	local contact = {
		kind = "asteroidWorld",
		a = body,
		b = ctx.level.worlds[1],
		point = { x = 800, y = 460 },
		normal = { x = 0, y = -1 },
	}

	AsteroidSystem.handleContacts(ctx, { contact })

	assertEqual(3, #liveAsteroids(ctx))
end)

test("repeated grazing never cascades: live fragments stay bounded", function()
	local game = GameHarness.startMatch(floorLevel())
	local ctx = game.ctx
	injectAsteroid(ctx, { x = 800, y = 470, vy = 60, angularVelocity = 0.3 })

	for _ = 1, 600 do
		FrameStepper.step(game, 1)
		assertTrue(#liveAsteroids(ctx) <= 9, "expected splits not to cascade")
	end
end)

test("the same seed gives identical fragments", function()
	local function run()
		local game = GameHarness.startMatch(floorLevel(), { seed = 7 })
		local ctx = game.ctx
		injectAsteroid(ctx, { x = 800, y = 460, vx = 15, vy = 40, angularVelocity = 0.2 })
		FrameStepper.step(game, 1)
		local out = {}
		for _, asteroid in ipairs(liveAsteroids(ctx)) do
			local b = Bodies.get(ctx.sim.bodies, asteroid.body)
			table.insert(out, { b.x, b.y, b.vx, b.vy, b.mass, b.radius, #b.vertices })
		end
		return out
	end

	local first, second = run(), run()
	assertTrue(#first > 0)
	assertEqual(#first, #second)
	for i = 1, #first do
		for j = 1, 7 do
			assertEqual(first[i][j], second[i][j])
		end
	end
end)

-- Open space: no worlds, ships parked far away unless a test moves one.
local function openLevel()
	return {
		worlds = {},
		spawnPoints = { { x = -1000000, y = 100 }, { x = -1000000, y = 200 } },
		asteroids = { maxAlive = 0 },
	}
end

local function injectProjectile(ctx, x, y)
	local config = Config.projectile
	local bodyId = Bodies.add(ctx.sim.bodies, {
		x = x, y = y, vx = 0, vy = 0, angle = 0,
		mass = config.mass, kind = "projectile", radius = config.radius, armed = false,
	})
	local projectile = { id = bodyId, body = bodyId, shooter = 1, dead = false, age = 0 }
	table.insert(ctx.pools.projectiles, projectile)
	return projectile
end

local function placeShipAt(ctx, x, y)
	local ship = ctx.pools.ships[1]
	local body = Bodies.get(ctx.sim.bodies, ship.body)
	body.x, body.y, body.vx, body.vy = x, y, 0, 20
	return ship
end

test("a ship ramming a large asteroid crashes and the asteroid splits into 3 fragments", function()
	local game = GameHarness.startMatch(openLevel())
	local ctx = game.ctx
	-- 60x60 square (area 3600) centred (800, 400): top edge y = 370.
	local parent = injectAsteroid(ctx, { x = 800, y = 400, half = 30 })
	local ship = placeShipAt(ctx, 800, 372)

	FrameStepper.step(game, 1)

	assertTrue(ship.dead, "expected the ship to crash")
	assertTrue(parent.dead, "expected the parent asteroid to be dead")
	assertEqual(3, #liveAsteroids(ctx), "expected exactly 3 live fragments")
end)

test("a ship ramming a small asteroid crashes and the asteroid is destroyed", function()
	local game = GameHarness.startMatch(openLevel())
	local ctx = game.ctx
	local parent = injectAsteroid(ctx, { x = 800, y = 400, half = 20 })
	local ship = placeShipAt(ctx, 800, 382)

	FrameStepper.step(game, 1)

	assertTrue(ship.dead, "expected the ship to crash")
	assertTrue(parent.dead, "expected the small asteroid to be destroyed")
	assertEqual(0, #liveAsteroids(ctx), "expected no fragments")
end)

test("a projectile hitting a large asteroid splits it into fragments carrying the pushed velocity", function()
	local game = GameHarness.startMatch(openLevel())
	local ctx = game.ctx
	local parent, parentBody = injectAsteroid(ctx, { x = 800, y = 400, half = 30 })
	-- Inside the left edge: the blast pushes the asteroid towards +x.
	local projectile = injectProjectile(ctx, 780, 400)

	FrameStepper.step(game, 1)

	assertTrue(projectile.dead, "expected the projectile to detonate")
	assertTrue(parent.dead, "expected the parent asteroid to be dead")
	local live = liveAsteroids(ctx)
	assertEqual(3, #live, "expected exactly 3 live fragments")
	assertTrue(parentBody.vx > Config.asteroid.splitNudgeSpeed, "expected the push to dominate the nudge, got " .. parentBody.vx)
	for _, asteroid in ipairs(live) do
		local b = Bodies.get(ctx.sim.bodies, asteroid.body)
		assertTrue(b.vx >= parentBody.vx - Config.asteroid.splitNudgeSpeed - 1e-6, "fragment vx " .. b.vx .. " lacks the push " .. parentBody.vx)
	end
end)

test("a projectile hitting a small asteroid pushes it but it survives", function()
	local game = GameHarness.startMatch(openLevel())
	local ctx = game.ctx
	local asteroid, body = injectAsteroid(ctx, { x = 800, y = 400, half = 20 })
	local projectile = injectProjectile(ctx, 785, 400)

	FrameStepper.step(game, 1)

	assertTrue(projectile.dead, "expected the projectile to detonate")
	assertTrue(not asteroid.dead, "expected the small asteroid to survive")
	assertEqual(1, #liveAsteroids(ctx))
	assertTrue(body.vx > 0, "expected the asteroid to be pushed towards +x")
end)

test("fragments of a world split get clear of the world instead of re-touching it", function()
	local game = GameHarness.startMatch(floorLevel())
	local ctx = game.ctx
	injectAsteroid(ctx, { x = 800, y = 460, vx = 0, vy = 90 })

	FrameStepper.step(game, 1)
	local fragments = {}
	for _, asteroid in ipairs(liveAsteroids(ctx)) do
		table.insert(fragments, asteroid)
	end
	assertEqual(3, #fragments)

	FrameStepper.step(game, 10)

	for _, fragment in ipairs(fragments) do
		assertTrue(not fragment.dead, "expected fragment to survive separating from the world")
	end
end)

test("fragments of a split all move away from the split centre", function()
	local game = GameHarness.startMatch(floorLevel())
	local ctx = game.ctx
	injectAsteroid(ctx, { x = 800, y = 460, vx = 0, vy = 0 })

	FrameStepper.step(game, 1)

	local bodies = {}
	local cx, cy = 0, 0
	for i, asteroid in ipairs(liveAsteroids(ctx)) do
		bodies[i] = Bodies.get(ctx.sim.bodies, asteroid.body)
		cx, cy = cx + bodies[i].x / 3, cy + bodies[i].y / 3
	end
	local mvx, mvy = 0, 0
	for _, b in ipairs(bodies) do
		mvx, mvy = mvx + b.vx / 3, mvy + b.vy / 3
	end
	for _, b in ipairs(bodies) do
		local outward = (b.x - cx) * (b.vx - mvx) + (b.y - cy) * (b.vy - mvy)
		assertTrue(outward > 0, "expected fragment velocity to point away from the centre")
	end
end)
