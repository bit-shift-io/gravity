-- Field.bake dominates Match.new on a big world (a 5000x1000 floor costs ~5 s)
-- and tests build the same level many times. The baked fields are never
-- written after the bake, so identical worlds + field/gravity config share one.
local Field = require("src.sim.field")
local realBake = Field.bake
local bakeCache = {}

local function bakeKey(level, config)
	local parts = {
		config.field.cellSize, config.field.boundaryStrength,
		config.gravity.G, config.gravity.softening, config.gravity.falloff,
	}
	for _, world in ipairs(level.worlds) do
		parts[#parts + 1] = "m" .. world.mass
		for _, v in ipairs(world.vertices) do
			parts[#parts + 1] = v.x .. "," .. v.y
		end
	end
	return table.concat(parts, "|")
end

function Field.bake(level, config)
	local key = bakeKey(level, config)
	local hit = bakeCache[key]
	if not hit then
		local world, boundary = realBake(level, config)
		hit = { world, boundary }
		bakeCache[key] = hit
	end
	return hit[1], hit[2]
end
