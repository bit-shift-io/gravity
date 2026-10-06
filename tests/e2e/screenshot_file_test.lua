-- A screenshot request produces a real PNG in the save directory under real LÖVE.
local Compat = require("src.app.compat")
local Screenshot = require("src.app.screenshot")
local GameHarness = require("tests.support.game_harness")
local FrameStepper = require("tests.support.frame_stepper")

test("a requested screenshot lands as a PNG in screenshots/", function()
	local game = GameHarness.startMatch({ worlds = {} }, { real = true })
	local shot = Screenshot.new({ capture = Compat.captureScreenshot, stamp = function() return "e2e-test" end })
	local path = "screenshots/gravity-e2e-test.png"
	love.filesystem.remove(path)

	-- The runner's love.draw has no screenshot hook, so wrap it the way
	-- src/app/main.lua does; the capture lands once real frames are presented.
	local runnerDraw = love.draw
	love.draw = function()
		runnerDraw()
		shot:afterDraw()
	end
	shot:request()
	local deadline = love.timer.getTime() + 5
	while not love.filesystem.getInfo(path) and love.timer.getTime() < deadline do
		FrameStepper.step(game, 1)
	end
	love.draw = runnerDraw
	FrameStepper.step(game, 2)

	local info = love.filesystem.getInfo(path)
	assertTrue(info ~= nil and info.size > 0, "expected a non-empty PNG at " .. path)
	assertTrue(shot:toast() ~= nil, "expected the toast after the save")
	love.filesystem.remove(path)
end)
