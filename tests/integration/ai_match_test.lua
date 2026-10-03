-- AI players through the real harness: no human input, only Match.step.
local GameHarness = require("tests.support.game_harness")
local FrameStepper = require("tests.support.frame_stepper")
local Config = require("src.game.config")
local Bodies = require("src.sim.bodies")

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

local function roster(a, b)
	return {
		{ color = 1, binding = { kind = "ai", level = a } },
		{ color = 2, binding = { kind = "ai", level = b } },
	}
end

local MAX_FRAMES = 60 * 60 * 20

-- Steps until the match ends or MAX_FRAMES; returns the final ctx.
local function playMatch(seed, a, b)
	local game = GameHarness.startMatch(floorLevel(), { seed = seed, roster = roster(a, b) })
	local frames = 0
	while game.ctx.round.phase ~= "matchOver" and frames < MAX_FRAMES do
		FrameStepper.step(game, 60)
		frames = frames + 60
	end
	return game.ctx
end

test("two AIs play a full match to a winner with no human input", function()
	local ctx = playMatch(3, "medium", "medium")

	assertEqual("matchOver", ctx.round.phase)
	assertTrue(ctx.round.winner == 1 or ctx.round.winner == 2)
end)

test("an AI in tank mode shoots at an enemy", function()
	local game = GameHarness.startMatch(floorLevel(), { seed = 5, roster = roster("hard", "hard") })
	local ctx = game.ctx
	-- Enemy straight above slot 1's turret, so the AI stays landed to shoot.
	local enemy = Bodies.get(ctx.sim.bodies, ctx.pools.ships[2].body)
	enemy.x, enemy.y, enemy.pinned = -300, -100, true
	local shooter = ctx.pools.ships[1]

	local fired = false
	for _ = 1, 60 * 6 do
		FrameStepper.step(game, 1)
		if shooter.weapon.shell then
			fired = true
			break
		end
	end

	assertTrue(fired, "expected the tank AI to launch a shell")
	assertEqual("tank", shooter.lander.state)
end)

test("an AI in flight shoots at an enemy", function()
	local game = GameHarness.startMatch(floorLevel(), { seed = 5, roster = roster("hard", "hard") })
	local ctx = game.ctx
	local shooter = ctx.pools.ships[1]
	local body = Bodies.get(ctx.sim.bodies, shooter.body)
	-- Launch slot 1 into free flight, away from the floor, with the enemy far to the right.
	shooter.lander.state, shooter.lander.host, body.pinned = "flying", nil, false
	body.y, body.vx, body.vy = -300, 0, 0

	local fired = false
	for _ = 1, 60 * 4 do
		FrameStepper.step(game, 1)
		if shooter.weapon.shell then
			fired = true
			break
		end
	end

	assertTrue(fired, "expected the flying AI to launch a shell")
end)

test("the same seed and roster give identical results twice", function()
	local a = playMatch(11, "hard", "easy")
	local b = playMatch(11, "hard", "easy")

	assertEqual(a.round.score[1], b.round.score[1])
	assertEqual(a.round.score[2], b.round.score[2])
	assertEqual(a.time, b.time)
end)

test("hard beats easy more often than not over many seeded matches", function()
	local hardWins, easyWins = 0, 0
	for seed = 1, 12 do
		local ctx = playMatch(seed, "hard", "easy")
		if ctx.round.winner == 1 then
			hardWins = hardWins + 1
		elseif ctx.round.winner == 2 then
			easyWins = easyWins + 1
		end
		ctx = playMatch(seed, "easy", "hard")
		if ctx.round.winner == 2 then
			hardWins = hardWins + 1
		elseif ctx.round.winner == 1 then
			easyWins = easyWins + 1
		end
	end
	assertTrue(hardWins > easyWins, string.format("hard %d vs easy %d", hardWins, easyWins))
end)
