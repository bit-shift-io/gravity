local Keyframes = require("tools.trailer.keyframes")

local pushIn = {
	{ t = 0, x = -100, y = 40, zoom = 0.5, ease = "linear" },
	{ t = 1, x = 300, y = -60, zoom = 2 },
}

test("Trailer Keyframes returns the key's own view at each key", function()
	local first = Keyframes.at(pushIn, 0)
	assertEqual(-100, first.x)
	assertEqual(40, first.y)
	assertNear(0.5, first.zoom, 1e-9)
	local last = Keyframes.at(pushIn, 1)
	assertEqual(300, last.x)
	assertEqual(-60, last.y)
	assertNear(2, last.zoom, 1e-9)
end)

test("Trailer Keyframes linear midpoint is halfway in x and y", function()
	local mid = Keyframes.at(pushIn, 0.5)
	assertNear(100, mid.x, 1e-9)
	assertNear(-10, mid.y, 1e-9)
end)

test("Trailer Keyframes holds the first key before it and the last key after it", function()
	local keys = {
		{ t = 0.2, x = 10, y = 20, zoom = 1 },
		{ t = 0.8, x = 70, y = 80, zoom = 1 },
	}
	assertEqual(10, Keyframes.at(keys, 0).x)
	assertEqual(70, Keyframes.at(keys, 1).x)
end)

test("Trailer Keyframes picks the segment t falls in across three keys", function()
	local keys = {
		{ t = 0, x = 0, y = 0, zoom = 1, ease = "linear" },
		{ t = 0.5, x = 100, y = 0, zoom = 1, ease = "linear" },
		{ t = 1, x = 100, y = 200, zoom = 1 },
	}
	assertNear(50, Keyframes.at(keys, 0.25).x, 1e-9)
	assertNear(100, Keyframes.at(keys, 0.75).x, 1e-9)
	assertNear(100, Keyframes.at(keys, 0.75).y, 1e-9)
end)

test("Trailer Keyframes zoom interpolates in log space", function()
	assertNear(1, Keyframes.at(pushIn, 0.5).zoom, 1e-9)
end)

local function xAtQuarter(ease)
	local keys = {
		{ t = 0, x = 0, y = 0, zoom = 1, ease = ease },
		{ t = 1, x = 100, y = 0, zoom = 1 },
	}
	return Keyframes.at(keys, 0.25).x
end

test("Trailer Keyframes ease 'in' starts slow", function()
	assertNear(6.25, xAtQuarter("in"), 1e-9)
end)

test("Trailer Keyframes ease 'out' starts fast", function()
	assertNear(43.75, xAtQuarter("out"), 1e-9)
end)

test("Trailer Keyframes ease 'inOut' is a smoothstep, and the default", function()
	assertNear(15.625, xAtQuarter("inOut"), 1e-9)
	assertNear(15.625, xAtQuarter(nil), 1e-9)
end)

test("Trailer Keyframes ease belongs to the segment that starts at its key", function()
	local keys = {
		{ t = 0, x = 0, y = 0, zoom = 1, ease = "linear" },
		{ t = 0.5, x = 100, y = 0, zoom = 1, ease = "in" },
		{ t = 1, x = 200, y = 0, zoom = 1, ease = "out" },
	}
	assertNear(50, Keyframes.at(keys, 0.25).x, 1e-9)
	assertNear(106.25, Keyframes.at(keys, 0.625).x, 1e-9)
end)

local ManifestCheck = require("tools.trailer.manifest_check")

local function checkCamera(camera)
	local shot = {
		name = "push",
		seed = 4242,
		roster = {
			{ color = 1, binding = { kind = "ai", level = "hard" } },
			{ color = 2, binding = { kind = "ai", level = "hard" } },
		},
		from = 0,
		to = 240,
		camera = camera,
	}
	return ManifestCheck.validate({ shots = { shot } })
end

test("Trailer ManifestCheck accepts a two-key camera", function()
	local ok, err = checkCamera(pushIn)
	assertTrue(ok, tostring(err))
end)

test("Trailer ManifestCheck rejects unsorted keyframe t", function()
	local ok, err = checkCamera({
		{ t = 0.5, x = 0, y = 0, zoom = 1 },
		{ t = 0.2, x = 0, y = 0, zoom = 2 },
	})
	assertFalse(ok)
	assertEqual("push: camera key 2 t must be greater than the previous key's", err)
end)

test("Trailer ManifestCheck rejects keyframe t outside 0..1", function()
	local ok, err = checkCamera({
		{ t = 0, x = 0, y = 0, zoom = 1 },
		{ t = 1.5, x = 0, y = 0, zoom = 2 },
	})
	assertFalse(ok)
	assertEqual("push: camera key 2 t must be between 0 and 1", err)
end)

test("Trailer ManifestCheck rejects an unknown ease", function()
	local ok, err = checkCamera({
		{ t = 0, x = 0, y = 0, zoom = 1, ease = "bounce" },
		{ t = 1, x = 0, y = 0, zoom = 2 },
	})
	assertFalse(ok)
	assertEqual("push: camera key 1 ease must be linear, in, out or inOut", err)
end)

test("Trailer ManifestCheck rejects a keyframe with zoom of zero or less", function()
	local ok, err = checkCamera({
		{ t = 0, x = 0, y = 0, zoom = 0 },
		{ t = 1, x = 0, y = 0, zoom = 2 },
	})
	assertFalse(ok)
	assertEqual("push: camera key 1 needs numeric x, y and a positive zoom", err)
end)

local ShotRunner = require("tools.trailer.shot_runner")

local function runShot(camera, from, to, speed)
	local shot = {
		seed = 4242,
		roster = {
			{ color = 1, binding = { kind = "ai", level = "hard" } },
			{ color = 2, binding = { kind = "ai", level = "hard" } },
		},
		from = from,
		to = to,
		speed = speed,
		camera = camera,
	}
	local views = {}
	ShotRunner.run(shot, function(view)
		views[#views + 1] = { x = view.camera.x, y = view.camera.y, zoom = view.camera.zoom }
	end)
	return views
end

test("Trailer ShotRunner keyframes run from t=0 on the first frame to t=1 on the last", function()
	local views = runShot(pushIn, 0, 5)
	assertEqual(5, #views)
	assertEqual(-100, views[1].x)
	assertNear(0.5, views[1].zoom, 1e-9)
	assertEqual(300, views[5].x)
	assertNear(2, views[5].zoom, 1e-9)
	assertNear(100, views[3].x, 1e-9)
end)
