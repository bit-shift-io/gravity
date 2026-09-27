-- Proves the "1" debug overlay toggle actually works end-to-end: pressing 1
-- flips ctx.debug.showField under real LÖVE input, and the resulting frame
-- (with the baked field's arrows drawn) is captured to disk as evidence.
local GameHarness = require("tests.support.game_harness")
local FixtureLevel = require("src.game.levels.fixture_two_worlds")
local Capture = require("tests.support.capture")
local FakeInput = require("tests.support.fake_input").FakeInput
local FrameStepper = require("tests.support.frame_stepper")

test("1 toggles the field overlay on and the frame captures with it visible", function()
	local level = FixtureLevel.new()
	local game = GameHarness.startMatch(level, { real = true })

	Capture.capture("field_overlay_1_off")
	assertFalse(game.ctx.debug.showField, "expected the overlay to start off")

	local controller = FakeInput.new()
	controller:press("1")
	FrameStepper.step(game, 1)
	controller:release("1")

	assertTrue(game.ctx.debug.showField, "expected 1 to toggle the field overlay on")

	Capture.capture("field_overlay_1_on")
end)

test("a second 1 press toggles the field overlay back off", function()
	local level = FixtureLevel.new()
	local game = GameHarness.startMatch(level, { real = true })

	local controller = FakeInput.new()
	controller:press("1")
	FrameStepper.step(game, 1)
	controller:release("1")
	FrameStepper.step(game, 1)

	assertTrue(game.ctx.debug.showField, "expected the first press to turn the overlay on")

	controller:press("1")
	FrameStepper.step(game, 1)
	controller:release("1")

	assertFalse(game.ctx.debug.showField, "expected the second press to turn the overlay back off")
end)
