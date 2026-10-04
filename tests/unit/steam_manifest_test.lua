local ManifestCheck = require("tools.steam_assets.manifest_check")
local Manifest = require("tools.steam_assets.manifest")
local Scene = require("tools.steam_assets.scene")

local function entry(overrides)
	local e = {
		name = "screenshot_01",
		width = 1920,
		height = 1080,
		seed = 4242,
		step = 600,
		roster = {
			{ color = 1, binding = { kind = "ai", level = "hard" } },
			{ color = 2, binding = { kind = "ai", level = "hard" } },
			{ color = 3, binding = { kind = "ai", level = "easy" } },
		},
	}
	for k, v in pairs(overrides or {}) do
		e[k] = v
	end
	return e
end

test("ManifestCheck accepts a complete entry", function()
	local ok, err = ManifestCheck.validate({ entry() })
	assertTrue(ok, tostring(err))
end)

test("ManifestCheck names the entry that is missing a field", function()
	local ok, err = ManifestCheck.validate({ entry(), entry({ name = "hero", seed = false }) })
	assertFalse(ok)
	assertEqual("hero: missing field 'seed'", err)
end)

test("ManifestCheck rejects a non-positive or fractional size by name", function()
	local ok, err = ManifestCheck.validate({ entry({ width = 0 }) })
	assertFalse(ok)
	assertEqual("screenshot_01: width must be a positive integer", err)
	ok, err = ManifestCheck.validate({ entry({ height = 1080.5 }) })
	assertFalse(ok)
	assertEqual("screenshot_01: height must be a positive integer", err)
end)

test("ManifestCheck rejects a duplicate name", function()
	local ok, err = ManifestCheck.validate({ entry(), entry() })
	assertFalse(ok)
	assertEqual("screenshot_01: duplicate name", err)
end)

test("ManifestCheck rejects a roster with fewer than two slots", function()
	local ok, err = ManifestCheck.validate({ entry({ roster = { { color = 1, binding = { kind = "ai", level = "easy" } } } }) })
	assertFalse(ok)
	assertEqual("screenshot_01: roster needs at least 2 slots", err)
end)

test("ManifestCheck rejects a negative step", function()
	local ok, err = ManifestCheck.validate({ entry({ step = -1 }) })
	assertFalse(ok)
	assertEqual("screenshot_01: step must be a non-negative integer", err)
end)

test("ManifestCheck rejects a camera with a non-positive zoom", function()
	local ok, err = ManifestCheck.validate({ entry({ camera = { x = 0, y = 0, zoom = 0 } }) })
	assertFalse(ok)
	assertEqual("screenshot_01: camera needs numeric x, y and a positive zoom", err)
end)

test("ManifestCheck reports an unnamed entry by position", function()
	local ok, err = ManifestCheck.validate({ entry({ name = false }) })
	assertFalse(ok)
	assertEqual("entry #1: missing field 'name'", err)
end)

test("the shipped manifest passes validation", function()
	local ok, err = ManifestCheck.validate(Manifest)
	assertTrue(ok, tostring(err))
end)

