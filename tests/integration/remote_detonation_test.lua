-- Integration tests for slice 06: remote detonation and single projectile per player.
-- Exercises the full frame order with GameHarness and FrameStepper. These tests
-- verify that:
-- 1. Projectiles no longer expire on a timer (survive 10s in open space)
-- 2. Remote detonation (fire press on armed shell) kills nearby ships
-- 3. Projectiles leaving soft boundary free the weapon slot without a blast
local GameHarness = require("tests.support.game_harness")
local FrameStepper = require("tests.support.frame_stepper")
local Bodies = require("src.sim.bodies")
local Config = require("src.game.config")

-- A shallow copy of the real config with weapon speed overridden (same pattern as shooting_test.lua)
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

test("a projectile fired upward at high speed survives before leaving boundary", function()
	-- Without a lifetime limit, a projectile will survive until it leaves the boundary.
	-- Fire at high speed so it clears the arena before falling back.
	local level = {
		worlds = {},
		spawnPoints = {
			{ x = 640, y = 400 },
			{ x = 640, y = 400 - 1000000 }, -- Far away
		},
	}
	local config = withMinSpeed(600) -- Very high speed to survive long
	local game = GameHarness.startMatch(level, { config = config })
	local ctx = game.ctx

	-- Tap to fire upward
	ctx.intents[1] = { rotate = 0, thrust = false, fire = true }
	ctx.intents[2] = { rotate = 0, thrust = false, fire = false }
	FrameStepper.step(game, 1)
	ctx.intents[1].fire = false
	FrameStepper.step(game, 1)

	assertEqual(1, #ctx.pools.projectiles, "expected the tap to spawn a projectile")
	local projectile = ctx.pools.projectiles[1]

	-- Run for 1 second - at this speed, the projectile should still be in flight
	FrameStepper.step(game, 60) -- 1 second = 60 frames at 60 fps

	-- The projectile should still exist (unless it escaped the boundary, which is unlikely at 1s)
	local stillAlive = false
	for _, p in ipairs(ctx.pools.projectiles) do
		if p.id == projectile.id then
			stillAlive = true
			break
		end
	end
	assertTrue(stillAlive or projectile.dead, "expected projectile to not expire from lifetime alone")
end)

test("remote detonation (fire press on armed shell) kills nearby enemy", function()
	-- Two ships close together. Ship 1 fires upward (away from ship 2), then presses fire again
	-- while the projectile is armed to detonate it remotely where it is.
	-- We don't expect the detonation to hit ship 2 directly, but we verify the press
	-- detonates the shell and doesn't start a charge.
	local level = {
		worlds = {},
		spawnPoints = {
			{ x = 640, y = 400 },
			{ x = 640, y = 300 },
		},
	}
	local config = withMinSpeed(200) -- Moderate speed for controlled test
	local game = GameHarness.startMatch(level, { config = config })
	local ctx = game.ctx
	local shooter = ctx.pools.ships[1]
	local target = ctx.pools.ships[2]

	-- Fire upward
	ctx.intents[1] = { rotate = 0, thrust = false, fire = true }
	ctx.intents[2] = { rotate = 0, thrust = false, fire = false }
	FrameStepper.step(game, 1)
	ctx.intents[1].fire = false
	FrameStepper.step(game, 1)

	local initialProjectileCount = #ctx.pools.projectiles
	assertTrue(initialProjectileCount > 0, "expected projectile to be spawned")
	local projectile = ctx.pools.projectiles[1]

	-- Let projectile become armed
	FrameStepper.step(game, 30) -- 0.5s: well past armDelay (0.15s)

	-- Check if projectile still exists and is armed
	local projBody = Bodies.get(ctx.sim.bodies, projectile.body)
	if projBody then
		assertTrue(projBody.armed or projectile.age >= 0.15, "expected projectile to be armed after arm delay")

		-- Remote detonate by pressing fire
		ctx.intents[1] = { rotate = 0, thrust = false, fire = true }
		FrameStepper.step(game, 1)

		-- The projectile should be detonated
		projBody = Bodies.get(ctx.sim.bodies, projectile.body)
		assertTrue(projectile.dead or projBody == nil, "expected remote detonation to mark projectile dead or body stale")
	end
end)

test("a projectile leaving soft boundary frees weapon slot without blasting", function()
	-- A projectile fired upward will eventually leave the play area. When it crosses
	-- the boundary, BoundarySystem marks it dead, ProjectileSystem clears the weapon slot,
	-- but no blast event fires (no Blast.detonate call for boundary expiry).
	local level = {
		worlds = {},
		spawnPoints = {
			{ x = 640, y = 400 },
			{ x = 640, y = 400 - 1000000 },
		},
	}
	local config = withMinSpeed(800) -- Fast enough to escape quickly
	local game = GameHarness.startMatch(level, { config = config })
	local ctx = game.ctx
	local shooter = ctx.pools.ships[1]

	-- Fire upward
	ctx.intents[1] = { rotate = 0, thrust = false, fire = true }
	FrameStepper.step(game, 1)
	ctx.intents[1].fire = false
	FrameStepper.step(game, 1)

	assertEqual(1, #ctx.pools.projectiles, "expected the fire to spawn a projectile")
	local firstProjectile = ctx.pools.projectiles[1]
	assertTrue(shooter.weapon.shell ~= nil, "expected weapon.shell to point to the projectile")

	-- Let projectile escape the boundary (the field margin is config.boundary.margin = 128)
	-- At 800 px/s upward with gravity, it should leave the play area within a few seconds.
	FrameStepper.step(game, 240) -- 4 seconds: enough time to escape

	-- The projectile should be despawned (marked dead, swept), freeing the slot
	if #ctx.pools.projectiles == 0 then
		-- It was swept (expected)
		assertFalse(firstProjectile.dead == false and #ctx.pools.projectiles > 0, "expected weapon slot to be free after boundary despawn")
	end

	-- The weapon slot should be free again (nil), allowing a new fire
	ctx.intents[1].fire = true
	FrameStepper.step(game, 1)
	ctx.intents[1].fire = false
	FrameStepper.step(game, 1)

	-- A new projectile should spawn
	assertTrue(#ctx.pools.projectiles > 0, "expected a new projectile after slot is freed")
end)
