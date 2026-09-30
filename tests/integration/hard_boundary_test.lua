-- Exercises hard boundary collision detection through the real frame order,
-- ensuring ships are destroyed when hitting the hard boundary.
local GameHarness = require("tests.support.game_harness")
local FrameStepper = require("tests.support.frame_stepper")
local Bodies = require("src.sim.bodies")
local FixtureLevel = require("src.game.levels.fixture_two_worlds")

test("a ship crossing the hard boundary dies instantly", function()
	-- Use the real fixture level so we have proper worlds and gravity behavior
	local level = FixtureLevel.new()
	local game = GameHarness.startMatch(level)
	local ctx = game.ctx
	local ship = ctx.pools.ships[1]
	local body = Bodies.get(ctx.sim.bodies, ship.body)

	-- Hard boundary radius is 1280; position at 1270 with velocity pushing outward
	-- This puts the ship right at the threshold of the hard boundary
	body.x = 1270
	body.y = 0
	body.vx = 100  -- Moving outward toward the boundary
	body.vy = 0
	ship.fuel.amount = 0

	-- Step enough frames for the ship to cross the boundary
	-- At vx=100, it takes about 0.1 seconds = 6 frames to go from 1270 to 1270+100=1370
	FrameStepper.step(game, 10)

	-- After crossing the boundary, the ship should be dead
	assertTrue(ship.dead, "expected the ship to be dead after crossing hard boundary")
end)

test("the camera keeps framing a ship that died at the hard boundary until its death animation ends", function()
	local level = FixtureLevel.new()
	local game = GameHarness.startMatch(level)
	local ctx = game.ctx
	local survivor = ctx.pools.ships[1]
	local victim = ctx.pools.ships[2]
	local survivorBody = Bodies.get(ctx.sim.bodies, survivor.body)
	local victimBody = Bodies.get(ctx.sim.bodies, victim.body)

	survivorBody.x, survivorBody.y, survivorBody.vx, survivorBody.vy = 0, 0, 0, 0
	victimBody.x, victimBody.y, victimBody.vx, victimBody.vy = 1275, 0, 0, 0
	local zoomedOut = 720 / (2 * 1280)
	ctx.camera.zoom = zoomedOut

	FrameStepper.step(game, 1)
	assertTrue(victim.dead, "expected the victim to die at the hard boundary")
	assertTrue(not survivor.dead, "expected the survivor to stay alive")

	-- 0.15s into a 0.6s death animation: still framing the victim's death spot
	FrameStepper.step(game, 9)
	assertTrue(ctx.camera.zoom < zoomedOut + 0.02, "camera zoomed in on the survivor mid death animation")

	-- Well past the animation: camera frames the survivor alone
	FrameStepper.step(game, 90)
	assertTrue(ctx.camera.zoom > zoomedOut + 0.1, "camera never zoomed in on the survivor after the death animation")
end)
