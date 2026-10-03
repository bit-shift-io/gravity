-- Exercises firing, projectile flight, and the arm-delay-gated bounce/kill
-- rule through the real frame order (ShipSystem.update -> ProjectileSystem.update
-- -> Sim.step's contact list -> ShipSystem.handleContacts /
-- ProjectileSystem.handleContacts), the same way tests/integration/
-- landing_test.lua exercises landing. No worlds are needed for most of
-- these -- firing and hitting another ship don't require terrain -- so an
-- empty `worlds = {}` level keeps each test focused on the one behaviour it
-- targets. A tap release fires at minSpeed; longer charges reach higher
-- speeds up to maxSpeed.
local GameHarness = require("tests.support.game_harness")
local FrameStepper = require("tests.support.frame_stepper")
local Bodies = require("src.sim.bodies")
local Config = require("src.game.config")

-- A shallow copy of the real config with weapon speed overridden. At the
-- minSpeed (150px/s), a fired shot cannot escape its own shooter's
-- close-range gravity well and curves back onto the shooter well within its
-- arm delay. A test that needs the shot to reach a distant target overrides
-- minSpeed to a higher value so the shot clears the gravity well.
local function withMinSpeed(minSpeed)
	local overridden = {}
	for k, v in pairs(Config) do
		overridden[k] = v
	end
	overridden.weapon = {}
	for k, v in pairs(Config.weapon) do
		overridden.weapon[k] = v
	end
	overridden.weapon.minSpeed = minSpeed
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
	-- Use a 15px gap and high minSpeed so the shot reaches the target in well
	-- under 0.15s (armDelay), ensuring it hits unarmed and bounces. Close the gap
	-- quickly enough that gravity doesn't affect the initial trajectory.
	local level = facingLevel(15)
	local config = withMinSpeed(400) -- High speed so impact is very quick
	local game = GameHarness.startMatch(level, { config = config })
	local ctx = game.ctx
	local shooter = ctx.pools.ships[1]
	local target = ctx.pools.ships[2]

	-- Tap: press on frame 1
	ctx.intents[1] = { rotate = 0, thrust = false, fire = true }
	ctx.intents[2] = { rotate = 0, thrust = false, fire = false }
	FrameStepper.step(game, 1)

	-- Release on frame 2 (fire is released, projectile spawns)
	ctx.intents[1].fire = false
	FrameStepper.step(game, 1)

	assertEqual(1, #ctx.pools.projectiles, "expected the tap to spawn a projectile")

	-- Let projectile travel. At 400 px/s, 15px takes 0.0375s, well before arming at 0.15s
	FrameStepper.step(game, 3) -- 5 frames total; projectile should hit before arming

	-- Check immediately after impact
	assertFalse(shooter.dead, "expected the shooter to survive an unarmed bounce")
	assertFalse(target.dead, "expected the point-blank target to survive an unarmed bounce")
	assertEqual(1, #ctx.pools.projectiles, "expected the projectile to bounce, not despawn")
end)

test("a shot that travels past the arm delay kills the target", function()
	-- Far enough apart that the shot's flight time exceeds config.projectile.armDelay
	-- before it reaches the target, so the hit is armed. A higher min speed
	-- (see withMinSpeed above) so the shot actually clears the shooter's own
	-- gravity well and reaches the target, rather than curving back the way
	-- the canonical minSpeed does (next test).
	local level = facingLevel(300)
	local config = withMinSpeed(800)
	local game = GameHarness.startMatch(level, { config = config })
	local ctx = game.ctx
	local shooter = ctx.pools.ships[1]
	local target = ctx.pools.ships[2]

	-- Tap to fire at minSpeed (which is now 800)
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
	-- back onto itself, not about hitting anything else. At minSpeed 60px/s
	-- (below the shooter's own escape speed for config.ship.mass/config.gravity.G),
	-- a shot fired straight out decelerates, turns around, and falls back
	-- onto its own shooter once armed.
	local level = {
		worlds = {},
		spawnPoints = {
			{ x = 640, y = 400 },
			{ x = 640, y = 400 - 1000000 },
		},
	}
	local config = withMinSpeed(60)
	local game = GameHarness.startMatch(level, { config = config })
	local ctx = game.ctx
	local shooter = ctx.pools.ships[1]

	-- Tap to fire at minSpeed (60)
	ctx.intents[1] = { rotate = 0, thrust = false, fire = true }
	ctx.intents[2] = { rotate = 0, thrust = false, fire = false }
	FrameStepper.step(game, 1)
	ctx.intents[1].fire = false

	FrameStepper.step(game, 180) -- 3s: comfortably more than the round trip time

	assertTrue(shooter.dead, "expected the shooter's own shot to curve back and kill it once armed")
end)

test("a tank ship can charge and fire from the turret muzzle", function()
	local level = facingLevel(200)
	local game = GameHarness.startMatch(level)
	local ctx = game.ctx
	local shooter = ctx.pools.ships[1]
	local body = Bodies.get(ctx.sim.bodies, shooter.body)

	-- Fabricate a tank state directly (this test targets tank firing,
	-- not the landing sequence landing_test.lua already covers).
	body.pinned = true
	shooter.lander.state = "tank"
	shooter.lander.host = { vertices = {} }

	-- Tap to fire
	ctx.intents[1] = { rotate = 0, thrust = false, fire = true }
	FrameStepper.step(game, 1)
	ctx.intents[1].fire = false
	FrameStepper.step(game, 1)

	assertEqual(1, #ctx.pools.projectiles, "expected a tank ship to fire a projectile from the turret muzzle")
end)

test("a tank with turret at +limit fires along the turret direction", function()
	-- Place a target far to the right to check that the turret angle affects
	-- the firing direction, not just the ship's angle.
	local level = {
		worlds = {},
		spawnPoints = {
			{ x = 640, y = 400 },
			{ x = 1000, y = 400 },
		},
	}
	local game = GameHarness.startMatch(level)
	local ctx = game.ctx
	local shooter = ctx.pools.ships[1]
	local target = ctx.pools.ships[2]
	local body = Bodies.get(ctx.sim.bodies, shooter.body)

	-- Fabricate a tank state
	body.pinned = true
	shooter.lander.state = "tank"
	shooter.lander.host = { vertices = {} }

	-- Rotate turret to +limit (maximum right)
	shooter.turret.angle = ctx.config.tank.turretLimit

	-- Tap to fire: press on frame 1
	ctx.intents[1] = { rotate = 0, thrust = false, fire = true }
	FrameStepper.step(game, 1)

	-- Release on frame 2 (projectile spawns)
	ctx.intents[1].fire = false
	FrameStepper.step(game, 1)

	assertEqual(1, #ctx.pools.projectiles, "expected a projectile to spawn from tank turret")
	-- The projectile should have positive vx since it's fired to the right
	local projectile = ctx.pools.projectiles[1]
	local projBody = Bodies.get(ctx.sim.bodies, projectile.body)
	assertTrue(projBody.vx > 0, "expected projectile to fire rightward along turret direction")
end)

test("charge carries over landing and lift-off", function()
	-- Simplified test: fabricate tank state, charge while landed, then fire
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
	local body = Bodies.get(ctx.sim.bodies, shooter.body)

	-- Fabricate a tank state
	body.pinned = true
	shooter.lander.state = "tank"
	shooter.lander.host = { vertices = {} }

	-- Press fire (start charging)
	ctx.intents[1] = { rotate = 0, thrust = false, fire = true }
	FrameStepper.step(game, 1)

	-- Hold and charge for 2 seconds
	local chargeFrames = math.floor(2 / (1 / 60)) - 1
	for _ = 1, chargeFrames do
		FrameStepper.step(game, 1)
	end

	assertTrue(shooter.weapon.charging, "expected weapon to be charging while fire intent is held")
	assertTrue(shooter.weapon.charge >= 1.9, "expected charge to accumulate to ~2 seconds")

	-- Release to fire
	ctx.intents[1] = { rotate = 0, thrust = false, fire = false }
	FrameStepper.step(game, 1)

	assertEqual(1, #ctx.pools.projectiles, "expected charge to carry and fire when released")
	-- At 2 seconds into chargeTime (3), the speed should be well above minimum
	local projectile = ctx.pools.projectiles[1]
	local projBody = Bodies.get(ctx.sim.bodies, projectile.body)
	local minSpeed = ctx.config.weapon.minSpeed
	local chargeSpeed = math.abs(projBody.vy) -- direction.y = -1, so vy is negative
	assertTrue(chargeSpeed > minSpeed, "expected the charged shot to exceed minSpeed")
end)

test("an armed blast kills multiple ships in its radius", function()
	-- Three ships: shooter fires at target, and a bystander nearby target.
	-- All three are close together so the blast catches the bystander too.
	local level = {
		worlds = {},
		spawnPoints = {
			{ x = 640, y = 400 },
			{ x = 640, y = 200 },
			{ x = 660, y = 200 },
		},
	}
	local config = withMinSpeed(800) -- High speed to ensure blast on first ship
	local roster = {}
	local layouts = { "wasd", "arrows", "ijkl" }
	for slot = 1, 3 do
		roster[slot] = { color = slot, binding = { kind = "keyboard", layout = layouts[slot] } }
	end
	local game = GameHarness.startMatch(level, { config = config, roster = roster })
	local ctx = game.ctx
	local shooter = ctx.pools.ships[1]
	local target = ctx.pools.ships[2]
	local bystander = ctx.pools.ships[3]

	-- Tap to fire
	ctx.intents[1] = { rotate = 0, thrust = false, fire = true }
	ctx.intents[2] = { rotate = 0, thrust = false, fire = false }
	ctx.intents[3] = { rotate = 0, thrust = false, fire = false }
	FrameStepper.step(game, 1)
	ctx.intents[1].fire = false

	-- Let projectile travel and become armed
	FrameStepper.step(game, 60) -- 1s: well past armDelay

	assertTrue(target.dead, "expected the direct target to be dead from the blast")
	assertTrue(bystander.dead, "expected the bystander within blast radius to be dead")
	assertFalse(shooter.dead, "expected the shooter to survive (not in blast radius)")
end)

test("an unarmed projectile still bounces off its shooter", function()
	-- A very close target so the projectile hits before arming.
	-- The shooter should not be killed.
	local level = facingLevel(15)
	local config = withMinSpeed(400)
	local game = GameHarness.startMatch(level, { config = config })
	local ctx = game.ctx
	local shooter = ctx.pools.ships[1]

	-- Tap to fire
	ctx.intents[1] = { rotate = 0, thrust = false, fire = true }
	ctx.intents[2] = { rotate = 0, thrust = false, fire = false }
	FrameStepper.step(game, 1)
	ctx.intents[1].fire = false

	-- Let it hit just before arming
	FrameStepper.step(game, 3)

	assertFalse(shooter.dead, "expected the shooter to survive an unarmed bounce")
end)
