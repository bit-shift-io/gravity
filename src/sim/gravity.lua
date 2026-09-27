-- Softened inverse-square gravity: the one law both the baked static field
-- (src/sim/field.lua) and the later pairwise dynamic gravity build on
-- (docs/adr/0002-hybrid-gravity-field.md). Pure math -- no `love.*`
-- (docs/ARCHITECTURE.md "Layers").
local Gravity = {}

-- Acceleration a sample point feels from a point mass `m`, given
-- (dx, dy) = sample - mass (the vector FROM the mass TO the sample point).
-- Returns ax, ay pointing back toward the mass (attraction). `eps` softens
-- the denominator so a sample near the mass's own location doesn't divide
-- by (near) zero. At dx = dy = 0 the numerator vector is also zero, so this
-- returns 0, 0 regardless of softening -- nothing needs to special-case a
-- mass sampling its own cell (see field.lua's self-exclusion gotcha; this
-- is the belt to that braces).
function Gravity.pointMass(dx, dy, m, G, eps)
	local r2 = dx * dx + dy * dy + eps * eps
	local invR3 = 1 / (r2 * math.sqrt(r2))
	local scale = -G * m * invR3
	return dx * scale, dy * scale
end

return Gravity
