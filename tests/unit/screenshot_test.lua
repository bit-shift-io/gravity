local Screenshot = require("src.app.screenshot")

local function newShot(stamps)
	local calls = {}
	local i = 0
	local shot = Screenshot.new({
		capture = function(path, done) calls[#calls + 1] = { path = path, done = done } end,
		stamp = function() i = i + 1; return stamps[math.min(i, #stamps)] end,
	})
	return shot, calls
end

test("a request captures after the draw, into screenshots/ with a timestamp", function()
	local shot, calls = newShot({ "20261006-142530" })
	shot:afterDraw()
	assertEqual(0, #calls)
	shot:request()
	assertEqual(0, #calls)
	shot:afterDraw()
	assertEqual(1, #calls)
	assertEqual("screenshots/gravity-20261006-142530.png", calls[1].path)
	shot:afterDraw()
	assertEqual(1, #calls)
end)

test("two shots in the same second get distinct filenames", function()
	local shot, calls = newShot({ "20261006-142530", "20261006-142530" })
	shot:request(); shot:afterDraw()
	shot:request(); shot:afterDraw()
	assertTrue(calls[1].path ~= calls[2].path)
end)

test("the toast shows once the save finishes, then fades out", function()
	local shot, calls = newShot({ "a" })
	assertEqual(nil, shot:toast())
	shot:request(); shot:afterDraw()
	assertEqual(nil, shot:toast())
	calls[1].done()
	local text, alpha = shot:toast()
	assertEqual("SCREENSHOT SAVED", text)
	assertEqual(1, alpha)
	shot:update(1.8)
	local _, fading = shot:toast()
	assertTrue(fading < 1 and fading > 0)
	shot:update(1)
	assertEqual(nil, shot:toast())
end)
