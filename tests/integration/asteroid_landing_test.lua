-- Exercises ship-vs-asteroid landing and riding through the real frame
-- order (Sim.integrate -> ShipSystem.followRiders -> Sim.collide's
-- "shipAsteroid" contacts -> ShipSystem.handleContacts), the same way
-- tests/integration/landing_test.lua exercises ship-vs-world landing.
-- Asteroids are injected directly (a literal body + pool record, bypassing
-- src/game/systems/asteroid_system.lua's random spawner) so the test
-- controls the asteroid's exact position/velocity/spin, per docs/
-- ARCHITECTURE.md's "tests pass literal level tables, never generated
-- levels, unless the test targets the generator".
local GameHarness = require("tests.support.game_harness")
local FrameStepper = require("tests.support.frame_stepper")
local Bodies = require("src.sim.bodies")
local Poly = require("src.core.poly")

-- A 200x200 square asteroid, local-space vertices centred on its own
-- centroid (matching src/game/asteroid_shape.lua's convention) -- wide
-- enough that a ship landing near its top centre never lands off an edge.
local function squareAsteroidVertices()
	return Poly.normalize({
		{ x = -100, y = -100 },
		{ x = 100, y = -100 },
		{ x = 100, y = 100 },
		{ x = -100, y = 100 },
	})
end

-- Injects an asteroid body + pool record directly into `ctx`, mirroring
-- src/game/systems/asteroid_system.lua's own spawnAsteroid shape.
local function injectAsteroid(ctx, fields)
	local body = {
		x = fields.x,
		y = fields.y,
		vx = fields.vx or 0,
		vy = fields.vy or 0,
		angle = fields.angle or 0,
		angularVelocity = fields.angularVelocity or 0,
		mass = fields.mass or 500,
		kind = "asteroid",
		radius = fields.radius or 141,
		vertices = fields.vertices or squareAsteroidVertices(),
		refuelMultiplier = ctx.config.asteroid.refuelMultiplier,
		riders = {},
	}
	local bodyId = Bodies.add(ctx.sim.bodies, body)
	local asteroid = { id = bodyId, body = bodyId, dead = false, kind = "asteroid" }
	table.insert(ctx.pools.asteroids, asteroid)
	return asteroid, body
end

-- No worlds, no auto-spawner (maxAlive = 0 -- the test injects its own
-- asteroid instead), one ship spawn point.
local function bareLevel(spawnPoints)
	return {
		worlds = {},
		spawnPoints = spawnPoints,
		asteroids = { maxAlive = 0 },
	}
end

test("a ship matched to a drifting spinning asteroid lands and rides, then refuels faster than on a world", function()
	local level = bareLevel({ { x = 640, y = 100 }, { x = -1000000, y = 100 } })
	local game = GameHarness.startMatch(level)
	local ctx = game.ctx
	local ship = ctx.pools.ships[1]
	local shipBody = Bodies.get(ctx.sim.bodies, ship.body)

	local spin = 0.1
	local asteroid, asteroidBody = injectAsteroid(ctx, {
		x = 640,
		y = 300,
		vx = 15,
		vy = 0,
		angularVelocity = spin,
		angle = 0,
	})

	-- Ship starts already touching the asteroid's top edge (asteroid top at
	-- world y = 300 - 100 = 200, its base corners already a few px past it)
	-- so contact is detected on the very first frame -- this deliberately
	-- avoids a long simulated fall, since the ship's own mass (config.ship.mass
	-- = 40000, tuned for ship-vs-ship gravity feel) would otherwise pull
	-- hard on the much lighter injected asteroid at close range over many
	-- frames and perturb the approach unpredictably. Velocity matches the
	-- asteroid's own linear velocity plus the small tangential term its
	-- spin adds at that point (omega x r, r ~= (0,-100)), plus a slow,
	-- landing-safe descent component.
	shipBody.x = 640
	shipBody.y = 201
	shipBody.vx = 15 + spin * 100
	shipBody.vy = 10
	shipBody.angle = 0
	ship.fuel.amount = 0

	FrameStepper.step(game, 5) -- lands within the first frame

	assertEqual("riding", ship.lander.state, "expected the ship to be riding the asteroid")
	assertTrue(shipBody.pinned, "expected a riding ship's body to be pinned")
	assertEqual(asteroidBody, ship.lander.host, "expected the ship's host to be the asteroid body")

	-- Riders move and rotate with the asteroid: advance the asteroid (drift
	-- + spin) for a while longer and check the ship tracked it rather than
	-- staying at its landing-time position.
	local hostXBefore, hostYBefore, hostAngleBefore = asteroidBody.x, asteroidBody.y, asteroidBody.angle
	FrameStepper.step(game, 60)

	assertTrue(asteroidBody.x ~= hostXBefore, "expected the asteroid to have kept drifting")
	assertTrue(asteroidBody.angle ~= hostAngleBefore, "expected the asteroid to have kept spinning")

	-- The ship's offset from the host, in the host's OWN rotated frame,
	-- should be unchanged from the moment it landed -- i.e. it moved and
	-- rotated together with the host rather than drifting away from it.
	-- (Rotation preserves distance from the host's centre, so this distance
	-- should be exactly whatever it was the instant landing snapped the
	-- ship's position -- not a specific expected number, since the exact
	-- contact point depends on which ship vertex touched first.)
	local dx, dy = shipBody.x - asteroidBody.x, shipBody.y - asteroidBody.y
	local distAtLandingTime = math.sqrt(dx * dx + dy * dy)
	FrameStepper.step(game, 1)
	local dx2, dy2 = shipBody.x - asteroidBody.x, shipBody.y - asteroidBody.y
	local distNow = math.sqrt(dx2 * dx2 + dy2 * dy2)
	assertNear(distAtLandingTime, distNow, 0.01, "expected the ship to stay at a fixed distance from the asteroid's centre")

	-- Refuels faster than a world (config.landing.refuelRate x
	-- config.asteroid.refuelMultiplier vs plain refuelRate). A short window
	-- (0.1s), well clear of config.ship.fuel.capacity, so the gain isn't
	-- clamped by a full tank before the comparison can tell "faster" from
	-- "capped".
	ship.fuel.amount = 0
	FrameStepper.step(game, 6) -- 0.1s
	local gained = ship.fuel.amount
	local worldRate = ctx.config.landing.refuelRate
	local expectedRidingGain = worldRate * ctx.config.asteroid.refuelMultiplier * 0.1
	assertTrue(gained > worldRate * 0.1 * 1.05, "expected riding to refuel noticeably faster than a world's plain rate")
	assertNear(expectedRidingGain, gained, expectedRidingGain * 0.05)
end)

