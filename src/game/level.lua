-- A level is a plain table: worlds (polygon vertex lists, an optional
-- density or mass override), spawn points, and asteroid settings
-- (docs/CONTEXT.md "World", "Match"). Tests pass literal level tables, never
-- generated ones, unless the test targets the generator
-- (docs/ARCHITECTURE.md "Rules").
local Poly = require("src.core.poly")
local Config = require("src.game.config")

local Level = {}

-- Validates and normalises `t.worlds` in place: rejects self-intersecting
-- polygons, normalises each polygon to one winding (src/core/poly.lua
-- Poly.normalize), and derives world.mass from density x area when mass
-- isn't set explicitly. Returns true, or false plus an error message.
function Level.validate(t)
	if type(t) ~= "table" or type(t.worlds) ~= "table" then
		return false, "level must be a table with a worlds list"
	end

	for index, world in ipairs(t.worlds) do
		if type(world.vertices) ~= "table" or #world.vertices < 3 then
			return false, string.format("world %d: vertices must have at least 3 points", index)
		end

		if not Poly.isSimple(world.vertices) then
			return false, string.format("world %d: polygon is self-intersecting", index)
		end

		world.vertices = Poly.normalize(world.vertices)

		if not world.mass then
			local density = world.density or Config.world.density
			world.mass = density * math.abs(Poly.area(world.vertices))
		end
	end

	return true
end

return Level
