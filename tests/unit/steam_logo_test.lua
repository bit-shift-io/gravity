local Logo = require("tools.steam_assets.logo")
local Menu = require("src.app.render.menu")
local ManifestCheck = require("tools.steam_assets.manifest_check")

test("Menu.titleParts splits GRAV//TY into white text and two coloured slashes", function()
	local red, blue = { 1, 0, 0 }, { 0, 0, 1 }
	local parts = Menu.titleParts("GRAV//TY", { red, blue })
	assertEqual(4, #parts)
	assertEqual("GRAV", parts[1][1])
	assertEqual(nil, parts[1][2])
	assertEqual("/", parts[2][1])
	assertEqual(red, parts[2][2])
	assertEqual("/", parts[3][1])
	assertEqual(blue, parts[3][2])
	assertEqual("TY", parts[4][1])
end)

test("Menu.titleParts keeps a title without slashes as one white part", function()
	local parts = Menu.titleParts("MATCH OVER", { { 1, 0, 0 }, { 0, 0, 1 } })
	assertEqual(1, #parts)
	assertEqual("MATCH OVER", parts[1][1])
	assertEqual(nil, parts[1][2])
end)

test("Logo.fontSize scales the reference font to the wanted width", function()
	-- 72px font measures 400 wide; 1000 wide wants a 180px font.
	assertEqual(180, Logo.fontSize(1000, 72, 400))
end)

test("Logo.place centres the logo for the centre anchor", function()
	local x, y = Logo.place(1280, 720, "centre", 400, 100)
	assertEqual(440, x)
	assertEqual(310, y)
end)

test("Logo.place keeps a margin from the corner for a corner anchor", function()
	local x, y = Logo.place(1000, 500, "top-left", 200, 50)
	assertEqual(Logo.margin(1000, 500), x)
	assertEqual(Logo.margin(1000, 500), y)
	x, y = Logo.place(1000, 500, "bottom-right", 200, 50)
	assertEqual(1000 - 200 - Logo.margin(1000, 500), x)
	assertEqual(500 - 50 - Logo.margin(1000, 500), y)
end)

test("Logo.place supports edge-centred anchors", function()
	local x, y = Logo.place(1000, 500, "top", 200, 50)
	assertEqual(400, x)
	assertEqual(Logo.margin(1000, 500), y)
end)

test("Logo.stack puts the subtitle centred one gap below the title", function()
	local box = Logo.stack(400, 100, 200, 40)
	assertEqual(400, box.width)
	assertEqual(0, box.titleX)
	assertEqual(100, box.subtitleX)
	assertEqual(110, box.subtitleY)
	assertEqual(150, box.height)
end)

test("Logo.stack widens the box and centres the title when the subtitle is wider", function()
	local box = Logo.stack(200, 100, 400, 40)
	assertEqual(400, box.width)
	assertEqual(100, box.titleX)
	assertEqual(0, box.subtitleX)
end)

local function entry(overrides)
	local e = {
		name = "capsule",
		width = 1920,
		height = 1080,
		seed = 4242,
		step = 600,
		roster = {
			{ color = 1, binding = { kind = "ai", level = "hard" } },
			{ color = 2, binding = { kind = "ai", level = "hard" } },
		},
	}
	for k, v in pairs(overrides or {}) do
		e[k] = v
	end
	return e
end

test("ManifestCheck accepts a logo overlay with anchor and size", function()
	local ok, err = ManifestCheck.validate({ entry({ overlay = "logo", logoAnchor = "bottom", logoSize = 0.5 }) })
	assertTrue(ok, tostring(err))
end)

test("ManifestCheck rejects an unknown overlay by name", function()
	local ok, err = ManifestCheck.validate({ entry({ overlay = "banner", logoAnchor = "top", logoSize = 0.5 }) })
	assertFalse(ok)
	assertEqual("capsule: overlay must be \"logo\"", err)
end)

test("ManifestCheck rejects a logo overlay with a bad anchor or size", function()
	local ok, err = ManifestCheck.validate({ entry({ overlay = "logo", logoAnchor = "middle", logoSize = 0.5 }) })
	assertFalse(ok)
	assertEqual("capsule: logoAnchor 'middle' is not a known anchor", err)
	ok, err = ManifestCheck.validate({ entry({ overlay = "logo", logoAnchor = "top", logoSize = 1.5 }) })
	assertFalse(ok)
	assertEqual("capsule: logoSize must be above 0 and at most 1", err)
end)

test("ManifestCheck rejects a transparent entry larger than the logo limit", function()
	local ok, err = ManifestCheck.validate({
		entry({ transparent = true, overlay = "logo", logoAnchor = "centre", logoSize = 0.9, width = 1920 }),
	})
	assertFalse(ok)
	assertEqual("capsule: transparent logo must fit 1280x720", err)
end)

test("ManifestCheck requires a transparent entry to be the logo overlay", function()
	local ok, err = ManifestCheck.validate({ entry({ transparent = true, width = 1280, height = 720 }) })
	assertFalse(ok)
	assertEqual("capsule: transparent needs overlay = \"logo\"", err)
end)
