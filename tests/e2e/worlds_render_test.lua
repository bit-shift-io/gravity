-- Proves the fixture level's two worlds actually render: a real LÖVE window
-- draws the match state and the frame is captured to disk as evidence
-- (see tests/e2e/harness_smoke_test.lua for the base pattern).
local GameHarness = require("tests.support.game_harness")
local FixtureLevel = require("src.game.levels.fixture_two_worlds")
local Capture = require("tests.support.capture")

test("the fixture level's two worlds render as outlines", function()
	local level = FixtureLevel.new()
	GameHarness.startMatch(level, { real = true })

	Capture.capture("fixture_two_worlds")
end)
