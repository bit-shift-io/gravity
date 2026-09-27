-- Typed pool arrays (docs/ARCHITECTURE.md "Pool"): ships, projectiles,
-- asteroids. Pools own record lifetime and update order, never physics.
-- Pools.sweep runs alongside src/sim/bodies.lua's Bodies.sweep as the only
-- place records are removed (docs/ARCHITECTURE.md "Despawn sweep") -- and
-- runs *before* it, so no record is left pointing at a body id that
-- Bodies.sweep has already freed (this slice's Gotcha: "Sweep bodies after
-- pools").
local Pools = {}

function Pools.new()
	return {
		ships = {},
		projectiles = {},
		asteroids = {},
	}
end

local function sweepArray(array)
	local kept = {}
	for _, record in ipairs(array) do
		if not record.dead then
			table.insert(kept, record)
		end
	end

	for i = #array, 1, -1 do
		array[i] = nil
	end

	for i, record in ipairs(kept) do
		array[i] = record
	end
end

function Pools.sweep(pools)
	sweepArray(pools.ships)
	sweepArray(pools.projectiles)
	sweepArray(pools.asteroids)
end

return Pools
