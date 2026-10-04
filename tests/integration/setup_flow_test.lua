-- Roster setup through the real app flow (src/app/flow.lua) on the headless
-- love mock: Title -> Setup -> Match, by keyboard alone and by gamepad alone.
-- `love` is installed per test and restored afterwards.
local Flow = require("src.app.flow")
local LoveMock = require("tests.support.love_mock")
local PlayerColors = require("src.app.render.player_colors")
local Config = require("src.game.config")
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

test("keyboard alone: Play opens setup, a 3-player roster with seed and hardcore reaches the match", function()
	withLove(function()
		local flow = newFlow()
		flow:keypressed("return") -- Play
		assertEqual("setup", flow:topName())

		goTo(flow, "SLOT 3")
		flow:keypressed("right") -- empty -> ijkl (wasd and arrows are taken)
		flow:keypressed("right") -- -> AI easy (no pads connected)
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

test("every row is always shown and Start is blocked with a reason below two players", function()
	withLove(function()
		local flow = newFlow()
		flow:keypressed("return")
		local setup = flow.stack:top()
		for row = 1, 6 do
			assertEqual("SLOT " .. row, setup.items[row].label:sub(1, 6))
		end
		assertEqual("SLOT 3  EMPTY", setup.items[3].label)
		assertTrue(setup.items[3].dim, "an empty row is dimmed")
		assertFalse(setup.items[1].dim)
		assertTrue(setup.items[3].color ~= nil, "an empty row still shows its colour")

		goTo(flow, "SLOT 2")
		flow:keypressed("left") -- arrows -> wasd is taken -> empty
		assertEqual("SLOT 2  EMPTY", selectedLabel(flow))
		goTo(flow, "SLOT 1")
		for _ = 1, 10 do -- cycle slot 1's binding on to empty
			if selectedLabel(flow) == "SLOT 1  EMPTY" then
				break
			end
			flow:keypressed("right")
		end
		assertEqual("SLOT 1  EMPTY", selectedLabel(flow))
		goTo(flow, "START")
		flow:keypressed("return")
		assertEqual("setup", flow:topName(), "Start is blocked")
		assertEqual("NEED AT LEAST 2 PLAYERS", setup.notice)
	end)
end)

test("empty rows are dropped, players are numbered in row order and keep their row colours", function()
	withLove(function()
		local flow = newFlow()
		flow:keypressed("return")
		goTo(flow, "SLOT 4")
		flow:keypressed("left") -- empty -> AI hard
		goTo(flow, "SLOT 6")
		flow:keypressed("right") -- empty -> ijkl
		goTo(flow, "START")
		flow:keypressed("return")

		assertEqual("match", flow:topName())
		local ctx = flow:topCtx()
		local rows = { 1, 2, 4, 6 }
		assertEqual(4, #ctx.pools.ships)
		for player, row in ipairs(rows) do
			local ship = ctx.pools.ships[player]
			assertEqual(player, ship.player)
			assertEqual(Config.players.palette[row], PlayerColors.get(ctx, ship.player))
		end
		assertEqual("hard", ctx.roster[3].binding.level)
		assertEqual("ijkl", ctx.roster[4].binding.layout)
		assertEqual(6, #flow.settings.roster, "setup keeps all six rows")
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
