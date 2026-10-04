-- AI personalities through the real harness on generated levels: seeded
-- six-AI matches with mixed levels play to a winner, no AI throws or sits
-- idle while an enemy lives, every personality fires and wins rounds, hard
-- beats easy when both fly the same personality, and the Kamikaze scores
-- kills.
local AI = require("src.game.ai.init")
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

-- Every pooled personality, bound by slot in the mixed matches (a seeded
-- draw reshuffles whenever a kind joins the pool): pool entry i flies
-- mixed-match slot i, counting on through the matches' 18 slots and
-- wrapping round the pool (mixedPersonality).
local ALL = AI.pool()
local PERSONALITIES = { "hopper", "hunter", "sniper" }
local MIXED_SEEDS = { 2, 4, 9 }
-- Hard and easy duel in both slot orders, both flying the same personality,
-- which rotates with the seed: 1 hopper, 2 hunter, 3 sniper, 4 hopper...
-- (Seed 9's level is one small world where two Snipers never find a solved
-- shot or a vantage point, so that duel never ends.)
local DUEL_SEEDS = { 1, 2, 3, 4, 5, 6, 7, 8 }
-- A hard Kamikaze against a hard Hunter, one match per seed.
local KAMIKAZE_SEEDS = { 1, 2, 3 }

-- `behavior` is one name for every slot, or a list by slot.
local function roster(levels, behavior)
	local slots = {}
	for slot, level in ipairs(levels) do
		local name = type(behavior) == "table" and behavior[slot] or behavior
		slots[slot] = { color = slot, binding = { kind = "ai", level = level, behavior = name } }
	end
	return slots
end

