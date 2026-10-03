-- Roster setup through the real app flow (src/app/flow.lua) on the headless
-- love mock: Title -> Setup -> Match, by keyboard alone and by gamepad alone.
-- `love` is installed per test and restored afterwards.
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
	return Flow.new({})
end

local function selectedLabel(flow)
	local top = flow.stack:top()
	return top.items[top.selected].label
end

-- Presses `down` until the selected row's label starts with `prefix`.
local function goTo(flow, prefix)
	for _ = 1, 40 do
		if selectedLabel(flow):sub(1, #prefix) == prefix then
			return
		end
		flow:keypressed("down")
	end
	error("no setup row starting with " .. prefix)
end

local function type_(flow, text)
	for digit in text:gmatch(".") do
		flow:textinput(digit)
	end
end

test("keyboard alone: Play opens setup, a 3-slot roster with seed and hardcore reaches the match", function()
	withLove(function()
		local flow = newFlow()
		flow:keypressed("return") -- Play
		assertEqual("setup", flow:topName())

		goTo(flow, "ADD SLOT")
		flow:keypressed("return")
		goTo(flow, "SLOT 3")
		flow:keypressed("right") -- ijkl -> AI easy (no pads connected)
		flow:keypressed("return") -- colour 3 -> 4

		goTo(flow, "SEED")
		type_(flow, "4242")
		goTo(flow, "HARDCORE")
		flow:keypressed("return")
		goTo(flow, "START")
		flow:keypressed("return")

		assertEqual("match", flow:topName())
		local ctx = flow:topCtx()
		assertEqual(3, #ctx.roster)
		assertEqual("wasd", ctx.roster[1].binding.layout)
		assertEqual("arrows", ctx.roster[2].binding.layout)
		assertEqual("ai", ctx.roster[3].binding.kind)
		assertEqual("easy", ctx.roster[3].binding.level)
		assertEqual(4, ctx.roster[3].color)
		assertEqual(4242, flow.stack:top().seed)
		assertTrue(ctx.hardcore)
	end)
end)

local function padDownTo(flow, pad, prefix)
	for _ = 1, 40 do
		if selectedLabel(flow):sub(1, #prefix) == prefix then
			return
		end
		flow:gamepadpressed(pad, "dpdown")
	end
	error("no setup row starting with " .. prefix)
end

test("gamepad alone: randomise changes the seed field but a pad cannot edit its digits", function()
	withLove(function(input)
		local pad = input:addJoystick("pad")
		local flow = newFlow()
		flow:gamepadpressed(pad, "a") -- Play
		assertEqual("setup", flow:topName())
		local setup = flow.stack:top()
		assertEqual("", setup.settings.seedText)

		padDownTo(flow, pad, "SEED")
		flow:gamepadpressed(pad, "dpright")
		flow:gamepadpressed(pad, "a")
		flow:textinput("") -- a pad produces no text
		assertEqual("", setup.settings.seedText)

		padDownTo(flow, pad, "RANDOMISE")
		flow:gamepadpressed(pad, "a")
		local randomised = setup.settings.seedText
		assertTrue(randomised:match("^%d+$") ~= nil, "randomised seed is digits")
		assertTrue(#randomised <= 15, "stays a safe integer")

		padDownTo(flow, pad, "START")
		flow:gamepadpressed(pad, "a")
		assertEqual("match", flow:topName())
		assertEqual(tonumber(randomised), flow.stack:top().seed)
	end)
end)

test("a bound gamepad that disconnects in setup is flagged and blocks Start", function()
	withLove(function(input)
		local pad = input:addJoystick("pad")
		local flow = newFlow()
		flow:keypressed("return")
		goTo(flow, "SLOT 2")
		flow:keypressed("right") -- arrows -> ijkl
		flow:keypressed("right") -- -> PAD 1
		assertEqual("PAD 1", selectedLabel(flow):match("PAD %d"))

		input:removeJoystick(pad)
		flow:joystickremoved(pad)
		local setup = flow.stack:top()
		assertTrue(setup.items[2].flag, "slot 2 is flagged")

		goTo(flow, "START")
		flow:keypressed("return")
		assertEqual("setup", flow:topName(), "Start is blocked")
		assertEqual("SLOT 2: GAMEPAD 1 DISCONNECTED", setup.notice)

		input:addJoystick("pad again")
		flow:joystickadded(nil)
		assertFalse(setup.items[2].flag)
		flow:keypressed("return")
		assertEqual("match", flow:topName())
	end)
end)

test("limits show a visible reason instead of silently doing nothing", function()
	withLove(function()
		local flow = newFlow()
		flow:keypressed("return")
		local setup = flow.stack:top()
		goTo(flow, "ADD SLOT")
		for _ = 1, 4 do
			flow:keypressed("return")
		end
		assertEqual(6, #setup.settings.roster)
		assertEqual(nil, setup.notice)
		flow:keypressed("return")
		assertEqual("MAX 6 SLOTS", setup.notice)

		goTo(flow, "REMOVE SLOT")
		for _ = 1, 4 do
			flow:keypressed("return")
		end
		flow:keypressed("return")
		assertEqual(2, #setup.settings.roster)
		assertEqual("NEED AT LEAST 2 SLOTS", setup.notice)
	end)
end)

test("seed digits are capped so the seed stays a safe integer", function()
	withLove(function()
		local flow = newFlow()
		flow:keypressed("return")
		goTo(flow, "SEED")
		type_(flow, "12345678901234567890")
		local setup = flow.stack:top()
		assertEqual("123456789012345", setup.settings.seedText)
		assertEqual("SEED MAX 15 DIGITS", setup.notice)
		flow:textinput("x")
		flow:keypressed("backspace")
		assertEqual("12345678901234", setup.settings.seedText)
	end)
end)

test("rematch keeps roster, seed and hardcore; setup re-reads them on the next start", function()
	withLove(function()
		local flow = newFlow()
		flow:keypressed("return")
		goTo(flow, "SEED")
		type_(flow, "77")
		goTo(flow, "HARDCORE")
		flow:keypressed("return")
		goTo(flow, "SLOT 2")
		flow:keypressed("right") -- ijkl
		goTo(flow, "START")
		flow:keypressed("return")
		local first = flow:topCtx()

		flow:keypressed("r") -- rematch
		local again = flow:topCtx()
		assertTrue(again ~= first)
		assertEqual(77, flow.stack:top().seed)
		assertTrue(again.hardcore)
		assertEqual("ijkl", again.roster[2].binding.layout)

		-- Quit to title, reopen setup: the same values show, and edits reach the next match.
		flow:keypressed("escape")
		flow:keypressed("down")
		flow:keypressed("return")
		flow:keypressed("return") -- Play -> setup
		local setup = flow.stack:top()
		assertEqual("77", setup.settings.seedText)
		goTo(flow, "HARDCORE")
		flow:keypressed("return")
		goTo(flow, "START")
		flow:keypressed("return")
		assertFalse(flow:topCtx().hardcore)
		assertEqual("ijkl", flow:topCtx().roster[2].binding.layout)
	end)
end)

test("editing the setup after Start does not change a running match's roster", function()
	withLove(function()
		local flow = newFlow()
		flow:keypressed("return")
		flow:keypressed("return") -- START
		local roster = flow:topCtx().roster
		flow.settings.roster[1].color = 5
		assertEqual(1, roster[1].color)
	end)
end)

test("the settings-changed hook fires after each setup edit", function()
	withLove(function()
		local seen = 0
		local flow = Flow.new({ onSettingsChanged = function(settings) seen = seen + 1; assertTrue(settings.roster ~= nil) end })
		flow:keypressed("return")
		goTo(flow, "HARDCORE")
		flow:keypressed("return")
		assertEqual(1, seen)
	end)
end)