test("an asteroid hitting a world kills its rider", function()
	local level = {
		worlds = {
			{
				vertices = {
					{ x = -2000, y = 900 },
					{ x = 2000, y = 900 },
					{ x = 2000, y = 1200 },
					{ x = -2000, y = 1200 },
				},
				mass = 1,
			},
		},
		spawnPoints = { { x = 640, y = 100 }, { x = -1000000, y = 100 } },
		asteroids = { maxAlive = 0 },
	}
	local game = GameHarness.startMatch(level)
	local ctx = game.ctx
	local ship = ctx.pools.ships[1]
	local shipBody = Bodies.get(ctx.sim.bodies, ship.body)
	local shipBodyId = ship.body

	-- Place the asteroid already overlapping the world so it dies on the
	-- very first frame, with the ship already riding it (wired up directly
	-- via the same bookkeeping ShipSystem.handleContacts' "shipAsteroid"
	-- land branch performs, since this test's focus is "dies with host",
	-- not re-proving the landing decision the previous test already covers).
	local Lander = require("src.game.components.lander")
	local asteroid, asteroidBody = injectAsteroid(ctx, {
		x = 640,
		y = 850,
		vx = 0,
		vy = 50,
		angularVelocity = 0,
	})

	shipBody.x = 640
	shipBody.y = 750
	shipBody.angle = 0
	shipBody.pinned = true
	Lander.startRiding(ship, asteroidBody, shipBody)
	ship.fuel.amount = 5

	FrameStepper.step(game, 30)

	assertTrue(ship.dead or Bodies.get(ctx.sim.bodies, shipBodyId) == nil, "expected the riding ship to die with its host asteroid")
	assertEqual(0, #ctx.pools.asteroids, "expected the destroyed asteroid's record to be swept")
end)
