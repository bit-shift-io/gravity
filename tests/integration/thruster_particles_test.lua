-- Holding thrust spawns exhaust particles from the ship's rear edge, one per
-- step, through the real Match.step frame order.
local GameHarness = require("tests.support.game_harness")
local FrameStepper = require("tests.support.frame_stepper")
local Bodies = require("src.sim.bodies")
local Poly = require("src.core.poly")

-- No worlds and ship 2 far away: nothing but thrust moves ship 1.
local function startOpenSpace()
	local level = { worlds = {}, spawnPoints = { { x = 640, y = 360 }, { x = 640, y = -1000000 } } }
	return GameHarness.startMatch(level)
end

test("holding thrust for N steps spawns N particles", function()
	local game = startOpenSpace()
	game.ctx.intents[1] = { rotate = 0, thrust = true, fire = false }

	FrameStepper.step(game, 10)

	assertEqual(10, #game.ctx.pools.particles)
end)

test("a spawned particle starts at the rear of the ship, not its centre, and trails it", function()
	local game = startOpenSpace()
	local ship = game.ctx.pools.ships[1]
	local shipBody = Bodies.get(game.ctx.sim.bodies, ship.body)
	game.ctx.intents[1] = { rotate = 0, thrust = true, fire = false }

	FrameStepper.step(game, 1)

	local particle = game.ctx.pools.particles[1]
	local body = Bodies.get(game.ctx.sim.bodies, particle.body)
	assertTrue(body.y > shipBody.y, "expected particle behind (below) a nose-up ship")
	assertTrue(body.vy > shipBody.vy, "expected particle to move rearward relative to the ship")
end)

test("no particles spawn without thrust intent", function()
	local game = startOpenSpace()
	game.ctx.intents[1] = { rotate = 0, thrust = false, fire = false }

	FrameStepper.step(game, 10)

	assertEqual(0, #game.ctx.pools.particles)
end)

test("no particles spawn once the tank is empty", function()
	local game = startOpenSpace()
	local ship = game.ctx.pools.ships[1]
	ship.fuel.amount = 0
	game.ctx.intents[1] = { rotate = 0, thrust = true, fire = false }

	FrameStepper.step(game, 10)

	assertEqual(0, #game.ctx.pools.particles)
end)

test("particles are flagged passive at spawn", function()
	local game = startOpenSpace()
	game.ctx.intents[1] = { rotate = 0, thrust = true, fire = false }

	FrameStepper.step(game, 1)

	local particle = game.ctx.pools.particles[1]
	assertTrue(Bodies.get(game.ctx.sim.bodies, particle.body).passive)
end)

test("a particle near a world accelerates toward it", function()
	local level = {
		worlds = {
			{
				vertices = {
					{ x = -1000, y = 310 },
					{ x = 2000, y = 310 },
					{ x = 2000, y = 1000 },
					{ x = -1000, y = 1000 },
				},
				mass = 1,
			},
		},
		spawnPoints = { { x = 640, y = -1000 }, { x = -1000000, y = -1000 } },
	}
	local game = GameHarness.startMatch(level)
	local ParticleSystem = require("src.game.systems.particle_system")
	local particle = ParticleSystem.spawn(game.ctx, { x = 640, y = 200 }, { x = 0, y = 0 })
	local body = Bodies.get(game.ctx.sim.bodies, particle.body)

	FrameStepper.step(game, 5)

	assertTrue(body.vy > 0, "expected particle to fall toward the world below it")
end)

test("a ship's velocity is identical with and without live particles nearby", function()
	local function run(withParticles)
		local level = { worlds = {}, spawnPoints = { { x = 640, y = 360 }, { x = 640, y = -1000000 } } }
		local game = GameHarness.startMatch(level)
		local ParticleSystem = require("src.game.systems.particle_system")
		if withParticles then
			for i = 1, 20 do
				ParticleSystem.spawn(game.ctx, { x = 640 + i, y = 380 }, { x = 0, y = 0 })
			end
		end
		FrameStepper.step(game, 10)
		local ship = game.ctx.pools.ships[1]
		local body = Bodies.get(game.ctx.sim.bodies, ship.body)
		return body.vx, body.vy
	end

	local vx0, vy0 = run(false)
	local vx1, vy1 = run(true)

	assertNear(vx0, vx1, 1e-12)
	assertNear(vy0, vy1, 1e-12)
end)

test("after hold + fade time (2.5s) particles are removed from pool and body store", function()
	local level = { worlds = {}, spawnPoints = { { x = 640, y = 360 }, { x = 640, y = -1000000 } } }
	local game = GameHarness.startMatch(level)
	local ParticleSystem = require("src.game.systems.particle_system")
	game.ctx.intents[1] = { rotate = 0, thrust = true, fire = false }

	-- Spawn particles for 1 second (60 steps at 60 Hz)
	FrameStepper.step(game, 60)

	-- Should have 60 particles now
	assertEqual(60, #game.ctx.pools.particles)

	-- Stop thrusting to prevent new particles from spawning
	game.ctx.intents[1] = { rotate = 0, thrust = false, fire = false }

	-- Step for another 2.5 seconds (150 steps) to let all particles age out and despawn
	FrameStepper.step(game, 150)

	-- All particles should be gone
	assertEqual(0, #game.ctx.pools.particles)
end)

-- A world whose top edge is y=310 (same as the gravity test), well clear of
-- the ship spawn so only the particle under test touches it.
local function worldBelow()
	return {
		vertices = {
			{ x = -1000, y = 310 },
			{ x = 2000, y = 310 },
			{ x = 2000, y = 1000 },
			{ x = -1000, y = 1000 },
		},
		mass = 1,
	}
end

local function liveParticle(game, particle)
	return not particle.dead and Bodies.get(game.ctx.sim.bodies, particle.body) ~= nil
end

test("a particle fired into a world dies on that step and leaves the pool", function()
	local game = GameHarness.startMatch({
		worlds = { worldBelow() },
		spawnPoints = { { x = 640, y = -1000 }, { x = -1000000, y = -1000 } },
	})
	local ParticleSystem = require("src.game.systems.particle_system")
	local particle = ParticleSystem.spawn(game.ctx, { x = 640, y = 290 }, { x = 0, y = 600 })

	FrameStepper.step(game, 1)
	assertTrue(liveParticle(game, particle), "expected particle still above the edge after 1 step")

	FrameStepper.step(game, 1)
	assertTrue(not liveParticle(game, particle), "expected particle dead after crossing the edge")
	assertEqual(0, #game.ctx.pools.particles)
end)

local function squareAsteroid(game, x, y)
	local ctx = game.ctx
	local body = {
		x = x, y = y, vx = 0, vy = 0, angle = 0, angularVelocity = 0,
		mass = 100, kind = "asteroid", radius = 42,
		vertices = Poly.normalize({
			{ x = -30, y = -30 }, { x = 30, y = -30 }, { x = 30, y = 30 }, { x = -30, y = 30 },
		}),
	}
	local bodyId = Bodies.add(ctx.sim.bodies, body)
	table.insert(ctx.pools.asteroids, { id = bodyId, body = bodyId, dead = false, kind = "asteroid" })
	return body
end

test("a particle inside an asteroid dies, and the asteroid is untouched", function()
	local game = GameHarness.startMatch({
		worlds = {},
		spawnPoints = { { x = 640, y = 360 }, { x = 640, y = -1000000 } },
		asteroids = { maxAlive = 0 },
	})
	local ParticleSystem = require("src.game.systems.particle_system")
	local asteroidBody = squareAsteroid(game, 300, 300)
	local particle = ParticleSystem.spawn(game.ctx, { x = 300, y = 300 }, { x = 0, y = 0 })

	FrameStepper.step(game, 1)

	assertTrue(not liveParticle(game, particle), "expected particle dead inside the asteroid")
	assertTrue(not game.ctx.pools.asteroids[1].dead, "expected the asteroid to survive")
	assertEqual(asteroidBody, Bodies.get(game.ctx.sim.bodies, game.ctx.pools.asteroids[1].body))
end)

test("a particle past the hard boundary dies", function()
	local game = GameHarness.startMatch({
		worlds = {},
		spawnPoints = { { x = 640, y = 360 }, { x = 640, y = -1000000 } },
	})
	local ParticleSystem = require("src.game.systems.particle_system")
	local particle = ParticleSystem.spawn(game.ctx, { x = 1279, y = 0 }, { x = 600, y = 0 })

	FrameStepper.step(game, 1)
	assertTrue(not liveParticle(game, particle), "expected particle dead outside the boundary")
end)

test("a particle overlapping either ship survives", function()
	local game = GameHarness.startMatch({
		worlds = {},
		spawnPoints = { { x = 640, y = 360 }, { x = 800, y = 360 } },
	})
	local ParticleSystem = require("src.game.systems.particle_system")
	local particles = {}
	for _, ship in ipairs(game.ctx.pools.ships) do
		local body = Bodies.get(game.ctx.sim.bodies, ship.body)
		table.insert(particles, ParticleSystem.spawn(game.ctx, { x = body.x, y = body.y }, { x = 0, y = 0 }))
	end

	FrameStepper.step(game, 3)

	for _, particle in ipairs(particles) do
		assertTrue(liveParticle(game, particle), "expected particle overlapping a ship to survive")
	end
end)

test("a particle overlapping a projectile survives", function()
	local game = GameHarness.startMatch({
		worlds = {},
		spawnPoints = { { x = 640, y = 360 }, { x = 640, y = -1000000 } },
	})
	local ParticleSystem = require("src.game.systems.particle_system")
	local ProjectileSystem = require("src.game.systems.projectile_system")
	local ship = game.ctx.pools.ships[1]
	local shipBody = Bodies.get(game.ctx.sim.bodies, ship.body)
	local origin = { x = shipBody.x + 200, y = shipBody.y }
	local projectile = ProjectileSystem.spawn(game.ctx, ship, origin, { x = 0, y = -1 }, 0)
	local particle = ParticleSystem.spawn(game.ctx, origin, { x = 0, y = 0 })

	FrameStepper.step(game, 1)

	assertTrue(liveParticle(game, particle), "expected particle overlapping a projectile to survive")
	assertTrue(not projectile.dead, "expected the unarmed projectile to survive too")
end)

test("a particle born at the hull of a ship near a world dies on first contact, not before", function()
	local world = worldBelow()
	world.vertices[1].y, world.vertices[2].y = 330, 330
	local game = GameHarness.startMatch({
		worlds = { world },
		spawnPoints = { { x = 640, y = 300 }, { x = -1000000, y = -1000 } },
	})
	game.ctx.intents[1] = { rotate = 0, thrust = true, fire = false }

	FrameStepper.step(game, 1)
	local particle = game.ctx.pools.particles[1]
	local body = Bodies.get(game.ctx.sim.bodies, particle.body)
	assertTrue(body ~= nil and not particle.dead, "expected the particle alive on its birth step")
	assertTrue(body.y < 330, "expected the hull-born particle to start above the world's edge")

	game.ctx.intents[1] = { rotate = 0, thrust = false, fire = false }
	local steps = 0
	while liveParticle(game, particle) and steps < 120 do
		FrameStepper.step(game, 1)
		steps = steps + 1
	end
	assertTrue(steps > 0 and steps < 120, "expected the particle to die on contact with the world")
end)

local function startTank()
	local game = startOpenSpace()
	local ship = game.ctx.pools.ships[1]
	local body = Bodies.get(game.ctx.sim.bodies, ship.body)
	body.pinned = true
	ship.lander.state = "tank"
	ship.lander.host = { vertices = {} }
	return game
end

test("lifting off from tank mode emits on the lift-off step and every step after, once per step", function()
	local game = startTank()
	game.ctx.intents[1] = { rotate = 0, thrust = true, fire = false }

	FrameStepper.step(game, 1)
	assertEqual(1, #game.ctx.pools.particles, "expected one particle on the lift-off step")

	FrameStepper.step(game, 4)
	assertEqual(5, #game.ctx.pools.particles)
end)

test("a landed ship that is not thrusting emits nothing", function()
	local game = startTank()
	game.ctx.intents[1] = { rotate = 0, thrust = false, fire = false }

	FrameStepper.step(game, 5)

	assertEqual(0, #game.ctx.pools.particles)
end)
