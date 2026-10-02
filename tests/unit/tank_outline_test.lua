local Poly = require("src.core.poly")
local TankOutline = require("src.core.tank_outline")

local DOME = {
	{ x = -8, y = 8 },
	{ x = 8, y = 8 },
	{ x = 8, y = -1 },
	{ x = 4, y = -5 },
	{ x = -4, y = -5 },
	{ x = -8, y = -1 },
}

local function absArea(points)
	return math.abs(Poly.area(points))
end

test("TankOutline merges an upright barrel into the dome as one outline", function()
	local outline = TankOutline.build(DOME, 0, 12, 1.5)
	-- Dome area plus the barrel's 3px-wide, 7px-tall stub above the dome top.
	assertNear(absArea(DOME) + 3 * 7, absArea(outline), 1e-6)
	assertTrue(Poly.isSimple(outline), "outline must not cross itself")
end)

test("TankOutline leaves no outline vertex on the dome's covered top edge", function()
	local outline = TankOutline.build(DOME, 0, 12, 1.5)
	for _, p in ipairs(outline) do
		assertFalse(p.y == -5 and math.abs(p.x) < 1.5 - 1e-6, "dome top edge must be cut away under the barrel")
	end
end)

test("TankOutline contains the muzzle tip for a barrel swung to the limit", function()
	for _, angle in ipairs({ math.rad(80), -math.rad(80), math.rad(40) }) do
		local outline = TankOutline.build(DOME, angle, 12, 1.5)
		assertTrue(Poly.isSimple(outline), "outline must stay simple at angle " .. angle)
		local nearTip = { x = 11 * math.sin(angle), y = -11 * math.cos(angle) }
		assertTrue(Poly.pointInPolygon(outline, nearTip), "barrel should be part of the outline")
		assertTrue(absArea(outline) > absArea(DOME))
	end
end)

test("TankOutline returns the dome unchanged when the barrel is hidden inside it", function()
	local outline = TankOutline.build(DOME, 0, 4, 1.5)
	assertNear(absArea(DOME), absArea(outline), 1e-6)
end)
