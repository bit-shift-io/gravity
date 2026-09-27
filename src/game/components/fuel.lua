-- Fuel component (docs/ARCHITECTURE.md "Component"): plain-data sub-table
-- `{ amount, capacity, burnRate }` plus these pure functions over it. Never
-- updates itself -- the owning system (src/game/systems/ship_system.lua,
-- via src/game/components/thruster.lua) calls Fuel.consume/add explicitly.
local Fuel = {}

function Fuel.isEmpty(fuel)
	return fuel.amount <= 0
end

-- Burns burnRate * dt worth of fuel, clamped so amount never goes below 0
-- (docs/ARCHITECTURE.md "Nothing is removed... outside the despawn sweep"
-- doesn't apply here, but the same never-go-negative discipline does).
function Fuel.consume(fuel, dt)
	fuel.amount = math.max(0, fuel.amount - fuel.burnRate * dt)
end

-- Refuels by `amount`, clamped to capacity. Used by the lander component
-- (later slice) once a ship docks; exists now so Thruster/Fuel's contract
-- is complete from this slice on.
function Fuel.add(fuel, amount)
	fuel.amount = math.min(fuel.capacity, fuel.amount + amount)
end

return Fuel
