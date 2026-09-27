-- Exercises boundary detection through the real frame order (BoundarySystem.update
-- -> the despawn sweep), ensuring a ship drifting off-screen with no fuel is
-- destroyed once past the margin.
local GameHarness = require("tests.support.game_harness")
local FrameStepper = require("tests.support.frame_stepper")
local Bodies = require("src.sim.bodies")

-- A single flat world at y=600, well below spawn point, so a ship can freely
-- drift horizontally past the screen edge without interfering with gravity.
local function flatWorldLevel(spawnPoints)
	return {
		worlds = {
			{
				vertices = {
					{ x = -2000, y = 600 },
					{ x = 2000, y = 600 },
					{ x = 2000, y = 1000 },
					{ x = -2000, y = 1000 },
				},
				mass = 1,
			},
		},
		spawnPoints = spawnPoints,
	}
end

test("a ship drifting off-screen horizontally with no thrust is lost to space past the margin", function()
	-- Ship 2 far away so its pairwise pull doesn't affect ship 1.
	local level = flatWorldLevel({ { x = 640, y = 300 }, { x = -1000000, y = 300 } })
	local game = GameHarness.startMatch(level)
	local ctx = game.ctx
	local ship = ctx.pools.ships[1]
	local bodyId = ship.body
	local body = Bodies.get(ctx.sim.bodies, bodyId)

	-- No fuel, no thrust -- gravity pulls downward, but the ship starts well
	-- above the world so it has plenty of time to drift horizontally to the
	-- screen edge and beyond.
	ship.fuel.amount = 0

	-- Give the ship a horizontal velocity toward the right edge.
	-- Screen width is 1280, margin is 128, so the right boundary is at 1280+128 = 1408.
	-- A ship at x=640 with vx=100 will reach 1408 in about 7.68 seconds.
	body.vx = 100
	body.vy = 0

	-- Step until the ship reaches the margin. At vx=100, it takes about 7.68s = 460 frames.
	-- We'll step a bit extra to ensure it goes past the margin.
	FrameStepper.step(game, 500)

	-- After drifting past the margin, the ship should be swept from the pool.
	assertEqual(0, #ctx.pools.ships, "expected the ship drifted past the margin to be swept")
	assertTrue(Bodies.get(ctx.sim.bodies, bodyId) == nil, "expected the ship's body to be swept too")
end)

test("a ship at the margin boundary still exists", function()
	local level = flatWorldLevel({ { x = 640, y = 300 }, { x = -1000000, y = 300 } })
	local game = GameHarness.startMatch(level)
	local ctx = game.ctx
	local ship = ctx.pools.ships[1]
	local body = Bodies.get(ctx.sim.bodies, ship.body)

	-- Position the ship exactly at the margin boundary (x = 1280 + 128).
	body.x = 1280 + 128
	body.y = 300
	body.vx = 0
	body.vy = 0
	ship.fuel.amount = 0

	FrameStepper.step(game, 10)

	assertEqual(1, #ctx.pools.ships, "expected the ship at the margin to still exist")
end)
