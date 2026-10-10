local ShotFormat = require("tools.trailer.shot_format")
local ManifestCheck = require("tools.trailer.manifest_check")

local roster = {
	{ color = 1, binding = { kind = "ai", level = "hard" } },
	{ color = 2, binding = { kind = "ai", level = "easy" } },
}

local function mark(step, view, sim)
	return { step = step, view = view or false, sim = sim or { x = 5, y = -6, zoom = 0.75 } }
end

local function loaded(text)
	local chunk = assert(load("return " .. text))
	return chunk()
end

test("Trailer ShotFormat prints an entry that loads, passes the manifest check and has the marked range", function()
	local ok, text = ShotFormat.entry({ seed = 4242, roster = roster, markIn = mark(121), markOut = mark(300) })
	assertTrue(ok, tostring(text))
	local shot = loaded(text)
	assertEqual(4242, shot.seed)
	assertEqual(2, #shot.roster)
	assertEqual("easy", shot.roster[2].binding.level)
	-- Frame k shows the state after step from + k, so from = in - 1 makes the first frame show the marked step.
	assertEqual(120, shot.from)
	assertEqual(300, shot.to)
	assertEqual(nil, shot.camera)
	local valid, err = ManifestCheck.validate({ shots = { shot } })
	assertTrue(valid, tostring(err))
end)

test("Trailer ShotFormat clamps from to 0 when marking in at step 0", function()
	local ok, text = ShotFormat.entry({ seed = 1, roster = roster, markIn = mark(0), markOut = mark(60) })
	assertTrue(ok, tostring(text))
	assertEqual(0, loaded(text).from)
end)

test("Trailer ShotFormat refuses out before in with a message and prints nothing", function()
	local ok, message = ShotFormat.entry({ seed = 1, roster = roster, markIn = mark(300), markOut = mark(120) })
	assertEqual(false, ok)
	assertTrue(message:find("out", 1, true) ~= nil, message)
end)

test("Trailer ShotFormat refuses a missing mark and an empty range", function()
	local ok, message = ShotFormat.entry({ seed = 1, roster = roster, markOut = mark(120) })
	assertEqual(false, ok)
	assertTrue(message:find("in", 1, true) ~= nil, message)
	ok, message = ShotFormat.entry({ seed = 1, roster = roster, markIn = mark(0), markOut = mark(0) })
	assertEqual(false, ok)
end)

test("Trailer ShotFormat writes a two-key camera from the marked views", function()
	local ok, text = ShotFormat.entry({
		seed = 1,
		roster = roster,
		markIn = mark(10, { x = 1.5, y = 2, zoom = 0.5 }),
		markOut = mark(70, { x = -30, y = 40.25, zoom = 1.2 }),
	})
	assertTrue(ok, tostring(text))
	local shot = loaded(text)
	assertEqual(2, #shot.camera)
	assertEqual(0, shot.camera[1].t)
	assertEqual(1.5, shot.camera[1].x)
	assertNear(0.5, shot.camera[1].zoom, 1e-9)
	assertEqual(1, shot.camera[2].t)
	assertEqual(-30, shot.camera[2].x)
	assertEqual(40.25, shot.camera[2].y)
	local valid, err = ManifestCheck.validate({ shots = { shot } })
	assertTrue(valid, tostring(err))
end)

test("Trailer ShotFormat uses the sim camera at the mark when only one mark has a view", function()
	local ok, text = ShotFormat.entry({
		seed = 1,
		roster = roster,
		markIn = mark(10, nil, { x = 7, y = 8, zoom = 0.9 }),
		markOut = mark(70, { x = -30, y = 40, zoom = 1.2 }),
	})
	assertTrue(ok, tostring(text))
	local shot = loaded(text)
	assertEqual(7, shot.camera[1].x)
	assertNear(0.9, shot.camera[1].zoom, 1e-9)
	assertEqual(-30, shot.camera[2].x)
end)

test("Trailer ShotFormat entry renders from the step scout showed to the marked out step", function()
	local ShotRunner = require("tools.trailer.shot_runner")
	local ok, text = ShotFormat.entry({ seed = 4242, roster = roster, markIn = mark(5), markOut = mark(9) })
	assertTrue(ok, tostring(text))
	local steps = {}
	ShotRunner.run(loaded(text), function(_, step)
		steps[#steps + 1] = step
	end)
	assertEqual(5, steps[1])
	assertEqual(9, steps[#steps])
end)
