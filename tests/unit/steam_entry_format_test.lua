local EntryFormat = require("tools.steam_assets.entry_format")
local ManifestCheck = require("tools.steam_assets.manifest_check")
local Scene = require("tools.steam_assets.scene")

local function ai(color, level)
	return { color = color, binding = { kind = "ai", level = level } }
end

local function frame(overrides)
	local f = {
		seed = 4242,
		step = 1830,
		roster = { ai(1, "hard"), ai(2, "hard"), ai(3, "easy"), ai(4, "easy") },
		camera = { x = -408.25, y = 60.5, zoom = 0.8123456789 },
	}
	for k, v in pairs(overrides or {}) do
		f[k] = v
	end
	return f
end

local function parse(text)
	local chunk, err = load("return " .. text)
	assertTrue(chunk ~= nil, tostring(err))
	return chunk()
end

test("EntryFormat output loads back as a table with the frame's seed, step and roster", function()
	local e = parse(EntryFormat.entry(frame()))
	assertEqual(4242, e.seed)
	assertEqual(1830, e.step)
	assertEqual(4, #e.roster)
	assertEqual(3, e.roster[3].color)
	assertEqual("easy", e.roster[3].binding.level)
end)

test("EntryFormat output passes manifest validation", function()
	local ok, err = ManifestCheck.validate({ parse(EntryFormat.entry(frame())) })
	assertTrue(ok, tostring(err))
end)

test("EntryFormat keeps the camera to a few decimals", function()
	local e = parse(EntryFormat.entry(frame()))
	assertNear(-408.25, e.camera.x, 1e-9)
	assertNear(60.5, e.camera.y, 1e-9)
	assertNear(0.8123, e.camera.zoom, 1e-9)
end)

test("EntryFormat omits the camera when the view is the sim camera", function()
	local e = parse(EntryFormat.entry(frame({ camera = false })))
	assertEqual(nil, e.camera)
end)

test("a printed entry rebuilds the frame it describes", function()
	local e = parse(EntryFormat.entry(frame({ step = 90 })))
	local ctx = Scene.build(e)
	assertNear(90 / 60, ctx.time, 1e-9)
	assertNear(-408.25, ctx.camera.x, 1e-9)
end)
