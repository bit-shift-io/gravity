-- Exercises asteroid-vs-asteroid bounce and projectile-vs-asteroid contacts
-- through the real frame order (Sim.collide's "asteroidAsteroid"/
-- "projectileAsteroid" contacts -> AsteroidSystem.handleContacts), the same
-- way tests/integration/ship_bounce_test.lua exercises ship-vs-ship bounce.
local GameHarness = require("tests.support.game_harness")
local FrameStepper = require("tests.support.frame_stepper")
local Bodies = require("src.sim.bodies")
local Poly = require("src.core.poly")

local function squareAsteroidVertices()
	return Poly.normalize({
		{ x = -30, y = -30 },
		{ x = 30, y = -30 },
		{ x = 30, y = 30 },
		{ x = -30, y = 30 },
	})
end

local function injectAsteroid(ctx, fields)
	local body = {
		x = fields.x,
		y = fields.y,
		vx = fields.vx or 0,
		vy = fields.vy or 0,
		angle = fields.angle or 0,
		angularVelocity = fields.angularVelocity or 0,
		mass = fields.mass or 100,
		kind = "asteroid",
		radius = fields.radius or 42,
		vertices = fields.vertices or squareAsteroidVertices(),
		refuelMultiplier = ctx.config.asteroid.refuelMultiplier,
		riders = {},
	}
	local bodyId = Bodies.add(ctx.sim.bodies, body)
	local asteroid = { id = bodyId, body = bodyId, dead = false, kind = "asteroid" }
	table.insert(ctx.pools.asteroids, asteroid)
	return asteroid, body
end

local function bareLevel()
	return {
		worlds = {},
		spawnPoints = { { x = -1000000, y = 100 }, { x = -1000000, y = 200 } },
		asteroids = { maxAlive = 0 },
	}
end

test("two asteroids colliding bounce apart and both survive", function()
	local game = GameHarness.startMatch(bareLevel())
	local ctx = game.ctx

	local _, bodyA = injectAsteroid(ctx, { x = 600, y = 400, vx = 60, vy = 0, mass = 100 })
	local _, bodyB = injectAsteroid(ctx, { x = 680, y = 400, vx = -60, vy = 0, mass = 100 })

	FrameStepper.step(game, 10)

	assertEqual(2, #ctx.pools.asteroids, "expected both asteroids to survive the bounce")
	assertTrue(bodyA.vx < 0, "expected asteroid A to have bounced back (negative vx)")
	assertTrue(bodyB.vx > 0, "expected asteroid B to have bounced back (positive vx)")
end)

test("a projectile hitting an asteroid dies and leaves the asteroid's velocity and spin unchanged", function()
	local game = GameHarness.startMatch(bareLevel())
	local ctx = game.ctx

	local asteroidVx, asteroidVy, asteroidSpin = 12, -7, 0.2
	local _, asteroidBody = injectAsteroid(ctx, {
		x = 640,
		y = 360,
		vx = asteroidVx,
		vy = asteroidVy,
		angularVelocity = asteroidSpin,
		mass = 800,
	})

	-- A fast, already-armed projectile spawned right at the asteroid's
	-- centre so it's guaranteed to be inside it the very first frame,
	-- regardless of armDelay timing.
	local Bodies2 = Bodies
	local projectileBody = {
		x = 640,
		y = 360,
		vx = 500,
		vy = 0,
		angle = 0,
		mass = 0.001,
		kind = "projectile",
		radius = 3,
		armed = true,
	}
	local projectileBodyId = Bodies2.add(ctx.sim.bodies, projectileBody)
	local projectile = {
		id = projectileBodyId,
		body = projectileBodyId,
		shooter = 1,
		dead = false,
		age = 1,
		lifetime = { remaining = 3 },
	}
	table.insert(ctx.pools.projectiles, projectile)

	FrameStepper.step(game, 1)

	assertEqual(0, #ctx.pools.projectiles, "expected the projectile to die on contact with the asteroid")
	assertNear(asteroidVx, asteroidBody.vx, 0.0001, "expected the asteroid's vx to be unchanged")
	assertNear(asteroidVy, asteroidBody.vy, 0.0001, "expected the asteroid's vy to be unchanged")
	assertNear(asteroidSpin, asteroidBody.angularVelocity, 0.0001, "expected the asteroid's spin to be unchanged")
end)
