local AI = require("src.game.ai.init")
local Match = require("src.game.match")
local Config = require("src.game.config")
local LevelGen = require("src.game.level_gen")

-- Runs `fn` with the registry holding only "hopper" (other test files register
-- kinds that would join the pool), then restores it.
local function withKinds(extra, fn)
	local saved = AI.kinds
	AI.kinds = { hopper = saved.hopper }
	for name, kind in pairs(extra or {}) do
		AI.kinds[name] = kind
	end
	local ok, err = pcall(fn)
	AI.kinds = saved
	if not ok then
		error(err, 0)
	end
end

local idle = { update = function() end }

local function roster()
	return {
		{ color = 1, binding = { kind = "keyboard", layout = "wasd" } },
		{ color = 2, binding = { kind = "ai", level = "easy" } },
		{ color = 3, binding = { kind = "ai", level = "hard" } },
		{ color = 4, binding = { kind = "ai", level = "hard" } },
	}
end

local function newMatch(seed)
	local level = LevelGen.generate(seed, Config)
	return Match.new(level, Config, seed, { roster = roster() })
end

test("every AI slot gets a personality at Match.new and human slots get none", function()
	withKinds(nil, function()
		local ctx = newMatch(7)
		assertEqual("hopper", ctx.personalities[2])
		assertEqual("hopper", ctx.personalities[3])
		assertEqual("hopper", ctx.personalities[4])
		assertTrue(ctx.personalities[1] == nil)
	end)
end)

test("the same seed and roster draw the same personalities", function()
	withKinds({ alpha = idle, beta = idle, gamma = idle }, function()
		local a = newMatch(12345).personalities
		local b = newMatch(12345).personalities
		for slot = 2, 4 do
			assertEqual(a[slot], b[slot])
		end
	end)
end)

test("different seeds can draw different personalities", function()
	withKinds({ alpha = idle, beta = idle, gamma = idle }, function()
		local seen = {}
		for seed = 1, 30 do
			seen[newMatch(seed).personalities[2]] = true
		end
		local count = 0
		for _ in pairs(seen) do
			count = count + 1
		end
		assertTrue(count > 1, "30 seeds drew a single personality")
	end)
end)

test("registering a personality adds it to the pool, sorted by name", function()
	withKinds({ zeta = idle, alpha = idle }, function()
		local pool = AI.pool()
		assertEqual(3, #pool)
		assertEqual("alpha", pool[1])
		assertEqual("hopper", pool[2])
		assertEqual("zeta", pool[3])
	end)
end)

test("drawing personalities leaves ctx.rng untouched", function()
	local seed = 99
	local humans = roster()
	for slot = 2, 4 do
		humans[slot].binding = { kind = "keyboard", layout = "ijkl" }
	end
	local control = Match.new(LevelGen.generate(seed, Config), Config, seed, { roster = humans })
	withKinds({ alpha = idle, beta = idle }, function()
		local ctx = newMatch(seed)
		assertEqual(control.rng.state, ctx.rng.state)
	end)
end)
