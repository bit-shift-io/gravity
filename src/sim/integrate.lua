-- Semi-implicit (symplectic) Euler: velocity is updated from acceleration
-- first, then position is updated from the *new* velocity. More stable
-- under gravity than explicit Euler (updating position from the old
-- velocity) at the same fixed timestep, at the cost of first-order (O(dt))
-- error against the closed-form solution -- expected, not a bug, per the
-- unit test's tolerance. Pure math -- no `love.*` (docs/ARCHITECTURE.md
-- "Layers").
local Integrate = {}

-- Mutates `body` in place: applies (ax, ay) over `dt`, then advances angle
-- by angularVelocity * dt when the body has one (bodies with no rotation,
-- e.g. future non-rotating asteroids, simply omit angularVelocity).
function Integrate.step(body, ax, ay, dt)
	body.vx = body.vx + ax * dt
	body.vy = body.vy + ay * dt
	body.x = body.x + body.vx * dt
	body.y = body.y + body.vy * dt

	if body.angularVelocity then
		body.angle = (body.angle or 0) + body.angularVelocity * dt
	end
end

return Integrate
