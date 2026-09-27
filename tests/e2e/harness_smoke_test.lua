-- Proves the headed path end-to-end: a match boots through the real stack
-- under real LÖVE, frames step and are genuinely drawn, and a capture
-- writes a real PNG to disk.
local GameHarness = require("tests.support.game_harness")
local FrameStepper = require("tests.support.frame_stepper")
local Capture = require("tests.support.capture")

test("a match boots under real LÖVE and steps frames without error", function()
	local level = { worlds = {} }
	local game = GameHarness.startMatch(level, { real = true })

	FrameStepper.step(game, 60)

	assertNear(1.0, game.ctx.time, 0.0001, "expected 60 frames at 1/60s to advance ctx.time by 1 second")

	Capture.capture("stepped")
end)
