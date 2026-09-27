-- Landable component (docs/ARCHITECTURE.md "Component"): the surface a ship
-- can land on -- a world (a plain table, docs/CONTEXT.md "World": "Not
-- stored in the body store") or, from slice 09, an asteroid (its sim BODY,
-- since velocity/angularVelocity/position live there, not on the pool
-- record). Pure functions only, called explicitly by
-- src/game/systems/ship_system.lua -- never self-updating (docs/
-- ARCHITECTURE.md "Rules").
local Landable = {}

-- The velocity of `host`'s surface at `point`, for measuring a ship's
-- landing/crash speed relative to the surface it touches rather than to
-- world space (docs/CONTEXT.md "Landing": "Speed is measured relative to
-- the surface point touched"). Worlds are static, so a world host (no
-- `vx`/`angularVelocity` fields) always returns zero here. An asteroid host
-- is a rigid body: its surface point velocity is its own linear velocity
-- PLUS its angular velocity crossed with the offset from its centre to
-- `point` -- standard rigid-body point velocity, v_point = v_center + ω × r,
-- where r = point - center. src/sim/integrate.lua advances angle by
-- `angularVelocity * dt` (a positive angularVelocity turns the same
-- direction src/core/vec2.lua's Vec2.rotate turns for a positive angle), so
-- the matching 2D cross product here is ω × r = ω * (-r.y, r.x) -- this is
-- verified directly by this slice's unit test ("surface velocity at the rim
-- of a spinning static asteroid equals ω × r").
function Landable.surfaceVelocityAt(host, point)
	if not host or not host.angularVelocity then
		return { x = 0, y = 0 }
	end

	local r = { x = point.x - host.x, y = point.y - host.y }
	local omega = host.angularVelocity

	return {
		x = (host.vx or 0) + omega * -r.y,
		y = (host.vy or 0) + omega * r.x,
	}
end

-- Refuel rate multiplier for `host` (1 unless the host overrides it, e.g. a
-- richer or poorer asteroid in a later slice). Worlds don't set this, so
-- they always refuel at the plain configured rate.
function Landable.refuelMultiplier(host)
	if host and host.refuelMultiplier then
		return host.refuelMultiplier
	end
	return 1
end

return Landable
