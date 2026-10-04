local Monogram = require("tools.steam_assets.monogram")
local ManifestCheck = require("tools.steam_assets.manifest_check")

-- Fake font metrics: text width is 5.5 px per font px (not linear in general,
-- so the fit must use the measured width, not a reference guess).
local function measure(fontSize)
	return fontSize * 5.5 + 3
end

test("Monogram.fitSize keeps measured text within 80% of the square", function()
	for _, size in ipairs({ 32, 184, 256 }) do
		local fs = Monogram.fitSize(size, measure)
		assertTrue(measure(fs) <= size * 0.8, "too wide at " .. size)
		-- and is the largest size that fits
		assertTrue(measure(fs + 1) > size * 0.8, "not maximal at " .. size)
	end
end)

test("Monogram.fitSize applies glyphScale", function()
	local full = Monogram.fitSize(184, measure)
	local half = Monogram.fitSize(184, measure, 0.5)
	assertTrue(measure(half) <= 184 * 0.8 * 0.5)
	assertTrue(half < full)
end)

test("Monogram.fitSize never returns below 1", function()
	assertEqual(1, Monogram.fitSize(1, measure))
end)

test("Monogram.centre centres the glyph box with equal margins", function()
	local x, y = Monogram.centre(184, 100, 60)
	assertEqual(42, x)
	assertEqual(62, y)
	-- ink offset inside the box (left bearing 4, top 10) is compensated
	x, y = Monogram.centre(184, 100, 60, 4, 10)
	assertEqual(38, x)
	assertEqual(52, y)
end)

test("Monogram.centre leaves at least 10% margin when box fits in 80%", function()
	local size = 184
	local x, y = Monogram.centre(size, size * 0.8, size * 0.4)
	assertTrue(x >= size * 0.1 - 1e-9)
	assertTrue(size - (x + size * 0.8) >= size * 0.1 - 1e-9)
	assertTrue(y >= size * 0.1)
end)

local function iconEntry(overrides)
	local e = {
		name = "test_icon",
		width = 184,
		height = 184,
		seed = 4242,
		step = 0,
		roster = {
			{ color = 1, binding = { kind = "ai", level = "hard" } },
			{ color = 2, binding = { kind = "ai", level = "hard" } },
		},
		icon = true,
	}
	for k, v in pairs(overrides or {}) do
		e[k] = v
	end
	return e
end

test("ManifestCheck accepts an icon entry", function()
	local ok, err = ManifestCheck.validate({ iconEntry() })
	assertTrue(ok, tostring(err))
end)

test("ManifestCheck rejects a non-square icon", function()
	local ok, err = ManifestCheck.validate({ iconEntry({ width = 200, height = 184 }) })
	assertFalse(ok)
	assertEqual("test_icon: icon must be a square", err)
end)

test("ManifestCheck rejects an icon with an overlay", function()
	local ok, err = ManifestCheck.validate({ iconEntry({ overlay = "logo", logoAnchor = "centre", logoSize = 0.5 }) })
	assertFalse(ok)
	assertEqual("test_icon: icon cannot have an overlay", err)
end)

test("ManifestCheck accepts an icon with glyphScale", function()
	local ok, err = ManifestCheck.validate({ iconEntry({ glyphScale = 0.5 }) })
	assertTrue(ok, tostring(err))
end)

test("ManifestCheck rejects glyphScale on non-icon entries", function()
	local e = {
		name = "test_non_icon",
		width = 1920,
		height = 1080,
		seed = 4242,
		step = 600,
		roster = {
			{ color = 1, binding = { kind = "ai", level = "hard" } },
			{ color = 2, binding = { kind = "ai", level = "hard" } },
		},
		glyphScale = 0.5,
	}
	local ok, err = ManifestCheck.validate({ e })
	assertFalse(ok)
	assertEqual("test_non_icon: glyphScale only applies to icons", err)
end)

test("ManifestCheck rejects invalid glyphScale values", function()
	local ok, err = ManifestCheck.validate({ iconEntry({ glyphScale = 0 }) })
	assertFalse(ok)
	assertEqual("test_icon: glyphScale must be a number above 0 and at most 1", err)

	ok, err = ManifestCheck.validate({ iconEntry({ glyphScale = 1.5 }) })
	assertFalse(ok)
	assertEqual("test_icon: glyphScale must be a number above 0 and at most 1", err)
end)
