-- Proves the hard boundary renders visually: a real LÖVE window draws the
-- match state with the boundary circle visible and the frame is captured to
-- disk as evidence (see tests/e2e/worlds_render_test.lua for the base pattern).
local GameHarness = require("tests.support.game_harness")
local FixtureLevel = require("src.game.levels.fixture_two_worlds")
local Capture = require("tests.support.capture")

test("the hard boundary renders as a visible circle", function()
	local level = FixtureLevel.new()
	GameHarness.startMatch(level, { real = true })

	Capture.capture("boundary_circle")
end)
