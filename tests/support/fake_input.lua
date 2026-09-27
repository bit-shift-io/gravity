-- Drives a fake keyboard/joystick state the way a human would: press/release
-- keys. Built on top of the *current* global `love` (the integration tier's
-- love_mock, or real LÖVE under the e2e tier) so construct a FakeInput only
-- after GameHarness.startMatch() has run under a `love` global.
--
-- No input mapping exists yet (that's a later slice) -- this only shims
-- love.keyboard.isDown; extend it (per-player joystick assignment, etc.)
-- once src/app wires ctx.intents from real input.
local FrameStepper = require("tests.support.frame_stepper")

local FakeInput = {}
FakeInput.__index = FakeInput

function FakeInput.new()
	local state = love._state or { keysDown = {}, joysticks = {} }
	love._state = state

	love.keyboard.isDown = function(key)
		return state.keysDown[key] == true
	end

	return setmetatable({ state = state }, FakeInput)
end

function FakeInput:press(key)
	self.state.keysDown[key] = true
end

function FakeInput:release(key)
	self.state.keysDown[key] = nil
end

-- press, step frames at a fixed 1/60s for `seconds`, then release.
local function holdFor(game, controller, key, seconds)
	controller:press(key)
	FrameStepper.step(game, FrameStepper.secondsToFrames(seconds))
	controller:release(key)
end

-- steps frames until predicate() is true, or fails the test if maxFrames is
-- exhausted without it becoming true.
local function runUntil(game, predicate, maxFrames)
	for _ = 1, maxFrames do
		FrameStepper.step(game, 1)
		if predicate() then
			return
		end
	end
	error(string.format("runUntil: predicate not satisfied within %d frames", maxFrames))
end

return {
	FakeInput = FakeInput,
	holdFor = holdFor,
	runUntil = runUntil,
}
