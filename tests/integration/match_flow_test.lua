-- Match flow through the real harness: scripted kills play a full match to a
-- winner, and a rematch (App.reset's path) restarts clean on the same level.
local GameHarness = require("tests.support.game_harness")
local FrameStepper = require("tests.support.frame_stepper")
local Bodies = require("src.sim.bodies")
local Config = require("src.game.config")
local LevelGen = require("src.game.level_gen")
local MatchState = require("src.app.states.match_state")
local RoundSystem = require("src.game.systems.round_system")

local function floorLevel()
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

local function hold(game)
	FrameStepper.step(game, FrameStepper.secondsToFrames(Config.round.endDelay + Config.round.cardDuration) + 3)
end

-- Kills the other player's ship so `winner` takes the round.
local function winRound(game, winner)
	local ctx = game.ctx
	for _, ship in ipairs(ctx.pools.ships) do
		if ship.player ~= winner then
			killShip(ctx, ship)
		end
	end
	FrameStepper.step(game, 1)
end

test("scripted kills play a full match to a winner on one level", function()
	local game = GameHarness.startMatch(floorLevel(), { seed = 4 })
	local ctx = game.ctx
	local level = ctx.level

	winRound(game, 1)
	hold(game)
	winRound(game, 2)
	hold(game)
	winRound(game, 1)
	hold(game)
	assertEqual("playing", ctx.round.phase)
	assertEqual(2, ctx.round.score[1])
	assertEqual(1, ctx.round.score[2])

	winRound(game, 1)
	assertEqual("matchOver", ctx.round.phase)
	assertEqual(1, ctx.round.winner)
	assertEqual(3, ctx.round.score[1])
	assertFalse(RoundSystem.cardVisible(ctx.round, Config.round))

	hold(game)
	assertEqual("matchOver", ctx.round.phase)
	assertEqual(level, ctx.level)
end)

test("rematch restarts at 0-0 on the same level and seed with tanks at the first-round spawn points", function()
	local seed = 11
	local level = LevelGen.generate(seed, Config)
	local first = MatchState.enter(level, Config, seed)
	local firstXY = {}
	for player, ship in ipairs(first.pools.ships) do
		local body = Bodies.get(first.sim.bodies, ship.body)
		firstXY[player] = { body.x, body.y }
	end
	first.round.score = { 3, 1 }
	first.round.phase = "matchOver"
	first.round.winner = 1

	-- App.reset: regenerate from the stored seed and enter afresh.
	local again = MatchState.enter(LevelGen.generate(seed, Config), Config, seed)

	assertEqual("playing", again.round.phase)
	assertEqual(0, again.round.score[1])
	assertEqual(0, again.round.score[2])
	assertEqual(#level.worlds, #again.level.worlds)
	for i, world in ipairs(level.worlds) do
		for j, v in ipairs(world.vertices) do
			assertEqual(v.x, again.level.worlds[i].vertices[j].x)
			assertEqual(v.y, again.level.worlds[i].vertices[j].y)
		end
	end
	assertEqual(first.rng:int(1, 1000000), again.rng:int(1, 1000000))
	assertEqual(2, #again.pools.ships)
	for player, ship in ipairs(again.pools.ships) do
		assertEqual("tank", ship.lander.state)
		local body = Bodies.get(again.sim.bodies, ship.body)
		assertEqual(firstXY[player][1], body.x)
		assertEqual(firstXY[player][2], body.y)
	end
end)
