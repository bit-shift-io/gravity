-- LÖVE callbacks: virtual-resolution letterboxing and the fixed-timestep
-- accumulator. This is the only module `main.lua` requires; every other
-- app-layer module hangs off it. No sim/game/core module may require
-- anything from here (see docs/ARCHITECTURE.md "Layers").
local Screen = require("src.app.screen")
local Config = require("src.game.config")
local MatchState = require("src.app.states.match_state")
local LevelGen = require("src.game.level_gen")
local RoundSystem = require("src.game.systems.round_system")
local PostMode = require("src.app.post.post_mode")
local Pipeline = require("src.app.post.pipeline")

-- Fixed timestep of 1/60 s (docs/ARCHITECTURE.md "Rules"): the simulation
-- must be deterministic for a given seed and input sequence, which a
-- variable dt cannot guarantee.
local FIXED_DT = 1 / 60

local App = {}

App.ctx = nil
App.accumulator = 0
App.seed = nil
App.postMode = Config.post.defaultMode

-- Rematch (and dev reset on R): rebuild the match from a fresh level with the original seed, so
-- a reset reproduces the initial state exactly.
function App.reset()
	-- Both ships start as tanks on the farthest-apart pair of surface points.
	local level = LevelGen.generate(App.seed, Config)
	App.ctx = MatchState.enter(level, Config, App.seed)
	App.accumulator = 0
end


local function findArg(args, arg)
	for _, a in ipairs(args or {}) do
		local path = a:match(arg)
		if path then
			return path
		end
	end
	return nil
end

-- e2e=<path/to/scenario_test.lua>, mirroring fido-and-kitch's launch-argument
-- style. Detected here so love.load can hand control to the e2e runner
-- instead of constructing the normal App (see tests/e2e/run.lua).
local function findE2ETestFile(args)
	local path = findArg(args, "^e2e=(.+)$")
	return path

	-- for _, a in ipairs(args or {}) do
	-- 	local path = a:match("^e2e=(.+)$")
	-- 	if path then
	-- 		return path
	-- 	end
	-- end
	-- return nil
end

function love.load(args)
	-- if findArg(args, "debug") then
	-- 	local ok, debugger = pcall(require, "lldebugger")
	-- 	if ok then
	-- 		debugger.start()
	-- 	else
	-- 		print("✗ lldebugger not found; continuing without debugger")
	-- 	end
	-- end

	local e2eTestFile = findE2ETestFile(args)
	if e2eTestFile then
		-- requiring tests.e2e.run defines its own love.update/love.draw/
		-- love.quit, replacing the ones below for the rest of this process.
		local E2ERunner = require("tests.e2e.run")
		E2ERunner.start(e2eTestFile, args)
		return
	end

	love.graphics.setBackgroundColor(0, 0, 0)

	-- No menu yet (slice 12) -- match_state is the only state, so it's
	-- entered directly rather than showing a title screen first. seed=N
	-- fixes the generated level; otherwise the clock picks one, logged so a
	-- good layout can be replayed.
	App.seed = tonumber(findArg(args, "^seed=(.+)$")) or os.time()
	print("seed=" .. App.seed)
	App.reset()
end

function love.keypressed(key)
	if key == "r" and App.ctx then
		App.reset()
	elseif (key == "return" or key == "kpenter" or key == "space") and App.ctx and RoundSystem.matchOver(App.ctx.round) then
		App.reset()
	elseif key == "p" then
		App.postMode = PostMode.next(App.postMode)
	end
end

function love.update(dt)
	App.accumulator = App.accumulator + dt

	while App.accumulator >= FIXED_DT do
		MatchState.update(App.ctx, FIXED_DT)
		App.accumulator = App.accumulator - FIXED_DT
	end
end

function love.draw()
	local windowWidth, windowHeight = love.graphics.getDimensions()
	local fit = Screen.fit(windowWidth, windowHeight)

	-- Bars stay plain black: clear the window, then the pipeline draws the
	-- game rectangle only.
	love.graphics.clear(0, 0, 0, 1)
	Pipeline.draw(fit, App.postMode, function()
		MatchState.draw(App.ctx)
	end)
end

return App
