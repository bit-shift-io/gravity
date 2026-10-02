-- Round cycle through the real harness: a kill locks the round, the end
-- delay elapses, and a fresh round starts on the same level.
local GameHarness = require("tests.support.game_harness")
local FrameStepper = require("tests.support.frame_stepper")
local Bodies = require("src.sim.bodies")
local Config = require("src.game.config")

-- A wide floor with five tank-ready spawn candidates on its top face; the
-- first two double as round 1's spawn points.
local function roundLevel()
	local world = {
		vertices = { { x = -400, y = 100 }, { x = 400, y = 100 }, { x = 400, y = 200 }, { x = -400, y = 200 } },
		mass = 1000,
	}
	local function point(x)
		return { x = x, y = 100, normal = { x = 0, y = -1 }, world = world }
	end
	return {
		worlds = { world },
		spawnPoints = { point(-300), point(300) },
		spawnCandidates = { point(-300), point(-150), point(0), point(150), point(300) },
	}
end

local function killShip(ctx, ship)
	ship.dead = true
	Bodies.markDead(ctx.sim.bodies, ship.body)
end

local function endRound(game)
	FrameStepper.step(game, FrameStepper.secondsToFrames(Config.round.endDelay + Config.round.cardDuration) + 3)
end

test("a kill scores, then after the end delay both ships respawn on a clean field", function()
	local game = GameHarness.startMatch(roundLevel(), { seed = 3 })
	local ctx = game.ctx
	local level = ctx.level
	local oldShips = { ctx.pools.ships[1], ctx.pools.ships[2] }
	oldShips[2].fuel.amount = 2

	killShip(ctx, oldShips[1])
	FrameStepper.step(game, 1)
	assertEqual("roundOver", ctx.round.phase)
	assertEqual(2, ctx.round.result.winner)

	endRound(game)

	assertEqual("playing", ctx.round.phase)
	assertEqual(level, ctx.level)
	assertEqual(2, #ctx.pools.ships)
	for _, ship in ipairs(ctx.pools.ships) do
		assertFalse(ship.dead)
		assertTrue(ship ~= oldShips[1] and ship ~= oldShips[2])
		assertEqual("tank", ship.lander.state)
		assertEqual(Config.ship.fuel.capacity, ship.fuel.amount)
		assertEqual(0, ship.turret.angle)
	end
	assertEqual(0, #ctx.pools.projectiles)
	assertEqual(0, #ctx.pools.asteroids)
	assertEqual(0, #ctx.events)
	assertEqual(0, ctx.round.score[1])
	assertEqual(1, ctx.round.score[2])
end)

test("a projectile in flight at reset is gone and the player can fire again at once", function()
	local game = GameHarness.startMatch(roundLevel(), { seed = 3 })
	local ctx = game.ctx
	local shooter = ctx.pools.ships[2]

	ctx.intents[2] = { rotate = 0, thrust = false, fire = true }
	FrameStepper.step(game, 1)
	ctx.intents[2].fire = false
	FrameStepper.step(game, 1)
	assertEqual(1, #ctx.pools.projectiles, "expected a shot in flight")

	killShip(ctx, ctx.pools.ships[1])
	endRound(game)

	assertEqual(0, #ctx.pools.projectiles)
	assertTrue(ctx.pools.ships[2] ~= shooter)

	-- Fire again straight away on the fresh ship.
	local fresh = ctx.pools.ships[2]
	ctx.intents[fresh.player] = { rotate = 0, thrust = false, fire = true }
	FrameStepper.step(game, 1)
	ctx.intents[fresh.player].fire = false
	FrameStepper.step(game, 1)
	assertEqual(1, #ctx.pools.projectiles, "expected the fresh ship to fire")
end)
