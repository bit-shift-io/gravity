-- Lifetime component (docs/ARCHITECTURE.md "Component"): plain-data
-- sub-table `{ remaining }` plus this pure function over it, called
-- explicitly by the owning system (src/game/systems/projectile_system.lua's
-- update). Marks the owning record `dead = true` once its remaining time
-- runs out -- never removes anything itself (docs/ARCHITECTURE.md "Nothing
-- is removed... outside the despawn sweep"); the despawn sweep (src/game/
-- pools.lua Pools.sweep) does the actual removal later the same frame.
-- Generic over any record with a `.lifetime` sub-table, not projectile-
-- specific, so a future timed entity (a mine, a pickup) can reuse it
-- without changes.
local Lifetime = {}

function Lifetime.tick(record, ctx)
	local lifetime = record.lifetime
	if not lifetime then
		return
	end

	lifetime.remaining = lifetime.remaining - ctx.dt
	if lifetime.remaining <= 0 then
		record.dead = true
	end
end

return Lifetime
