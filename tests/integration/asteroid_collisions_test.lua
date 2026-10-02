-- Exercises asteroid-vs-asteroid splitting and projectile-vs-asteroid contacts
-- through the real frame order (Sim.collide's "asteroidAsteroid"/
-- "projectileAsteroid" contacts -> AsteroidSystem.handleContacts), the same
-- way tests/integration/ship_bounce_test.lua exercises ship-vs-ship bounce.
local GameHarness = require("tests.support.game_harness")
local FrameStepper = require("tests.support.frame_stepper")
local Bodies = require("src.sim.bodies")
local Poly = require("src.core.poly")
local Config = require("src.game.config")

local function squareAsteroidVertices()
	return Poly.normalize({
		{ x = -30, y = -30 },
		{ x = 30, y = -30 },
		{ x = 30, y = 30 },
		{ x = -30, y = 30 },
	})
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

local function liveAsteroids(ctx)
	local live = {}
	for _, asteroid in ipairs(ctx.pools.asteroids) do
		if not asteroid.dead then
			table.insert(live, asteroid)
		end
	end
	return live
end

-- Squares overlapping by 4px between bounding circles (radius 42 each,
-- centres 80 apart), closing head-on. half = 30 (area 3600) is above
-- splitAreaThreshold; half = 20 (area 1600) is below it.
local function collidingPair(game, halfA, halfB)
	local ctx = game.ctx
	local a = injectAsteroid(ctx, {
		x = 600, y = 400, vx = 60,
		vertices = squareVertices(halfA), radius = 42,
	})
	local b = injectAsteroid(ctx, {
		x = 680, y = 400, vx = -60,
		vertices = squareVertices(halfB), radius = 42,
	})
	return a, b
end

