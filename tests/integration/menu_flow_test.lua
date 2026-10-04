-- Menu flow through the real app state stack (src/app/flow.lua) on the
-- headless love mock: title -> match -> pause -> resume -> pause -> quit to
-- title, by keyboard alone and by gamepad alone. `love` is installed per test
-- and restored afterwards (the rest of this tier has no `love` global).
local Flow = require("src.app.flow")
local LoveMock = require("tests.support.love_mock")
local FakeInputModule = require("tests.support.fake_input")

local function withLove(fn)
	local saved = _G.love
	_G.love = LoveMock.new()
	local ok, err = pcall(fn, FakeInputModule.FakeInput.new())
	_G.love = saved
	if not ok then
		error(err, 0)
	end
end

local function newFlow()
	local flow = Flow.new({ seed = 12345 })
	flow.quitCalls = 0
	flow.onQuit = function() flow.quitCalls = flow.quitCalls + 1 end
	return flow
end

-- Play opens the roster setup, which has START selected: a second confirm launches.
local function startMatch(flow, pad)
	if pad then
		flow:gamepadpressed(pad, "a")
		flow:gamepadpressed(pad, "a")
	else
		flow:keypressed("return")
		flow:keypressed("return")
	end
end

local function step(flow, frames)
	for _ = 1, frames or 1 do
		flow:update(1 / 60)
	end
end

