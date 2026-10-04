-- LÖVE callbacks: virtual-resolution letterboxing and the fixed-timestep
-- accumulator. This is the only module `main.lua` requires; every other
-- app-layer module hangs off it. No sim/game/core module may require
-- anything from here (see docs/ARCHITECTURE.md "Layers").
local Screen = require("src.app.screen")
local Flow = require("src.app.flow")
local Pipeline = require("src.app.post.pipeline")
local Compat = require("src.app.compat")
local SettingsStore = require("src.app.settings_store")
local Audio = require("src.app.audio")

-- Fixed timestep of 1/60 s (docs/ARCHITECTURE.md "Rules"): the simulation
-- must be deterministic for a given seed and input sequence, which a
-- variable dt cannot guarantee.
local FIXED_DT = 1 / 60

local App = {}

-- The flow (src/app/flow.lua) owns the state stack: title, match, pause.
App.flow = nil
App.accumulator = 0
App.lastTop = nil

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
	-- Setup's randomise action draws from math.random.
	math.randomseed(os.time())
	Compat.loadGamepadMappings("res/gamecontrollerdb.txt")

	-- seed=N fixes the generated level for every Play; otherwise each Play
	-- picks a fresh seed, logged so a good layout can be replayed.
	-- hardcore=1 makes rotating burn fuel.
	-- The last roster and hardcore setting reload here and save when a match
	-- starts; the seed is never saved. The launch args win for this launch.
	local saved = SettingsStore.load()
	App.flow = Flow.new({
		seed = tonumber(findArg(args, "^seed=(.+)$")),
		hardcore = findArg(args, "^hardcore=(.+)$") == "1" or saved.hardcore,
		roster = saved.roster,
		sound = saved.sound,
		postMode = saved.postMode,
		fullscreen = saved.fullscreen,
		setFullscreen = Compat.setFullscreen,
		isFullscreen = Compat.isFullscreen,
		onStart = SettingsStore.save,
		onSettingsChanged = SettingsStore.save,
		quit = love.event.quit,
		intro = true,
	})
	Audio.setEnabled(App.flow.settings.sound)
	Compat.setFullscreen(App.flow.settings.fullscreen)
end

-- Every input callback goes through the state stack; the match state keeps the
-- R/P dev keys and rematch, Esc / gamepad Start pause.
function love.keypressed(key)
	App.flow:keypressed(key)
end

function love.gamepadpressed(joystick, button)
	App.flow:gamepadpressed(joystick, button)
end

function love.gamepadaxis(joystick, axis, value)
	App.flow:gamepadaxis(joystick, axis, value)
end

function love.textinput(text)
	App.flow:textinput(text)
end

-- Pads are polled by ordinal every frame (src/app/input.lua), so hot-plugging
-- needs no bookkeeping in a match; the setup screen re-validates its gamepad
-- bindings on these events. They are logged too.
function love.joystickadded(joystick)
	print("joystick added: " .. tostring(joystick:getName()))
	App.flow:joystickadded(joystick)
end

function love.joystickremoved(joystick)
	print("joystick removed: " .. tostring(joystick:getName()))
	App.flow:joystickremoved(joystick)
end

function love.update(dt)
	-- Pausing, resuming or changing screen drops the leftover time, so a state
	-- change never bursts catch-up steps.
	local top = App.flow.stack:top()
	if top ~= App.lastTop then
		App.lastTop = top
		App.accumulator = 0
	end

	App.accumulator = App.accumulator + dt

	while App.accumulator >= FIXED_DT do
		App.flow:update(FIXED_DT)
		App.accumulator = App.accumulator - FIXED_DT
	end
end

function love.draw()
	local windowWidth, windowHeight = love.graphics.getDimensions()
	local fit = Screen.fit(windowWidth, windowHeight)

	-- Bars stay plain black: clear the window, then the pipeline draws the
	-- game rectangle only.
	love.graphics.clear(0, 0, 0, 1)
	Pipeline.draw(fit, App.flow.settings.postMode, function()
		App.flow:draw()
	end)
end

return App
