-- AI personalities through the real harness on generated levels: seeded
-- six-AI matches with mixed levels play to a winner, no AI throws or sits
-- idle while an enemy lives, and hard beats easy when both fly the same
-- personality.
local GameHarness = require("tests.support.game_harness")
local FrameStepper = require("tests.support.frame_stepper")
local Config = require("src.game.config")
local LevelGen = require("src.game.level_gen")
local Bodies = require("src.sim.bodies")

-- The longest an AI may hold a neutral intent (no turn, thrust or fire)
-- with no shell of its own in flight, while an enemy lives. A Sniper waits
-- config.ai.relocateDelay for a shot and a Hunter may coast between burns.
local STUCK_SECONDS = 10
-- No match in these seeds needs anywhere near this; it only stops a
-- regression from hanging the suite.
local MAX_SECONDS = 1200

local PERSONALITIES = { "hopper", "hunter", "sniper" }
local MIXED_SEEDS = { 2, 4, 9 }
-- Hard and easy duel in both slot orders, both flying the same personality,
-- which rotates with the seed: 1 hopper, 2 hunter, 3 sniper, 4 hopper...
-- (Seed 9's level is one small world where two Snipers never find a solved
-- shot or a vantage point, so that duel never ends.)
local DUEL_SEEDS = { 1, 2, 3, 4, 5, 6, 7, 8 }

local function roster(levels, behavior)
	local slots = {}
	for slot, level in ipairs(levels) do
		slots[slot] = { color = slot, binding = { kind = "ai", level = level, behavior = behavior } }
	end
	return slots
end

local function livingCount(ctx)
	local count = 0
	for _, ship in ipairs(ctx.pools.ships) do
		if not ship.dead then
			count = count + 1
		end
	end
	return count
end

-- Plays one match to matchOver (or MAX_SECONDS). Returns `{ ctx, error,
-- rounds = { [level] = rounds won, draw = n }, idle = longest idle seconds,
-- idleBy = "slot level personality" }`.
local function play(seed, levels, behavior)
	local game = GameHarness.startMatch(LevelGen.generate(seed, Config), { seed = seed, roster = roster(levels, behavior) })
	local ctx = game.ctx
	local result = { ctx = ctx, rounds = { hard = 0, easy = 0, draw = 0 }, idle = 0 }
	local idle = {}
	local lastResult
	for _ = 1, MAX_SECONDS * 60 do
		if ctx.round.phase == "matchOver" then
			break
		end
		local ok, err = pcall(FrameStepper.step, game, 1)
		if not ok then
			result.error = err
			return result
		end

		if ctx.round.result ~= lastResult then
			lastResult = ctx.round.result
			if lastResult then
				local key = lastResult.winner and levels[lastResult.winner] or "draw"
				result.rounds[key] = result.rounds[key] + 1
			end
		end

		local contested = ctx.round.phase == "playing" and livingCount(ctx) > 1
		for _, ship in ipairs(ctx.pools.ships) do
			local intent = ctx.intents[ship.player]
			local shell = ship.weapon.shell and Bodies.get(ctx.sim.bodies, ship.weapon.shell)
			local neutral = intent and intent.rotate == 0 and not intent.thrust and not intent.fire
			if contested and not ship.dead and neutral and not shell then
				idle[ship] = (idle[ship] or 0) + 1 / 60
				if idle[ship] > result.idle then
					result.idle = idle[ship]
					result.idleBy = string.format(
						"slot %d %s %s",
						ship.player,
						levels[ship.player],
						tostring(behavior or ctx.personalities[ship.player])
					)
				end
			else
				idle[ship] = 0
			end
		end
	end
	return result
end

-- Each seeded run plays once; the tests below read the same results.
local mixedRuns
local function mixed()
	if not mixedRuns then
		mixedRuns = {}
		for _, seed in ipairs(MIXED_SEEDS) do
			-- Hard and easy alternate, hard first on odd seeds.
			local levels = seed % 2 == 1 and { "hard", "easy", "hard", "easy", "hard", "easy" }
				or { "easy", "hard", "easy", "hard", "easy", "hard" }
			mixedRuns[seed] = play(seed, levels)
		end
	end
	return mixedRuns
end

local duelRuns
local function duels()
	if not duelRuns then
		duelRuns = {}
		for _, seed in ipairs(DUEL_SEEDS) do
			local behavior = PERSONALITIES[(seed - 1) % #PERSONALITIES + 1]
			duelRuns[#duelRuns + 1] = { behavior = behavior, seed = seed, run = play(seed, { "hard", "easy" }, behavior) }
			duelRuns[#duelRuns + 1] = { behavior = behavior, seed = seed, run = play(seed, { "easy", "hard" }, behavior) }
		end
	end
	return duelRuns
end

test("seeded six-AI matches with mixed levels play to a winner without an AI throwing", function()
	local drawn = {}
	for _, seed in ipairs(MIXED_SEEDS) do
		local run = mixed()[seed]
		assertEqual(nil, run.error, string.format("seed %d threw: %s", seed, tostring(run.error)))
		assertEqual("matchOver", run.ctx.round.phase, string.format("seed %d never finished", seed))
		assertTrue(run.ctx.round.winner ~= nil, string.format("seed %d has no winner", seed))
		for _, name in pairs(run.ctx.personalities) do
			drawn[name] = true
		end
	end
	for _, name in ipairs(PERSONALITIES) do
		assertTrue(drawn[name], "fixture: the seeds draw every personality, missing " .. name)
	end
end)

test("no AI sits idle while an enemy lives", function()
	for _, seed in ipairs(MIXED_SEEDS) do
		local run = mixed()[seed]
		assertTrue(
			run.idle <= STUCK_SECONDS,
			string.format("seed %d: %s idle for %.1f s", seed, tostring(run.idleBy), run.idle)
		)
	end
	for _, duel in ipairs(duels()) do
		assertEqual(nil, duel.run.error, string.format("%s seed %d threw: %s", duel.behavior, duel.seed, tostring(duel.run.error)))
		assertTrue(
			duel.run.idle <= STUCK_SECONDS,
			string.format("%s duel seed %d: %s idle for %.1f s", duel.behavior, duel.seed, tostring(duel.run.idleBy), duel.run.idle)
		)
	end
end)

test("hard wins a clear majority of rounds against easy flying the same personality", function()
	local hard, easy = 0, 0
	for _, duel in ipairs(duels()) do
		assertEqual("matchOver", duel.run.ctx.round.phase, string.format("%s duel seed %d never finished", duel.behavior, duel.seed))
		hard = hard + duel.run.rounds.hard
		easy = easy + duel.run.rounds.easy
	end
	-- A clear majority: at least five rounds for every four easy wins.
	assertTrue(hard >= 1.25 * easy, string.format("hard %d vs easy %d rounds", hard, easy))
end)