local function counters(n)
	local list = {}
	for slot = 1, n do
		list[slot] = 0
	end
	return list
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
-- idleBy = "slot level personality", and by slot: wins, shots, kills,
-- selfKills }`. A kill is an enemy ship that dies on the step the slot's
-- shell goes off; a self-kill is the slot's own ship dying so.
local function play(seed, levels, behavior)
	local game = GameHarness.startMatch(LevelGen.generate(seed, Config), { seed = seed, roster = roster(levels, behavior) })
	local ctx = game.ctx
	local result = {
		ctx = ctx,
		rounds = { hard = 0, easy = 0, draw = 0 },
		idle = 0,
		wins = counters(#levels),
		shots = counters(#levels),
		kills = counters(#levels),
		selfKills = counters(#levels),
	}
	local idle = {}
	local lastShell = {}
	local lastResult
	for _ = 1, MAX_SECONDS * 60 do
		if ctx.round.phase == "matchOver" then
			break
		end
		-- Dead ships drop out of the pool, so keep references to the living.
		local living, shells = {}, {}
		for _, ship in ipairs(ctx.pools.ships) do
			if not ship.dead then
				living[#living + 1] = ship
				local id = ship.weapon.shell
				local body = id and Bodies.get(ctx.sim.bodies, id)
				if body then
					shells[ship.player] = { id = id, body = body }
				end
			end
		end

		local ok, err = pcall(FrameStepper.step, game, 1)
		if not ok then
			result.error = err
			return result
		end

		for slot, shell in pairs(shells) do
			if shell.body.dead or not Bodies.get(ctx.sim.bodies, shell.id) then
				for _, ship in ipairs(living) do
					if ship.dead then
						local tally = ship.player == slot and result.selfKills or result.kills
						tally[slot] = tally[slot] + 1
					end
				end
			end
		end
		for _, ship in ipairs(ctx.pools.ships) do
			local id = ship.weapon.shell
			if id and id ~= lastShell[ship.player] then
				result.shots[ship.player] = result.shots[ship.player] + 1
			end
			lastShell[ship.player] = id
		end

		if ctx.round.result ~= lastResult then
			lastResult = ctx.round.result
			if lastResult then
				local key = lastResult.winner and levels[lastResult.winner] or "draw"
				result.rounds[key] = result.rounds[key] + 1
				if lastResult.winner then
					result.wins[lastResult.winner] = result.wins[lastResult.winner] + 1
				end
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
						tostring(ctx.roster[ship.player].binding.behavior or ctx.personalities[ship.player])
					)
				end
			else
				idle[ship] = 0
			end
		end
	end
	return result
end

-- The personality flying `slot` of mixed match `index`. The third match's
-- levels start hard where the first two start easy, so its neighbouring
-- slots swap: with nine personalities, each flies once hard and once easy.
local function mixedPersonality(index, slot)
	local k = (index - 1) * 6 + slot - 1
	if index == 3 then
		k = k + (slot % 2 == 1 and 1 or -1)
	end
	return ALL[k % #ALL + 1]
end

-- Each seeded run plays once; the tests below read the same results.
local mixedRuns
local function mixed()
	if not mixedRuns then
		mixedRuns = {}
		for index, seed in ipairs(MIXED_SEEDS) do
			-- Hard and easy alternate, hard first on odd seeds.
			local levels = seed % 2 == 1 and { "hard", "easy", "hard", "easy", "hard", "easy" }
				or { "easy", "hard", "easy", "hard", "easy", "hard" }
			local behaviors = {}
			for slot = 1, 6 do
				behaviors[slot] = mixedPersonality(index, slot)
			end
			mixedRuns[seed] = play(seed, levels, behaviors)
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
	local flown = {}
	for _, seed in ipairs(MIXED_SEEDS) do
		local run = mixed()[seed]
		assertEqual(nil, run.error, string.format("seed %d threw: %s", seed, tostring(run.error)))
		assertEqual("matchOver", run.ctx.round.phase, string.format("seed %d never finished", seed))
		assertTrue(run.ctx.round.winner ~= nil, string.format("seed %d has no winner", seed))
		for _, entry in ipairs(run.ctx.roster) do
			flown[entry.binding.behavior] = true
		end
	end
	for _, name in ipairs(ALL) do
		assertTrue(flown[name], "fixture: the mixed matches fly every personality, missing " .. name)
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

-- Per personality over the mixed matches: rounds won, shots, kills and
-- self-kills.
local function tally()
	local rows = {}
	for _, name in ipairs(ALL) do
		rows[name] = { wins = 0, shots = 0, kills = 0, selfKills = 0 }
	end
	for index, seed in ipairs(MIXED_SEEDS) do
		local run = mixed()[seed]
		for slot = 1, 6 do
			local row = rows[mixedPersonality(index, slot)]
			row.wins = row.wins + run.wins[slot]
			row.shots = row.shots + run.shots[slot]
			row.kills = row.kills + run.kills[slot]
			row.selfKills = row.selfKills + run.selfKills[slot]
		end
	end
	return rows
end

test("every personality fires and wins rounds in the mixed matches", function()
	local rows = tally()
	-- Printed, so a balance run reports the numbers whatever it asserts.
	for _, name in ipairs(ALL) do
		local row = rows[name]
		print(string.format("  %-10s wins %2d  shots %3d  kills %2d  self-kills %2d", name, row.wins, row.shots, row.kills, row.selfKills))
	end
	for _, name in ipairs(ALL) do
		assertTrue(rows[name].shots > 0, name .. " never fired")
		assertTrue(rows[name].wins > 0, name .. " never won a round")
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

test("a hard kamikaze scores kills against a hard hunter", function()
	local kills, selfKills, shots = 0, 0, 0
	for _, seed in ipairs(KAMIKAZE_SEEDS) do
		local run = play(seed, { "hard", "hard" }, { "kamikaze", "hunter" })
		assertEqual(nil, run.error, string.format("kamikaze seed %d threw: %s", seed, tostring(run.error)))
		kills = kills + run.kills[1]
		selfKills = selfKills + run.selfKills[1]
		shots = shots + run.shots[1]
	end
	print(string.format("  kamikaze vs hunter: %d kills, %d self-kills from %d shots", kills, selfKills, shots))
	-- Reliable: at least one kill a match, and a kill for every four shots.
	assertTrue(kills >= #KAMIKAZE_SEEDS, string.format("%d kills in %d matches", kills, #KAMIKAZE_SEEDS))
	assertTrue(kills * 4 >= shots, string.format("%d kills from %d shots", kills, shots))
end)
