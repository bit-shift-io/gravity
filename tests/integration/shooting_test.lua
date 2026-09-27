-- Exercises firing, projectile flight, and the arm-delay-gated bounce/kill
-- rule through the real frame order (ShipSystem.update -> ProjectileSystem.update
-- -> Sim.step's contact list -> ShipSystem.handleContacts /
-- ProjectileSystem.handleContacts), the same way tests/integration/
-- landing_test.lua exercises landing. No worlds are needed for most of
-- these -- firing and hitting another ship don't require terrain -- so an
-- empty `worlds = {}` level keeps each test focused on the one behaviour it
-- targets.
local GameHarness = require("tests.support.game_harness")
local FrameStepper = require("tests.support.frame_stepper")
local Bodies = require("src.sim.bodies")
local Config = require("src.game.config")

-- A shallow copy of the real config with config.projectile.muzzleSpeed
-- overridden. At the canonical muzzleSpeed (500px/s), a fired shot cannot
-- escape its own shooter's close-range gravity well (config.ship.mass is
-- large -- slice 06's own tuning, not this slice's to touch) and curves
-- back onto the shooter well within its arm delay (see "a shot curved back
-- by gravity kills its shooter" below, at the canonical speed) -- exactly
-- the acceptance criterion "Projectiles curve under static and dynamic
-- gravity" in action. A dedicated "reaches a distant target" test needs a
-- higher muzzle speed to clear that same well before turning back, so this
-- helper overrides only muzzleSpeed, leaving every other tuning number
-- (including armDelay) untouched.
local function withMuzzleSpeed(muzzleSpeed)
	local overridden = {}
	for k, v in pairs(Config) do
		overridden[k] = v
	end
	overridden.projectile = {}
	for k, v in pairs(Config.projectile) do
		overridden.projectile[k] = v
	end
	overridden.projectile.muzzleSpeed = muzzleSpeed
	return overridden
end

-- Ship 1 faces "up" (angle 0, nose along (0,-1) -- src/game/components/
-- thruster.lua's NOSE convention) toward ship 2, placed directly above it at
-- `gap` px. A third, far-away spawn point keeps a two-player level's
-- gravity pull negligible for tests that only care about ships 1 and 2
-- (docs/memory gotcha: "a few thousand px still produces measurable pull",
-- so ship 2 or any unused slot goes to ~1,000,000px away instead).
local function facingLevel(gap)
	return {
		worlds = {},
		spawnPoints = {
			{ x = 640, y = 400 },
			{ x = 640, y = 400 - gap },
		},
	}
end

test("a point-blank shot bounces off the target when it hits before the arm delay", function()
	local level = facingLevel(30) -- well inside the arm delay at muzzleSpeed
	local game = GameHarness.startMatch(level)
	local ctx = game.ctx
	local shooter = ctx.pools.ships[1]
	local target = ctx.pools.ships[2]

	ctx.intents[1] = { rotate = 0, thrust = false, fire = true }
	ctx.intents[2] = { rotate = 0, thrust = false, fire = false }
	FrameStepper.step(game, 1)

	assertEqual(1, #ctx.pools.projectiles, "expected the shot to spawn a projectile")

	ctx.intents[1].fire = false
	FrameStepper.step(game, 30) -- 0.5s: comfortably more than needed to close a 30px gap, well under armDelay's 0.15s at this range only if it hits fast -- close range means it arrives in a couple of frames, long before arming.

	assertFalse(shooter.dead, "expected the shooter to survive an unarmed bounce")
	assertFalse(target.dead, "expected the point-blank target to survive an unarmed bounce")
	assertEqual(1, #ctx.pools.projectiles, "expected the projectile to bounce, not despawn")
end)

test("a shot that travels past the arm delay kills the target", function()
	-- Far enough apart that the shot's flight time exceeds config.projectile.armDelay
	-- before it reaches the target, so the hit is armed. A higher muzzle
	-- speed (see withMuzzleSpeed above) so the shot actually clears the
	-- shooter's own gravity well and reaches the target, rather than
	-- curving back the way the canonical speed does (next test).
	local level = facingLevel(300)
	local config = withMuzzleSpeed(800)
	local game = GameHarness.startMatch(level, { config = config })
	local ctx = game.ctx
	local shooter = ctx.pools.ships[1]
	local target = ctx.pools.ships[2]

	ctx.intents[1] = { rotate = 0, thrust = false, fire = true }
	ctx.intents[2] = { rotate = 0, thrust = false, fire = false }
	FrameStepper.step(game, 1)
	ctx.intents[1].fire = false

	FrameStepper.step(game, 60) -- 1s: comfortably more than the ~0.45s flight time at this speed/gap

	assertTrue(target.dead, "expected the armed hit to kill the target")
	assertFalse(shooter.dead, "expected the shooter itself to be untouched")
end)

test("a shot curved back by gravity kills its shooter", function()
	-- No target ship nearby (player 2's spawn is ~1,000,000px away, per
	-- the memory gotcha above the pull test files already follow) -- this
	-- test is purely about the shooter's own gravity well curving its shot
	-- back onto itself, not about hitting anything else. At the canonical
	-- muzzleSpeed (500px/s, below the shooter's own escape speed for
	-- config.ship.mass/config.gravity.G), a shot fired straight out decelerates,
	-- turns around, and falls back onto its own shooter once armed.
	local level = {
		worlds = {},
		spawnPoints = {
			{ x = 640, y = 400 },
			{ x = 640, y = 400 - 1000000 },
		},
	}
	local game = GameHarness.startMatch(level)
	local ctx = game.ctx
	local shooter = ctx.pools.ships[1]

	ctx.intents[1] = { rotate = 0, thrust = false, fire = true }
	ctx.intents[2] = { rotate = 0, thrust = false, fire = false }
	FrameStepper.step(game, 1)
	ctx.intents[1].fire = false

	FrameStepper.step(game, 120) -- 2s: comfortably more than the ~0.5s round trip

	assertTrue(shooter.dead, "expected the shooter's own shot to curve back and kill it once armed")
end)

test("a landed ship's fire intent does not spawn a projectile", function()
	local level = facingLevel(200)
	local game = GameHarness.startMatch(level)
	local ctx = game.ctx
	local shooter = ctx.pools.ships[1]
	local body = Bodies.get(ctx.sim.bodies, shooter.body)

	-- Fabricate a landed state directly (this test targets the fire gate,
	-- not the landing sequence landing_test.lua already covers).
	body.pinned = true
	shooter.lander.state = "landed"
	shooter.lander.host = { vertices = {} }

	ctx.intents[1] = { rotate = 0, thrust = false, fire = true }
	FrameStepper.step(game, 5)

	assertEqual(0, #ctx.pools.projectiles, "expected a landed ship's fire intent to be ignored")
end)
