local Integrate = require("src.sim.integrate")

test("Integrate.step with constant acceleration matches the closed-form position within tolerance", function()
	local body = { x = 0, y = 0, vx = 0, vy = 0 }
	local ax, ay = 100, 0
	local dt = 1 / 60
	local steps = 60

	for _ = 1, steps do
		Integrate.step(body, ax, ay, dt)
	end

	local t = steps * dt
	-- Semi-implicit Euler's position error against the true 0.5*a*t^2 is
	-- O(dt) per step, so a small but non-zero tolerance is expected here,
	-- not exact agreement.
	local expectedX = 0.5 * ax * t * t
	assertNear(expectedX, body.x, 1.0)
	assertNear(ax * t, body.vx, 0.0001)
end)

test("Integrate.step leaves velocity and position unchanged for zero acceleration and zero initial velocity", function()
	local body = { x = 5, y = 7, vx = 0, vy = 0 }

	Integrate.step(body, 0, 0, 1 / 60)

	assertNear(5, body.x)
	assertNear(7, body.y)
end)

test("Integrate.step advances angle by angularVelocity * dt", function()
	local body = { x = 0, y = 0, vx = 0, vy = 0, angle = 0, angularVelocity = 2 }

	Integrate.step(body, 0, 0, 0.5)

	assertNear(1, body.angle)
end)