test("keyboard alone: title -> match -> pause -> resume -> pause -> quit to title", function()
	withLove(function()
		local flow = newFlow()
		assertEqual("title", flow:topName())

		flow:keypressed("return") -- Play is the first item
		assertEqual("setup", flow:topName())
		flow:keypressed("return") -- START is preselected
		assertEqual("match", flow:topName())
		assertEqual(2, #flow:topCtx().roster)

		flow:keypressed("escape")
		assertEqual("pause", flow:topName())

		flow:keypressed("return") -- Resume is the first item
		assertEqual("match", flow:topName())

		flow:keypressed("escape")
		flow:keypressed("down")
		flow:keypressed("down")
		flow:keypressed("return") -- Quit to menu
		assertEqual("title", flow:topName())
		assertEqual(1, #flow.stack.states, "match must be discarded")
	end)
end)

test("gamepad alone: any connected pad drives title, pause, resume and quit", function()
	withLove(function(input)
		local padA, padB = input:addJoystick("pad A"), input:addJoystick("pad B")
		local flow = newFlow()

		flow:gamepadpressed(padB, "a") -- the second pad confirms Play
		assertEqual("setup", flow:topName())
		flow:gamepadpressed(padA, "a") -- and any pad confirms Start
		assertEqual("match", flow:topName())

		flow:gamepadpressed(padA, "start")
		assertEqual("pause", flow:topName())
		flow:gamepadpressed(padB, "a") -- Resume
		assertEqual("match", flow:topName())

		flow:gamepadpressed(padB, "start")
		flow:gamepadpressed(padA, "dpdown")
		flow:gamepadpressed(padA, "dpdown")
		flow:gamepadpressed(padA, "a") -- Quit to menu
		assertEqual("title", flow:topName())
	end)
end)

test("left stick navigates menus and B backs out of pause", function()
	withLove(function(input)
		local pad = input:addJoystick()
		local flow = newFlow()
		flow:gamepadaxis(pad, "lefty", 0.9) -- down: Quit is selected
		flow:gamepadaxis(pad, "lefty", 0)
		flow:gamepadaxis(pad, "lefty", -0.9) -- up: Play again
		startMatch(flow, pad)
		assertEqual("match", flow:topName())

		flow:keypressed("escape")
		flow:gamepadpressed(pad, "b")
		assertEqual("match", flow:topName())
	end)
end)

test("Quit on the title asks the app to quit", function()
	withLove(function()
		local flow = newFlow()
		flow:keypressed("down")
		flow:keypressed("down") -- past Settings
		flow:keypressed("return")
		assertEqual(1, flow.quitCalls)
	end)
end)

test("sim time does not advance while paused and resumes afterwards", function()
	withLove(function()
		local flow = newFlow()
		startMatch(flow)
		step(flow, 30)
		local ctx = flow:topCtx()
		local before = ctx.time
		assertTrue(before > 0, "match should be running")

		flow:keypressed("escape")
		step(flow, 120)
		assertEqual(before, ctx.time, "time advanced while paused")

		startMatch(flow)
		step(flow, 30)
		assertNear(before + 30 / 60, flow:topCtx().time, 1e-9)
		assertTrue(flow:topCtx() == ctx, "resume keeps the same match")
	end)
end)

test("quit to menu discards the match; Play starts a fresh one", function()
	withLove(function()
		local flow = newFlow()
		startMatch(flow)
		step(flow, 30)
		local first = flow:topCtx()
		flow:keypressed("escape")
		flow:keypressed("down")
		flow:keypressed("down")
		flow:keypressed("return")
		assertEqual(nil, flow:topCtx())

		startMatch(flow)
		assertTrue(flow:topCtx() ~= first)
		assertEqual(0, flow:topCtx().time)
	end)
end)

test("R rebuilds the match with the same seed", function()
	withLove(function()
		local flow = newFlow()
		startMatch(flow)
		step(flow, 10)
		local first = flow:topCtx()
		local firstSeed = flow.stack:top().seed
		flow:keypressed("r")
		assertTrue(flow:topCtx() ~= first)
		assertEqual(0, flow:topCtx().time)
		assertEqual(12345, firstSeed)
		assertEqual(firstSeed, flow.stack:top().seed)
	end)
end)

test("P in a match leaves the post mode unchanged", function()
	withLove(function()
		local flow = newFlow()
		startMatch(flow)
		local mode = flow.settings.postMode
		flow:keypressed("p")
		assertEqual(mode, flow.settings.postMode)
	end)
end)

test("match-over rematch still works by Enter and by pad A", function()
	withLove(function(input)
		local pad = input:addJoystick()
		local flow = newFlow()
		startMatch(flow)

		local function endMatch()
			local round = flow:topCtx().round
			round.winner = 1
			round.phase = "matchOver"
		end
		local RoundSystem = require("src.game.systems.round_system")
		endMatch()
		if not RoundSystem.matchOver(flow:topCtx().round) then
			error("test setup: could not mark the match over")
		end
		local first = flow:topCtx()
		local firstSeed = flow.stack:top().seed
		flow:keypressed("return")
		assertTrue(flow:topCtx() ~= first)
		assertTrue(flow.stack:top().seed ~= firstSeed, "rematch should roll a new seed")
		assertFalse(RoundSystem.matchOver(flow:topCtx().round))

		endMatch()
		first = flow:topCtx()
		flow:gamepadpressed(pad, "a")
		assertTrue(flow:topCtx() ~= first)
	end)
end)

local Audio = require("src.app.audio")

local function openSettings(flow)
	flow:keypressed("down") -- Settings sits between Play and Quit
	flow:keypressed("return")
end

test("title -> SETTINGS -> toggling SOUND flips the setting and reports the change", function()
	withLove(function()
		local changes = 0
		local flow = Flow.new({ seed = 12345, onSettingsChanged = function() changes = changes + 1 end })
		assertTrue(flow.settings.sound)
		openSettings(flow)
		assertEqual("settings", flow:topName())

		flow:keypressed("return") -- SOUND is the first row
		assertFalse(flow.settings.sound)
		assertEqual(1, changes)
		flow:keypressed("right")
		assertTrue(flow.settings.sound)
		flow:keypressed("left")
		assertFalse(flow.settings.sound)
		assertEqual(3, changes)
		Audio.setEnabled(true)
	end)
end)

test("the sound setting seeds from opts, defaulting on", function()
	withLove(function()
		assertFalse(Flow.new({ sound = false }).settings.sound)
		assertTrue(Flow.new({}).settings.sound)
	end)
end)

test("Back from settings returns to the title, by Esc and by pad B", function()
	withLove(function(input)
		local pad = input:addJoystick()
		local flow = newFlow()
		openSettings(flow)
		flow:keypressed("escape")
		assertEqual("title", flow:topName())

		openSettings(flow)
		flow:gamepadpressed(pad, "b")
		assertEqual("title", flow:topName())

		openSettings(flow)
		flow:keypressed("down") -- BACK row
		flow:keypressed("return")
		assertEqual("title", flow:topName())
	end)
end)

test("the POST FX row cycles off, glow, glow+CRT and wraps, saving each change", function()
	withLove(function()
		local changes = 0
		local flow = Flow.new({ seed = 12345, postMode = "off", onSettingsChanged = function() changes = changes + 1 end })
		openSettings(flow)
		flow:keypressed("down") -- SOUND -> POST FX
		local top = flow.stack:top()
		assertEqual("POST FX  OFF", top.items[top.selected].label)
		flow:keypressed("return")
		assertEqual("glow", flow.settings.postMode)
		assertEqual("POST FX  GLOW", top.items[top.selected].label)
		flow:keypressed("right")
		assertEqual("glowCrt", flow.settings.postMode)
		assertEqual("POST FX  GLOW+CRT", top.items[top.selected].label)
		flow:keypressed("left")
		assertEqual("off", flow.settings.postMode)
		assertEqual(3, changes)
	end)
end)

test("the FULLSCREEN row toggles through the window hook, saving each change", function()
	withLove(function()
		local changes, calls = 0, {}
		local flow = Flow.new({
			seed = 12345,
			setFullscreen = function(on) calls[#calls + 1] = on end,
			onSettingsChanged = function() changes = changes + 1 end,
		})
		openSettings(flow)
		flow:keypressed("down") -- SOUND -> POST FX
		flow:keypressed("down") -- -> FULLSCREEN
		local top = flow.stack:top()
		assertEqual("FULLSCREEN  OFF", top.items[top.selected].label)
		flow:keypressed("return")
		assertTrue(flow.settings.fullscreen)
		assertEqual("FULLSCREEN  ON", top.items[top.selected].label)
		flow:keypressed("left")
		assertFalse(flow.settings.fullscreen)
		assertEqual(2, changes)
		assertEqual(2, #calls)
		assertTrue(calls[1])
		assertFalse(calls[2])
	end)
end)

test("without a window hook the FULLSCREEN row only flips the setting", function()
	withLove(function()
		local flow = Flow.new({ seed = 12345 })
		openSettings(flow)
		flow:keypressed("down")
		flow:keypressed("down")
		flow:keypressed("return")
		assertTrue(flow.settings.fullscreen)
	end)
end)

test("opening settings shows the real window state, not the saved value", function()
	withLove(function()
		local windowIsFullscreen = false
		local flow = Flow.new({
			seed = 12345,
			fullscreen = true,
			isFullscreen = function() return windowIsFullscreen end,
		})
		openSettings(flow)
		local top = flow.stack:top()
		assertEqual("FULLSCREEN  OFF", top.items[3].label)
		assertFalse(flow.settings.fullscreen)
	end)
end)

test("pause -> SETTINGS -> change a setting -> Back -> pause menu", function()
	withLove(function()
		local changes = 0
		local flow = Flow.new({
			seed = 12345,
			onSettingsChanged = function() changes = changes + 1 end,
		})
		startMatch(flow)
		flow:keypressed("escape") -- open pause
		assertEqual("pause", flow:topName())

		flow:keypressed("down") -- select SETTINGS (next item after RESUME)
		flow:keypressed("return") -- confirm SETTINGS
		assertEqual("settings", flow:topName())

		flow:keypressed("return") -- toggle SOUND
		assertFalse(flow.settings.sound)
		assertEqual(1, changes)

		flow:keypressed("escape") -- Back via Esc
		assertEqual("pause", flow:topName())

		-- match is still frozen and the setting persists
		assertFalse(flow.settings.sound)
	end)
end)

test("gamepad Start inside settings over pause does not unpause", function()
	withLove(function(input)
		local pad = input:addJoystick()
		local flow = newFlow()
		startMatch(flow, pad)
		flow:gamepadpressed(pad, "start") -- open pause
		assertEqual("pause", flow:topName())

		flow:gamepadpressed(pad, "dpdown") -- select SETTINGS
		flow:gamepadpressed(pad, "a") -- confirm SETTINGS
		assertEqual("settings", flow:topName())

		flow:gamepadpressed(pad, "start") -- Start should NOT close settings or unpause
		assertEqual("settings", flow:topName())

		flow:gamepadpressed(pad, "b") -- Back via B
		assertEqual("pause", flow:topName())
	end)
end)
