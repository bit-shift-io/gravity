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

-- Accumulates pairwise dynamic gravity across every body in `bodies` (any
-- table iterable with `pairs` -- an array, or a slot->body map like
-- `sim.bodies.slots`), built on `Gravity.pointMass` (docs/adr/
-- 0002-hybrid-gravity-field.md "Dynamic gravity"). Returns a table keyed the
-- same way as `bodies`, each value `{x = ax, y = ay}` -- the combined
-- acceleration that body should ADD to its static-field sample, computed
-- from every OTHER body before any position changes (this slice's Gotcha:
-- accumulate before integrating, so results don't depend on iteration
-- order -- the caller integrates only after every entry here is complete).
--
-- A dead body neither exerts nor receives (it's already gone in every way
-- that matters). A pinned body (a landed ship, docs/CONTEXT.md "Landed")
-- still exerts its mass's pull on everything else, but its own entry stays
-- zero -- it's fixed to a surface and does not integrate
-- (src/sim/step.lua's `not body.pinned` guard already skips it there; this
-- mirrors that same flag on the receiving side only). A body never
-- contributes to its own entry (self-exclusion is by identity, not
-- position, so it holds even for two bodies that happen to coincide).
-- A passive body (`body.passive`, docs/CONTEXT.md "Passive body") neither
-- exerts nor receives, and has no entry in the result.
-- A negative `mass` repels rather than attracts -- `Gravity.pointMass`
-- already flips the sign, so no separate branch is needed here.
function Gravity.pairwise(bodies, G, eps)
	local accel = {}
	-- Passive bodies (cosmetic, e.g. exhaust particles) are filtered out here,
	-- once, so the O(n^2) loops below only ever see active bodies.
	local sources = {}
	local receivers = {}
	for key, body in pairs(bodies) do
		if not body.dead and not body.passive then
			accel[key] = { x = 0, y = 0 }
			sources[key] = body
			if not body.pinned then
				receivers[key] = body
			end
		end
	end

	for keyA, receiver in pairs(receivers) do
		local entry = accel[keyA]
		for keyB, bodyB in pairs(sources) do
			if keyB ~= keyA then
				local dx = receiver.x - bodyB.x
				local dy = receiver.y - bodyB.y
				local ax, ay = Gravity.pointMass(dx, dy, bodyB.mass, G, eps)
				entry.x = entry.x + ax
				entry.y = entry.y + ay
			end
		end
	end

	return accel
end

return Gravity
