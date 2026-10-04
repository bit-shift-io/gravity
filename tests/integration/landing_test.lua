-- Exercises landing/crashing/refuelling/lift-off through the real frame
-- order (Sim.step's contact list -> ShipSystem.handleContacts -> the
-- despawn sweep), the same way tests/integration/ship_flight_test.lua
-- exercises flight. Uses a single flat world with an explicit tiny mass so
-- gravity is negligible and the test can control descent speed directly by
-- setting body.vy, rather than fighting the baked field for a precise
-- approach speed.
local GameHarness = require("tests.support.game_harness")
local FrameStepper = require("tests.support.frame_stepper")
local Bodies = require("src.sim.bodies")
local Config = require("src.game.config")

-- These tests park the second ship out of bounds, so it dies at once; keep
-- the round-end respawn from resetting the ship under test mid-scenario.
local noRespawnConfig = setmetatable({ round = { endDelay = math.huge, winsToWin = 3 } }, { __index = Config })

-- A wide flat platform with its top surface at y=310 (outward normal
-- (0,-1), matching a ship's angle-0 nose exactly) -- wide enough that a
-- ship spawned anywhere near x=640-700 always lands well inside it, never
-- off an edge.
local function flatWorldLevel(spawnPoints)
	return {
		worlds = {
			{
				vertices = {
					{ x = -100, y = 310 },
					{ x = 1400, y = 310 },
					{ x = 1400, y = 400 },
					{ x = -100, y = 400 },
				},
				mass = 1,
			},
		},
		spawnPoints = spawnPoints,
	}
end

test("a ship dropped slowly nose-up onto a world lands, refuels to full, then lifts off on thrust", function()
	-- Ship 2 is spawned far away so its pairwise pull on ship 1 (slice 06)
	-- doesn't perturb the controlled vertical descent this test relies on.
	local level = flatWorldLevel({ { x = 640, y = 250 }, { x = -1000000, y = 250 } })
	local game = GameHarness.startMatch(level, { config = noRespawnConfig })
	local ctx = game.ctx
	local ship = ctx.pools.ships[1]
	local body = Bodies.get(ctx.sim.bodies, ship.body)

	assertEqual("flying", ship.lander.state)

	-- Slow, nose-up descent straight toward the world's top surface -- well
	-- under config.landing.maxSpeed (400), so this
	-- should land rather than crash.
	body.vx = 0
	body.vy = 30
	ship.fuel.amount = 0

	FrameStepper.step(game, 300) -- 5s: comfortably more than the ~2.3s fall

	assertEqual("tank", ship.lander.state, "expected the slow, aligned contact to land")
	assertNear(0, body.vx, 0.0001)
	assertNear(0, body.vy, 0.0001)
	assertTrue(body.pinned, "expected a landed ship's body to be pinned")

	-- Refuels to full over the configured time (config.landing.refuelRate).
	local capacity = ship.fuel.capacity
	local secondsToFull = capacity / ctx.config.landing.refuelRate
	FrameStepper.step(game, FrameStepper.secondsToFrames(secondsToFull) + 10)
	assertNear(capacity, ship.fuel.amount, 0.01)

	-- Tank: cannot rotate body, but can aim turret.
	ctx.intents[1] = { rotate = 1, thrust = false, fire = false }
	FrameStepper.step(game, 10)
	assertNear(0, body.angularVelocity, 0.0001, "expected a tank ship to ignore body rotate intent")
	assertEqual("tank", ship.lander.state)

	-- Thrust lifts off with normal thrust.
	ctx.intents[1] = { rotate = 0, thrust = true, fire = false }
	FrameStepper.step(game, 1)

	assertEqual("flying", ship.lander.state)
	assertFalse(body.pinned, "expected lift-off to un-pin the body")
	assertTrue(body.vy < 0, "expected upward thrust to lift the ship off the surface")
end)

test("a ship dropped fast crashes and its record is swept", function()
	local level = flatWorldLevel({ { x = 640, y = 250 } })
	local game = GameHarness.startMatch(level, { config = noRespawnConfig })
	local ctx = game.ctx
	local ship = ctx.pools.ships[1]
	local bodyId = ship.body
	local body = Bodies.get(ctx.sim.bodies, bodyId)

	-- Far above config.landing.maxSpeed (400) -- guaranteed crash.
	body.vx = 0
	body.vy = 400

	FrameStepper.step(game, 60)

	assertEqual(0, #ctx.pools.ships, "expected the crashed ship's record to be swept")
	assertTrue(Bodies.get(ctx.sim.bodies, bodyId) == nil, "expected the crashed ship's body to be swept too")
end)

test("a ship dropped sideways onto a world at moderate speed lands upright without embedding", function()
	local level = flatWorldLevel({ { x = 640, y = 250 }, { x = -1000000, y = 250 } })
	local game = GameHarness.startMatch(level, { config = noRespawnConfig })
	local ctx = game.ctx
	local ship = ctx.pools.ships[1]
	local body = Bodies.get(ctx.sim.bodies, ship.body)

	-- Nose pointing along +x (90 degrees off the surface normal), falling at
	-- a speed under config.landing.maxSpeed.
	body.angle = math.pi / 2
	body.vx = 0
	body.vy = 100

	FrameStepper.step(game, 300)

	assertEqual("tank", ship.lander.state, "expected a sideways touch under max speed to land")
	assertNear(0, body.angle, 0.0001, "expected the ship to snap upright (nose along the surface normal)")

	local Collide = require("src.sim.collide")
	local points = Collide.transform(Collide.SHIP_SHAPE, body.x, body.y, body.angle)
	local lowest = -math.huge
	for _, p in ipairs(points) do
		lowest = math.max(lowest, p.y)
	end
	assertTrue(lowest <= 310 + 0.01, "expected no hull vertex embedded below the surface at y=310")
end)