local function shipPositions(ctx)
	local Bodies = require("src.sim.bodies")
	local out = {}
	for _, ship in ipairs(ctx.pools.ships) do
		local body = Bodies.get(ctx.sim.bodies, ship.body)
		out[#out + 1] = string.format("%.9f,%.9f", body.x, body.y)
	end
	return table.concat(out, ";") .. string.format("|%.9f|%.9f", ctx.time, ctx.camera.zoom)
end

test("Scene.build runs exactly entry.step steps", function()
	local ctx = Scene.build(entry({ step = 120 }))
	assertNear(120 / 60, ctx.time, 1e-9)
end)

test("Scene.build gives the same match for the same entry", function()
	local a = Scene.build(entry())
	local b = Scene.build(entry())
	assertEqual(shipPositions(a), shipPositions(b))
end)

test("Scene.build differs when the seed differs", function()
	local a = Scene.build(entry())
	local b = Scene.build(entry({ seed = 4243 }))
	assertTrue(shipPositions(a) ~= shipPositions(b))
end)

test("Scene.build applies a camera override", function()
	local ctx = Scene.build(entry({ step = 10, camera = { x = 50, y = -20, zoom = 1.5 } }))
	assertEqual(50, ctx.camera.x)
	assertEqual(-20, ctx.camera.y)
	assertEqual(1.5, ctx.camera.zoom)
end)

local Flags = require("tools.steam_assets.flags")
local GlowMath = require("src.app.post.glow_math")
local Framing = require("tools.steam_assets.framing")

test("Flags inherit the saved post mode and show the HUD when the entry omits them", function()
	local f = Flags.resolve(entry(), "glowCrt")
	assertTrue(f.hud)
	assertTrue(f.glow)
	assertTrue(f.crt)
	f = Flags.resolve(entry(), "glow")
	assertTrue(f.glow)
	assertFalse(f.crt)
	f = Flags.resolve(entry(), "off")
	assertFalse(f.glow)
	assertFalse(f.crt)
end)

test("Flags let an entry override the saved look either way", function()
	local f = Flags.resolve(entry({ hud = false, glow = false, crt = true }), "glow")
	assertFalse(f.hud)
	assertFalse(f.glow)
	assertTrue(f.crt)
end)

test("ManifestCheck rejects a non-boolean flag by entry name", function()
	local ok, err = ManifestCheck.validate({ entry({ crt = "yes" }) })
	assertFalse(ok)
	assertEqual("screenshot_01: crt must be true or false", err)
	ok, err = ManifestCheck.validate({ entry({ hud = false, glow = true, crt = false }) })
	assertTrue(ok, tostring(err))
end)

test("Glow tap spacing at 1920x1080 is 1.5x the in-game 1280x720 spacing", function()
	local radius = 14
	local base = GlowMath.tapSpacing(radius, Framing.transform(1280, 720, { zoom = 1 }).uiScale)
	local big = GlowMath.tapSpacing(radius, Framing.transform(1920, 1080, { zoom = 1 }).uiScale)
	assertNear(base * 1.5, big, 1e-9)
end)

local function byName(name)
	for _, e in ipairs(Manifest) do
		if e.name == name then
			return e
		end
	end
end

local STEAM_SIZES = {
	capsule_header = { 920, 430 },
	capsule_small = { 462, 174 },
	capsule_main = { 1232, 706 },
	capsule_vertical = { 748, 896 },
	library_capsule = { 600, 900 },
	library_header = { 920, 430 },
	library_hero = { 3840, 1240 },
	screenshot_01 = { 1920, 1080 },
	screenshot_02 = { 1920, 1080 },
	screenshot_03 = { 1920, 1080 },
	screenshot_04 = { 1920, 1080 },
	screenshot_05 = { 1920, 1080 },
}

test("the manifest has every Steam store and library asset at its Steamworks size", function()
	for name, size in pairs(STEAM_SIZES) do
		local e = byName(name)
		assertTrue(e ~= nil, name .. " is missing")
		assertEqual(size[1], e.width, name .. " width")
		assertEqual(size[2], e.height, name .. " height")
	end
end)

test("the library hero has no overlay and the capsules carry the logo", function()
	assertEqual(nil, byName("library_hero").overlay)
	for _, name in ipairs({ "capsule_header", "capsule_small", "capsule_main", "capsule_vertical", "library_capsule", "library_header" }) do
		assertEqual("logo", byName(name).overlay, name)
	end
end)

test("every non-logo entry sets glow and crt explicitly", function()
	for _, e in ipairs(Manifest) do
		assertTrue(type(e.glow) == "boolean", e.name .. " glow")
		assertTrue(type(e.crt) == "boolean", e.name .. " crt")
	end
end)

test("every manifest entry has a unique seed/step/camera so images differ", function()
	local seen = {}
	for _, e in ipairs(Manifest) do
		if not e.transparent then
			local cam = e.camera and (e.camera.x .. "," .. e.camera.y .. "," .. e.camera.zoom) or "-"
			local key = table.concat({ e.seed, e.step, cam, e.width, e.height }, "|")
			assertTrue(not seen[key], e.name .. " duplicates another entry")
			seen[key] = true
		end
	end
end)
