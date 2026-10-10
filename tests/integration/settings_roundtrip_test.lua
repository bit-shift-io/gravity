-- Roster persistence through the real flow and settings store on
-- the headless love mock. A relaunch is a second LoveMock sharing the first
-- one's in-memory save directory (`files`).
local Flow = require("src.app.flow")
local Roster = require("src.game.roster")
local SettingsStore = require("src.app.settings_store")
local LoveMock = require("tests.support.love_mock")
local FakeInputModule = require("tests.support.fake_input")

local function withLove(files, fn)
	local saved = _G.love
	_G.love = LoveMock.new(files)
	local ok, err = pcall(fn, FakeInputModule.FakeInput.new())
	_G.love = saved
	if not ok then
		error(err, 0)
	end
end

-- What main.lua does at launch.
local function launch(args)
	args = args or {}
	local saved = SettingsStore.load()
	return Flow.new({
		roster = saved.roster,
		sound = saved.sound,
		music = saved.music,
		postMode = saved.postMode,
		fullscreen = saved.fullscreen,
		seed = args.seed,
		onStart = SettingsStore.save,
		onSettingsChanged = SettingsStore.save,
	})
end

local function selectedLabel(flow)
	local top = flow.stack:top()
	return top.items[top.selected].label
end

local function goTo(flow, prefix)
	for _ = 1, 40 do
		if selectedLabel(flow):sub(1, #prefix) == prefix then
			return
		end
		flow:keypressed("down")
	end
	error("no setup row starting with " .. prefix)
end

test("the roster saved at match start are what setup shows after a relaunch", function()
	local files = {}
	withLove(files, function()
		local flow = launch()
		flow:keypressed("return") -- Play
		goTo(flow, "SLOT 3")
		flow:keypressed("right") -- empty -> ijkl
		flow:keypressed("right") -- -> AI easy
		flow:keypressed("return") -- colour 3 -> 4
		goTo(flow, "START")
		flow:keypressed("return")
		assertEqual("match", flow:topName())
	end)

	withLove(files, function()
		local flow = launch()
		flow:keypressed("return")
		local settings = flow.stack:top().settings
		assertEqual(6, #settings.roster)
		assertEqual("wasd", settings.roster[1].binding.layout)
		assertEqual("ai", settings.roster[3].binding.kind)
		assertEqual(4, settings.roster[3].color)
		assertEqual("none", settings.roster[4].binding.kind)
		assertEqual(3, settings.roster[4].color) -- swapped with row 3
		assertEqual(0, #Roster.validate(settings.roster, {}))
	end)
end)

test("the seed is never persisted", function()
	local files = {}
	withLove(files, function()
		local flow = launch({ seed = 31337 })
		flow:keypressed("return")
		goTo(flow, "START")
		flow:keypressed("return")
		assertEqual(31337, flow.stack:top().seed)
	end)
	for path, contents in pairs(files) do
		assertEqual(nil, contents:find("31337", 1, true), path .. " holds the seed")
		assertEqual(nil, contents:lower():find("seed", 1, true), path .. " mentions a seed")
	end
	withLove(files, function()
		assertEqual("", launch().settings.seedText)
	end)
end)

test("a saved gamepad that is missing at relaunch falls back and never blocks Start", function()
	local files = {}
	withLove(files, function(input)
		input:addJoystick("pad")
		local flow = launch()
		flow:keypressed("return")
		goTo(flow, "SLOT 2")
		flow:keypressed("right") -- arrows -> ijkl
		flow:keypressed("right") -- -> PAD 1
		goTo(flow, "START")
		flow:keypressed("return")
		assertEqual("match", flow:topName())
	end)

	withLove(files, function()
		local flow = launch()
		assertEqual("keyboard", flow.settings.roster[2].binding.kind)
		flow:keypressed("return") -- Play
		flow:keypressed("return") -- START
		assertEqual("match", flow:topName())
	end)
end)

test("a corrupt save file loads the defaults", function()
	local files = { ["settings.txt"] = "\0\1garbage{{{" }
	withLove(files, function()
		local flow = launch()
		assertEqual(6, #flow.settings.roster)
		assertEqual("none", flow.settings.roster[3].binding.kind)
	end)
end)

test("launch arguments win over saved values for that launch", function()
	local files = {}
	withLove(files, function()
		local flow = launch()
		flow:keypressed("return")
		goTo(flow, "START")
		flow:keypressed("return") -- saves the roster
	end)
	withLove(files, function()
		local flow = launch({ seed = 9 })
		assertEqual("9", flow.settings.seedText)
	end)
end)

test("SOUND turned off on the settings screen is still off after a relaunch", function()
	local files = {}
	withLove(files, function()
		local flow = launch()
		flow:keypressed("down") -- PLAY -> SETTINGS
		flow:keypressed("return")
		assertEqual("settings", flow:topName())
		flow:keypressed("return") -- SOUND off
	end)
	withLove(files, function()
		assertFalse(launch().settings.sound)
	end)
end)

test("a POST FX mode changed on the settings screen is restored after a relaunch", function()
	local files = {}
	withLove(files, function()
		local flow = launch()
		assertEqual("glowCrt", flow.settings.postMode)
		flow:keypressed("down") -- PLAY -> SETTINGS
		flow:keypressed("return")
		flow:keypressed("down") -- SOUND -> MUSIC
		flow:keypressed("down") -- -> POST FX
		flow:keypressed("return") -- glowCrt -> off
	end)
	withLove(files, function()
		assertEqual("off", launch().settings.postMode)
	end)
end)

test("MUSIC turned off on the settings screen is still off after a relaunch", function()
	local files = {}
	withLove(files, function()
		local flow = launch()
		assertTrue(flow.settings.music)
		flow:keypressed("down") -- PLAY -> SETTINGS
		flow:keypressed("return")
		flow:keypressed("down") -- SOUND -> MUSIC
		flow:keypressed("return") -- MUSIC off
	end)
	withLove(files, function()
		assertFalse(launch().settings.music)
	end)
end)
