-- The whole loop with a gamepad and nothing else: title -> setup -> match ->
-- match-over rematch -> match-over back to setup -> title -> settings -> back.
-- No keypressed / textinput call anywhere in this file.
local Flow = require("src.app.flow")
local LoveMock = require("tests.support.love_mock")
local FakeInputModule = require("tests.support.fake_input")
local Bindings = require("src.app.bindings")

local function withLove(fn)
	local saved = _G.love
	_G.love = LoveMock.new()
	local ok, err = pcall(fn, FakeInputModule.FakeInput.new())
	_G.love = saved
	if not ok then
		error(err, 0)
	end
end

local function step(flow, frames)
	for _ = 1, frames do
		flow:update(1 / 60)
	end
end

local function endMatch(flow)
	local round = flow:topCtx().round
	round.winner = 1
	round.phase = "matchOver"
end

local function assertPadOneFlies(flow, pad)
	local binding = flow:topCtx().roster[1].binding
	assertEqual("gamepad", binding.kind)
	assertEqual(1, binding.id)
	pad:press(Bindings.GAMEPAD.thrust)
	pad:press(Bindings.GAMEPAD.fire)
	pad:setAxis(Bindings.GAMEPAD.axis, 1)
	step(flow, 2)
	local intent = flow:topCtx().intents[1]
	assertTrue(intent.thrust, "pad thrust reaches the ship intent")
	assertTrue(intent.fire, "pad fire reaches the ship intent")
	assertEqual(1, intent.rotate)
	pad:release(Bindings.GAMEPAD.thrust)
	pad:release(Bindings.GAMEPAD.fire)
	pad:setAxis(Bindings.GAMEPAD.axis, 0)
	step(flow, 2)
	local idle = flow:topCtx().intents[1]
	assertFalse(idle.thrust)
	assertFalse(idle.fire)
end

test("pad alone plays the whole loop: setup, match, rematch, setup, title, settings, back", function()
	withLove(function(input)
		local pad = input:addJoystick("pad")
		local flow = Flow.new({ seed = 12345 })

		assertEqual("title", flow:topName())
		flow:gamepadpressed(pad, "a") -- Play
		assertEqual("setup", flow:topName())
		flow:gamepadpressed(pad, "a") -- START is preselected
		assertEqual("match", flow:topName())
		assertPadOneFlies(flow, pad)

		local first = flow:topCtx()
		endMatch(flow)
		flow:gamepadpressed(pad, "a") -- rematch
		assertEqual("match", flow:topName())
		assertTrue(flow:topCtx() ~= first, "rematch builds a new match")
		assertPadOneFlies(flow, pad)

		endMatch(flow)
		flow:gamepadpressed(pad, "b") -- back to setup
		assertEqual("setup", flow:topName())
		assertEqual("gamepad", flow.settings.roster[1].binding.kind)

		flow:gamepadpressed(pad, "b") -- back to title
		assertEqual("title", flow:topName())

		flow:gamepadpressed(pad, "dpdown") -- Settings
		flow:gamepadpressed(pad, "a")
		assertEqual("settings", flow:topName())
		local sound = flow.settings.sound
		flow:gamepadpressed(pad, "a") -- SOUND toggles
		assertEqual(not sound, flow.settings.sound)
		flow:gamepadpressed(pad, "b")
		assertEqual("title", flow:topName())
		flow.settings.sound = sound
		require("src.app.audio").setEnabled(sound)
	end)
end)
