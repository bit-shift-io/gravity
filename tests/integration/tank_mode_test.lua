-- Integration tests for tank mode: landing, turret aiming, refueling, lift-off
local GameHarness = require("tests.support.game_harness")
local FrameStepper = require("tests.support.frame_stepper")
local Bodies = require("src.sim.bodies")
local Config = require("src.game.config")

-- These tests park the second ship out of bounds, so it dies at once; keep
-- the round-end respawn from resetting the ship under test mid-scenario.
local noRespawnConfig = setmetatable({ round = { endDelay = math.huge, winsToWin = 3 } }, { __index = Config })

-- A wide flat platform with its top surface at y=310 (outward normal
-- (0,-1), matching a ship's angle-0 nose exactly).
local function flatWorldLevel(spawnPoints)
	return {
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
		spawnPoints = spawnPoints,
	}
end

test("a tank ship's turret starts straight up and stays within the limit when spinning", function()
	local level = flatWorldLevel({ { x = 640, y = 250 }, { x = -1000000, y = 250 } })
	local game = GameHarness.startMatch(level, { config = noRespawnConfig })
	local ctx = game.ctx
	local ship = ctx.pools.ships[1]
	local body = Bodies.get(ctx.sim.bodies, ship.body)

	-- Land the ship
	body.vx = 0
	body.vy = 30
	ship.fuel.amount = 0
	FrameStepper.step(game, 300)

	assertEqual("tank", ship.lander.state)
	assertNear(0, ship.turret.angle, 0.0001, "expected turret to start at 0 (straight up)")

	-- Spin right continuously for 2 seconds at turretSpeed = 1 rad/sec
	ctx.intents[1] = { rotate = 1, thrust = false, fire = false }
	local framesFor2Seconds = FrameStepper.secondsToFrames(2)
	FrameStepper.step(game, framesFor2Seconds)

	-- Turret should be clamped to the limit (80 degrees = ~1.396 radians)
	assertNear(
		ctx.config.tank.turretLimit,
		ship.turret.angle,
		0.01,
		"expected turret to be at +limit after holding right"
	)

	-- Body angle should be unchanged (still pointing up)
	assertNear(0, body.angle, 0.0001, "expected body angle unchanged while in tank mode")
end)

test("tank turret can spin left to -limit", function()
	local level = flatWorldLevel({ { x = 640, y = 250 }, { x = -1000000, y = 250 } })
	local game = GameHarness.startMatch(level, { config = noRespawnConfig })
	local ctx = game.ctx
	local ship = ctx.pools.ships[1]
	local body = Bodies.get(ctx.sim.bodies, ship.body)

	-- Land the ship
	body.vx = 0
	body.vy = 30
	ship.fuel.amount = 0
	FrameStepper.step(game, 300)

	assertEqual("tank", ship.lander.state)

	-- Spin left continuously for 2 seconds
	ctx.intents[1] = { rotate = -1, thrust = false, fire = false }
	local framesFor2Seconds = FrameStepper.secondsToFrames(2)
	FrameStepper.step(game, framesFor2Seconds)

	-- Turret should be clamped to -limit
	assertNear(
		-ctx.config.tank.turretLimit,
		ship.turret.angle,
		0.01,
		"expected turret to be at -limit after holding left"
	)

	-- Body angle should be unchanged
	assertNear(0, body.angle, 0.0001, "expected body angle unchanged")
end)

test("tank lift-off applies thrust along the surface normal, ignoring turret angle", function()
	local level = flatWorldLevel({ { x = 640, y = 250 }, { x = -1000000, y = 250 } })
	local game = GameHarness.startMatch(level, { config = noRespawnConfig })
	local ctx = game.ctx
	local ship = ctx.pools.ships[1]
	local body = Bodies.get(ctx.sim.bodies, ship.body)

	-- Land and refuel
	body.vx = 0
	body.vy = 30
	ship.fuel.amount = ctx.config.ship.fuel.capacity
	FrameStepper.step(game, 300)

	assertEqual("tank", ship.lander.state)

	-- Spin the turret to the right limit
	ctx.intents[1] = { rotate = 1, thrust = false, fire = false }
	FrameStepper.step(game, FrameStepper.secondsToFrames(2))

	-- Verify turret is at +limit
	assertNear(ctx.config.tank.turretLimit, ship.turret.angle, 0.01)

	-- Thrust while turret is at +limit
	ctx.intents[1] = { rotate = 0, thrust = true, fire = false }
	FrameStepper.step(game, 1)

	-- Ship should lift off
	assertEqual("flying", ship.lander.state, "expected lift-off to return to flying state")
	assertFalse(body.pinned, "expected body to be unpinned")

	-- Velocity should be upward (along the surface normal), not rotated by turret
	-- Surface normal is (0, -1), so upward thrust should give vy < 0
	assertTrue(body.vy < 0, "expected upward velocity after lift-off")

	-- The velocity should not be rotated by the turret angle
	-- Thrust is straight up the normal, so vx should be ~0
	assertNear(0, body.vx, 0.5, "expected velocity mostly upward, not rotated by turret")
end)

test("tank ship refuels while stationary on surface", function()
	local level = flatWorldLevel({ { x = 640, y = 250 }, { x = -1000000, y = 250 } })
	local game = GameHarness.startMatch(level, { config = noRespawnConfig })
	local ctx = game.ctx
	local ship = ctx.pools.ships[1]
	local body = Bodies.get(ctx.sim.bodies, ship.body)

	-- Land the ship
	body.vx = 0
	body.vy = 30
	FrameStepper.step(game, 300)

	assertEqual("tank", ship.lander.state)

	-- Set fuel to half capacity
	local capacity = ship.fuel.capacity
	ship.fuel.amount = capacity / 2

	-- Idle (no thrust, no rotate)
	ctx.intents[1] = { rotate = 0, thrust = false, fire = false }

	-- Refuel for the time to reach full capacity from half
	local fuelNeeded = capacity / 2
	local secondsToFull = fuelNeeded / ctx.config.landing.refuelRate
	FrameStepper.step(game, FrameStepper.secondsToFrames(secondsToFull) + 10)

	assertNear(capacity, ship.fuel.amount, 0.1, "expected tank to refuel to full")
end)
