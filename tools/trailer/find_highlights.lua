-- Highlight finder CLI (dev-only, plain LuaJIT, no `love`). Runs seeded all-AI
-- matches, scores sliding step windows per category (tools/trailer/highlights.lua)
-- and prints the best windows as pasteable trailer shot entries.
--
--   luajit tools/trailer/find_highlights.lua seeds=1-200 players=6 window=240 count=3
--
-- Arguments (all optional): seeds=A-B (default 1-50), players=2..6 (6),
-- window=steps (240), count=results per category (3), seconds=match length
-- simulated per seed (60), level=easy|hard for every slot (hard), jobs=worker
-- processes to split the seeds over (8; 1 runs in this process). A match takes
-- about 2 to 5 s, so 200 seeds of 60 s take under 3 minutes on 12 cores (about 4.5 minutes with jobs=4).
-- Suggests only: it never writes the manifest.
package.path = "./?.lua;" .. package.path

local Config = require("src.game.config")
local Highlights = require("tools.trailer.highlights")
local LevelGen = require("src.game.level_gen")
local Scene = require("tools.steam_assets.scene")

local FPS = 60
local DEFAULTS = { seeds = "1-50", players = "6", window = "240", count = "3", seconds = "60", level = "hard", jobs = "8", worker = "0" }

local function parse(argv)
	local args = {}
	for key, value in pairs(DEFAULTS) do
		args[key] = value
	end
	for _, arg in ipairs(argv) do
		local key, value = arg:match("^(%w+)=(.+)$")
		if not key or not DEFAULTS[key] then
			error("unknown argument '" .. arg .. "'; expected key=value with keys seeds, players, window, count, seconds, level", 0)
		end
		args[key] = value
	end
	local first, last = args.seeds:match("^(%d+)%-(%d+)$")
	if not first then
		first = args.seeds:match("^(%d+)$")
		last = first
	end
	assert(first, "seeds must be N or A-B")
	return {
		first = tonumber(first),
		last = tonumber(last),
		players = tonumber(args.players),
		window = tonumber(args.window),
		count = tonumber(args.count),
		seconds = tonumber(args.seconds),
		level = args.level,
		jobs = math.max(1, tonumber(args.jobs)),
		worker = args.worker == "1",
	}
end

local function recordMatch(seed, roster, steps)
	local ctx = Scene.build({ seed = seed, roster = roster, step = 0 })
	local recorder = Highlights.recorder()
	for step = 1, steps do
		Scene.step(ctx)
		recorder:observe(ctx, step)
	end
	return recorder:steps()
end

-- brawl is also reported per world kind, so both can be picked.
local function groupsFor(category, kind)
	local groups = { category }
	if category == "brawl" and kind ~= "mixed" then
		groups[2] = "brawl-" .. kind
	end
	return groups
end

-- The best window per seed and category: { category, seed, kind, from, to, score }.
local function scan(opts, first, last)
	local roster = Highlights.roster(opts.players, opts.level)
	local hits = {}
	for seed = first, last do
		local kind = Highlights.worldKind(LevelGen.generate(seed, Config))
		local steps = recordMatch(seed, roster, opts.seconds * FPS)
		for _, category in ipairs(Highlights.ORDER) do
			local best = Highlights.top(steps, category, { window = opts.window, count = 1 })[1]
			if best then
				hits[#hits + 1] = { category = category, seed = seed, kind = kind, from = best.from, to = best.to, score = best.score }
			end
		end
	end
	return hits
end

-- Workers print one tab-separated hit per line.
local function printHits(hits)
	for _, hit in ipairs(hits) do
		print(table.concat({ hit.category, hit.seed, hit.kind, hit.from, hit.to, string.format("%.6f", hit.score) }, "\t"))
	end
end

-- Splits first..last over opts.jobs child processes, all started before any is read.
local function scanParallel(opts)
	local jobs = math.min(opts.jobs, opts.last - opts.first + 1)
	local interpreter = arg[-1] or "luajit"
	local pipes = {}
	local size = math.ceil((opts.last - opts.first + 1) / jobs)
	for job = 0, jobs - 1 do
		local first = opts.first + job * size
		local last = math.min(opts.last, first + size - 1)
		if first <= last then
			local command = string.format("%s tools/trailer/find_highlights.lua worker=1 seeds=%d-%d players=%d window=%d seconds=%d level=%s",
				interpreter, first, last, opts.players, opts.window, opts.seconds, opts.level)
			pipes[#pipes + 1] = assert(io.popen(command, "r"))
		end
	end
	local hits = {}
	for _, pipe in ipairs(pipes) do
		for line in pipe:lines() do
			local category, seed, kind, from, to, score = line:match("^(%S+)\t(%d+)\t(%S+)\t(%d+)\t(%d+)\t(%S+)$")
			assert(category, "a worker failed: " .. line)
			hits[#hits + 1] = { category = category, seed = tonumber(seed), kind = kind, from = tonumber(from), to = tonumber(to), score = tonumber(score) }
		end
		pipe:close()
	end
	return hits
end

local function main(argv)
	local opts = parse(argv)
	if opts.worker then
		printHits(scan(opts, opts.first, opts.last))
		return
	end
	local roster = Highlights.roster(opts.players, opts.level)
	local started = os.time()
	local hits = opts.jobs > 1 and scanParallel(opts) or scan(opts, opts.first, opts.last)
	local found = { ["brawl-blob"] = {}, ["brawl-snake"] = {} }
	for _, category in ipairs(Highlights.ORDER) do
		found[category] = {}
	end
	for _, hit in ipairs(hits) do
		for _, group in ipairs(groupsFor(hit.category, hit.kind)) do
			table.insert(found[group], hit)
		end
	end

	local groups = {}
	for _, category in ipairs(Highlights.ORDER) do
		groups[#groups + 1] = category
		if category == "brawl" then
			groups[#groups + 1] = "brawl-blob"
			groups[#groups + 1] = "brawl-snake"
		end
	end
	print(string.format("-- seeds %d-%d, %d players, window %d steps (%.1f s), %d s per match, %.0f s to run",
		opts.first, opts.last, opts.players, opts.window, opts.window / FPS, opts.seconds, os.time() - started))
	for _, group in ipairs(groups) do
		local list = found[group]
		table.sort(list, function(a, b)
			if a.score ~= b.score then
				return a.score > b.score
			end
			return a.seed < b.seed
		end)
		print(string.format("\n-- %s (one best window per seed)", group))
		for rank = 1, math.min(opts.count, #list) do
			local hit = list[rank]
			local name = string.format("%s_%d_%d", group:gsub("-", "_"), hit.seed, hit.from)
			local ok, text = Highlights.entry({ name = name, seed = hit.seed, roster = roster, hit = hit })
			assert(ok, text)
			print(string.format("-- #%d score %.1f, world %s, %d players, steps %d-%d", rank, hit.score, hit.kind, opts.players, hit.from + 1, hit.to))
			print(text .. ",")
		end
	end
end

local ok, err = pcall(main, arg)
if not ok then
	io.stderr:write(tostring(err), "\n")
	os.exit(1)
end
