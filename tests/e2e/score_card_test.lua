-- The score card draws through the real renderer during the card phase only.
local GameHarness = require("tests.support.game_harness")
local FrameStepper = require("tests.support.frame_stepper")
local Capture = require("tests.support.capture")
local Bodies = require("src.sim.bodies")
local Config = require("src.game.config")
local RoundSystem = require("src.game.systems.round_system")
local FixtureLevel = require("src.game.levels.fixture_two_worlds")

test("the score card appears after the end delay and is gone after respawn", function()
	local game = GameHarness.startMatch(FixtureLevel.new(), { real = true })
	local ctx = game.ctx
	local ship = ctx.pools.ships[1]
	ship.dead = true
	Bodies.markDead(ctx.sim.bodies, ship.body)

	FrameStepper.step(game, FrameStepper.secondsToFrames(Config.round.endDelay / 2))
	assertFalse(RoundSystem.cardVisible(ctx.round, Config.round))

	FrameStepper.step(game, FrameStepper.secondsToFrames(Config.round.endDelay / 2 + Config.round.cardDuration / 2))
	assertTrue(RoundSystem.cardVisible(ctx.round, Config.round))
	Capture.capture("score_card")

	FrameStepper.step(game, FrameStepper.secondsToFrames(Config.round.cardDuration / 2) + 3)
	assertFalse(RoundSystem.cardVisible(ctx.round, Config.round))
end)