test("two large asteroids colliding each split into 3 fragments", function()
	local game = GameHarness.startMatch(bareLevel())
	local a, b = collidingPair(game, 30, 30)

	FrameStepper.step(game, 1)

	assertTrue(a.dead and b.dead, "expected both parents to be dead")
	assertEqual(6, #liveAsteroids(game.ctx), "expected 6 live fragments")
end)

test("a large asteroid colliding with a small one splits while the small is destroyed", function()
	local game = GameHarness.startMatch(bareLevel())
	local large, small = collidingPair(game, 30, 20)

	FrameStepper.step(game, 1)

	assertTrue(large.dead and small.dead, "expected both originals gone")
	assertEqual(3, #liveAsteroids(game.ctx), "expected only the large one's 3 fragments")
end)

test("two small asteroids colliding are both destroyed", function()
	local game = GameHarness.startMatch(bareLevel())
	collidingPair(game, 20, 20)

	FrameStepper.step(game, 1)

	assertEqual(0, #liveAsteroids(game.ctx), "expected no live asteroids")
end)

test("asteroid collision applies no bounce impulse to the fragments' velocity", function()
	local game = GameHarness.startMatch(bareLevel())
	collidingPair(game, 30, 30)

	FrameStepper.step(game, 1)

	-- Each fragment keeps its parent's velocity (+/-60 along x) plus only
	-- the split nudge, so none reverses direction as a bounce would.
	local nudge = Config.asteroid.splitNudgeSpeed
	for _, asteroid in ipairs(liveAsteroids(game.ctx)) do
		local body = Bodies.get(game.ctx.sim.bodies, asteroid.body)
		assertTrue(math.abs(math.abs(body.vx) - 60) <= nudge + 1e-6, "expected |vx| within nudge of 60, got " .. body.vx)
	end
end)

test("sibling fragments of one split do not collide with each other on later steps", function()
	local game = GameHarness.startMatch(bareLevel())
	-- The small partner is destroyed, leaving only the large one's overlapping
	-- siblings, which must not split or destroy one another.
	collidingPair(game, 30, 20)

	FrameStepper.step(game, 5)

	assertEqual(3, #liveAsteroids(game.ctx), "expected all 3 siblings to survive")
end)

test("siblings collide normally once they have separated", function()
	local game = GameHarness.startMatch(bareLevel())
	collidingPair(game, 30, 20)
	FrameStepper.step(game, 1)

	local live = liveAsteroids(game.ctx)
	assertEqual(3, #live, "expected the 3 siblings to survive the split")
	local bodies = {}
	for i, asteroid in ipairs(live) do
		bodies[i] = Bodies.get(game.ctx.sim.bodies, asteroid.body)
		bodies[i].x, bodies[i].y = 400 * i, 400
		bodies[i].vx, bodies[i].vy = 0, 0
	end
	FrameStepper.step(game, 1)
	assertEqual(3, #liveAsteroids(game.ctx), "expected separated siblings to be left alone")

	bodies[2].x, bodies[2].y = bodies[1].x, bodies[1].y
	FrameStepper.step(game, 1)

	assertTrue(#liveAsteroids(game.ctx) < 3, "expected separated siblings to collide")
end)

test("fragments are pushed away from the other asteroid along the contact normal", function()
	local game = GameHarness.startMatch(bareLevel())
	local a, b = collidingPair(game, 30, 30)
	local aBody = Bodies.get(game.ctx.sim.bodies, a.body)
	local bBody = Bodies.get(game.ctx.sim.bodies, b.body)

	FrameStepper.step(game, 1)

	-- The parents' final positions are where the contact found them.
	local ax, bx = aBody.x, bBody.x

	-- Fragment masses sum to the parent's and offsets are about its centre,
	-- so the mass-weighted mean x reveals the push-out direction.
	local sumA, massA, sumB, massB = 0, 0, 0, 0
	for _, asteroid in ipairs(liveAsteroids(game.ctx)) do
		local body = Bodies.get(game.ctx.sim.bodies, asteroid.body)
		if asteroid.fragmentOf == a.body then
			sumA, massA = sumA + body.x * body.mass, massA + body.mass
		else
			sumB, massB = sumB + body.x * body.mass, massB + body.mass
		end
	end
	assertTrue(massA > 0 and massB > 0, "expected fragments from both parents")
	assertTrue(sumA / massA < ax, "expected A's fragments pushed toward -x, away from B")
	assertTrue(sumB / massB > bx, "expected B's fragments pushed toward +x, away from A")
end)

test("a projectile hitting an asteroid dies and the asteroid may be pushed by the blast", function()
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
		vertices = squareVertices(20), -- small: only pushed, never split
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
	-- Asteroid survives the blast (not destroyed, only pushed)
	assertEqual(1, #ctx.pools.asteroids, "expected the asteroid to survive the blast")
	-- Asteroid's spin is unaffected by the linear push (rotation not affected)
	assertNear(asteroidSpin, asteroidBody.angularVelocity, 0.0001, "expected the asteroid's spin to be unchanged (rotation unaffected)")
end)

test("a projectile's blast pushes a nearby asteroid outward", function()
	local game = GameHarness.startMatch(bareLevel())
	local ctx = game.ctx

	-- Asteroid overlapping with the blast point, slightly offset so push direction is clear
	local _, asteroidBody = injectAsteroid(ctx, {
		x = 630,
		y = 345,
		vx = 0,
		vy = 0,
		mass = 100,
		vertices = squareVertices(20), -- small: only pushed, never split
	})

	-- Projectile moving fast into the asteroid
	-- Position nearby to guarantee collision on contact detection
	local projectileBody = {
		x = 620,
		y = 360,
		vx = 500,
		vy = 0,
		angle = 0,
		mass = 0.001,
		kind = "projectile",
		radius = 3,
		armed = true,
	}
	local projectileBodyId = Bodies.add(ctx.sim.bodies, projectileBody)
	local projectile = {
		id = projectileBodyId,
		body = projectileBodyId,
		shooter = 1,
		dead = false,
		age = 1,
	}
	table.insert(ctx.pools.projectiles, projectile)

	-- Step one frame: projectile moves and collides, detonates, pushes asteroid
	FrameStepper.step(game, 1)

	-- The asteroid should still be alive
	assertEqual(1, #ctx.pools.asteroids, "expected asteroid to survive the blast")
	-- The projectile should be dead
	assertEqual(0, #ctx.pools.projectiles, "expected projectile to be dead after detonation")
	-- The asteroid should have been pushed upward (negative y) away from blast
	assertTrue(asteroidBody.vy < 0, "expected asteroid to be pushed upward (away from blast at y=360)")
end)
