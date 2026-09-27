-- Proves the harness end-to-end: GameHarness boots a match from a literal
-- level table (never a file path -- see docs/memory/test-framework-from-fido-and-kitch.md),
-- and stepping it at the fixed timestep advances ctx.time deterministically.
local GameHarness = require("tests.support.game_harness")
local FrameStepper = require("tests.support.frame_stepper")

test("startMatch boots a match from a literal level table and steps frames without error", function()
	local level = { worlds = {} }
	local game = GameHarness.startMatch(level)

	FrameStepper.step(game, 60)

	assertNear(1.0, game.ctx.time, 0.0001, "expected 60 frames at 1/60s to advance ctx.time by 1 second")
end)
