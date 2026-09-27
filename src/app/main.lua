-- LÖVE callbacks: virtual-resolution letterboxing and the fixed-timestep
-- accumulator. This is the only module `main.lua` requires; every other
-- app-layer module hangs off it. No sim/game/core module may require
-- anything from here (see docs/ARCHITECTURE.md "Layers").
local Screen = require("src.app.screen")
local Config = require("src.game.config")
local MatchState = require("src.app.states.match_state")
local FixtureLevel = require("src.game.levels.fixture_two_worlds")

-- Fixed timestep of 1/60 s (docs/ARCHITECTURE.md "Rules"): the simulation
-- must be deterministic for a given seed and input sequence, which a
-- variable dt cannot guarantee.
local FIXED_DT = 1 / 60

local App = {}

App.ctx = nil
App.accumulator = 0

-- e2e=<path/to/scenario_test.lua>, mirroring fido-and-kitch's launch-argument
-- style. Detected here so love.load can hand control to the e2e runner
-- instead of constructing the normal App (see tests/e2e/run.lua).
local function findE2ETestFile(args)
	for _, a in ipairs(args or {}) do
		local path = a:match("^e2e=(.+)$")
		if path then
			return path
		end
	end
	return nil
end

function love.load(args)
	local e2eTestFile = findE2ETestFile(args)
	if e2eTestFile then
		-- requiring tests.e2e.run defines its own love.update/love.draw/
		-- love.quit, replacing the ones below for the rest of this process.
		local E2ERunner = require("tests.e2e.run")
		E2ERunner.start(e2eTestFile, args)
		return
	end

	love.graphics.setBackgroundColor(0, 0, 0)

	-- Fixture level until level generation lands (slice 11). No menu yet
	-- (slice 12) -- match_state is the only state, so it's entered directly
	-- rather than showing a title screen first.
	App.ctx = MatchState.enter(FixtureLevel.new(), Config)
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

	love.graphics.push()
	love.graphics.translate(fit.offsetX, fit.offsetY)
	love.graphics.scale(fit.scale, fit.scale)

	MatchState.draw(App.ctx)

	love.graphics.pop()
end

return App
