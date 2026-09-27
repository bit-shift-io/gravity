-- Exercises ship-vs-ship elastic bounce through the real frame order
-- (Sim.step's circle-circle contact detection -> ShipSystem.handleContacts'
-- resolveShipBounce), the same way tests/integration/landing_test.lua
-- exercises ship-vs-world contacts.
local GameHarness = require("tests.support.game_harness")
local FrameStepper = require("tests.support.frame_stepper")
local Bodies = require("src.sim.bodies")

test("two ships colliding bounce apart elastically and both survive", function()
	-- Placed just inside contact range (collisionRadius 9 each, so contact
	-- starts within 18px) and driven straight at each other -- guarantees a
	-- collision on the very first frames rather than waiting on drift.
	local level = {
		worlds = {},
		spawnPoints = {
			{ x = 630, y = 400 },
			{ x = 650, y = 400 },
		},
	}
	local game = GameHarness.startMatch(level)
	local ctx = game.ctx
	local shipA = ctx.pools.ships[1]
	local shipB = ctx.pools.ships[2]
	local bodyA = Bodies.get(ctx.sim.bodies, shipA.body)
	local bodyB = Bodies.get(ctx.sim.bodies, shipB.body)

	bodyA.vx = 80
	bodyB.vx = -80

	FrameStepper.step(game, 5)

	assertFalse(shipA.dead, "expected ship A to survive a ship-ship collision")
	assertFalse(shipB.dead, "expected ship B to survive a ship-ship collision")

	-- Equal masses head-on: an elastic bounce exchanges the two ships'
	-- velocities along the collision normal, i.e. each ship's own velocity
	-- flips sign (rather than continuing to close the gap).
	assertTrue(bodyA.vx < 0, "expected ship A to have bounced back (negative vx)")
	assertTrue(bodyB.vx > 0, "expected ship B to have bounced back (positive vx)")
end)
