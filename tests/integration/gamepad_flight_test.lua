-- Gamepads drive ships through the real app input path (src/app/input.lua ->
-- src/app/bindings.lua -> ctx.intents) using a fake joystick on the headless
-- love mock. `love` is installed per test and removed afterwards because the
-- rest of this tier runs with no `love` global.
local GameHarness = require("tests.support.game_harness")
local FrameStepper = require("tests.support.frame_stepper")
local LoveMock = require("tests.support.love_mock")
local FakeInputModule = require("tests.support.fake_input")
local Bodies = require("src.sim.bodies")
local Input = require("src.app.input")

local function withLove(fn)
	local saved = _G.love
	_G.love = LoveMock.new()
	local ok, err = pcall(fn, FakeInputModule.FakeInput.new())
	_G.love = saved
	if not ok then
		error(err, 0)
	end
end

-- Far-apart ships in empty space so only the pad under test matters.
local function level()
	return { worlds = {}, spawnPoints = { { x = 640, y = 360 }, { x = 640, y = -1000000 } } }
end

local function padRoster()
	return {
		{ color = 1, binding = { kind = "gamepad", id = 1 } },
		{ color = 2, binding = { kind = "gamepad", id = 2 } },
	}
end

test("a fake joystick flies its ship: A thrusts, stick rotates", function()
	withLove(function(input)
		local pad = input:addJoystick()
		input:addJoystick()
		local game = GameHarness.startMatch(level(), { roster = padRoster() })
		local ship = game.ctx.pools.ships[1]
		local body = Bodies.get(game.ctx.sim.bodies, ship.body)
		local startAngle = body.angle or 0

		pad:setAxis("leftx", 1)
		FrameStepper.step(game, 30)
		assertTrue((body.angle or 0) > startAngle, "expected the stick to rotate the ship")
		pad:setAxis("leftx", 0)

		local fuelBefore = ship.fuel.amount
		pad:press("a")
		FrameStepper.step(game, 30)
		assertTrue(ship.fuel.amount < fuelBefore, "expected A to thrust and burn fuel")
	end)
end)

test("two gamepads fly two ships independently", function()
	withLove(function(input)
		local padA, padB = input:addJoystick(), input:addJoystick()
		local game = GameHarness.startMatch(level(), { roster = padRoster() })
		FrameStepper.step(game, 1)
		padA:press("a")
		FrameStepper.step(game, 1)
		assertTrue(game.ctx.intents[1].thrust)
		assertFalse(game.ctx.intents[2].thrust)
		padA:release("a")
		padB:press("a")
		FrameStepper.step(game, 1)
		assertFalse(game.ctx.intents[1].thrust)
		assertTrue(game.ctx.intents[2].thrust)
	end)
end)

test("a held fire button charges and releasing it fires", function()
	withLove(function(input)
		local pad = input:addJoystick()
		input:addJoystick()
		local game = GameHarness.startMatch(level(), { roster = padRoster() })
		local ship = game.ctx.pools.ships[1]

		pad:press("x")
		FrameStepper.step(game, 20)
		assertTrue(ship.weapon.charging, "expected holding X to charge")
		assertEqual(0, #game.ctx.pools.projectiles)

		pad:release("x")
		FrameStepper.step(game, 2)
		assertEqual(1, #game.ctx.pools.projectiles, "expected releasing X to fire")
	end)
end)

test("removing the joystick mid-match gives a neutral intent and no error", function()
	withLove(function(input)
		local pad = input:addJoystick()
		input:addJoystick()
		local game = GameHarness.startMatch(level(), { roster = padRoster() })
		pad:press("a")
		FrameStepper.step(game, 5)
		assertTrue(game.ctx.intents[1].thrust)

		input:removeJoystick(pad)
		FrameStepper.step(game, 5)
		local intent = game.ctx.intents[1]
		assertEqual(0, intent.rotate)
		assertFalse(intent.thrust)
		assertFalse(intent.fire)
	end)
end)

test("keyboard layouts and AI slots coexist: AI intents are untouched", function()
	withLove(function(input)
		local roster = {
			{ color = 1, binding = { kind = "keyboard", layout = "wasd" } },
			{ color = 2, binding = { kind = "keyboard", layout = "arrows" } },
			{ color = 3, binding = { kind = "keyboard", layout = "ijkl" } },
			{ color = 4, binding = { kind = "ai", level = "easy" } },
		}
		local lvl = { worlds = {}, spawnPoints = {
			{ x = 640, y = 360 }, { x = 640, y = -1000000 }, { x = 640, y = 1000000 }, { x = -1000000, y = 0 },
		} }
		local game = GameHarness.startMatch(lvl, { roster = roster })
		game.ctx.intents[4] = { rotate = 1, thrust = true, fire = false }
		input:press("a")
		input:press("up")
		input:press("o")
		-- Match.step now runs AI.fill, which owns AI intents; check the input
		-- layer on its own so only Input.updateIntents is under test.
		Input.updateIntents(game.ctx, game.ctx.roster)
		assertEqual(-1, game.ctx.intents[1].rotate)
		assertTrue(game.ctx.intents[2].thrust)
		assertTrue(game.ctx.intents[3].fire)
		assertTrue(game.ctx.intents[4].thrust, "AI slot intent must be left alone")
	end)
end)
