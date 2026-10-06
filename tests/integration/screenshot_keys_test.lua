-- `p` asks for a screenshot in a match and on the pause menu, and nowhere
-- else (title, setup, settings).
local Flow = require("src.app.flow")
local LoveMock = require("tests.support.love_mock")

local function withLove(fn)
	local saved = _G.love
	_G.love = LoveMock.new()
	local ok, err = pcall(fn)
	_G.love = saved
	if not ok then
		error(err, 0)
	end
end

local function newFlow()
	local flow = Flow.new({ seed = 12345 })
	flow.requests = 0
	flow.onScreenshot = function() flow.requests = flow.requests + 1 end
	return flow
end

test("p does nothing on title, setup and settings", function()
	withLove(function()
		local flow = newFlow()
		flow:keypressed("p")
		flow:keypressed("return")
		assertEqual("setup", flow:topName())
		flow:keypressed("p")
		flow:openSettings()
		assertEqual("settings", flow:topName())
		flow:keypressed("p")
		assertEqual(0, flow.requests)
	end)
end)

test("p requests a screenshot in a match and on the pause menu", function()
	withLove(function()
		local flow = newFlow()
		flow:keypressed("return")
		flow:keypressed("return")
		assertEqual("match", flow:topName())
		flow:keypressed("p")
		assertEqual(1, flow.requests)
		flow:keypressed("escape")
		assertEqual("pause", flow:topName())
		flow:keypressed("p")
		assertEqual(2, flow.requests)
		assertEqual("pause", flow:topName())
	end)
end)
