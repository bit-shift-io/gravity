local Gravity = require("src.sim.gravity")

test("Gravity.pairwise pulls two equal bodies toward each other with equal and opposite accel", function()
	local bodies = {
		a = { x = 0, y = 0, mass = 1 },
		b = { x = 10, y = 0, mass = 1 },
	}

	local accel = Gravity.pairwise(bodies, 1, 1)

	assertTrue(accel.a.x > 0, "expected body a to accelerate toward body b (positive x)")
	assertTrue(accel.b.x < 0, "expected body b to accelerate toward body a (negative x)")
	assertNear(accel.a.x, -accel.b.x, 0.000001, "expected equal and opposite accel for equal masses")
	assertNear(0, accel.a.y)
	assertNear(0, accel.b.y)
end)

test("Gravity.pairwise gives a body zero self-contribution", function()
	local bodies = {
		a = { x = 5, y = 5, mass = 10 },
	}

	local accel = Gravity.pairwise(bodies, 1, 1)

	assertNear(0, accel.a.x)
	assertNear(0, accel.a.y)
end)

test("Gravity.pairwise: a pinned body exerts gravity but receives none", function()
	local bodies = {
		a = { x = 0, y = 0, mass = 1, pinned = true },
		b = { x = 10, y = 0, mass = 1 },
	}

	local accel = Gravity.pairwise(bodies, 1, 1)

	assertNear(0, accel.a.x, 0.000001, "expected pinned body to receive no acceleration")
	assertNear(0, accel.a.y, 0.000001, "expected pinned body to receive no acceleration")
	assertTrue(accel.b.x < 0, "expected non-pinned body to still be pulled toward the pinned body")
end)

test("Gravity.pairwise: a negative-mass body repels", function()
	local bodies = {
		a = { x = 0, y = 0, mass = -1 },
		b = { x = 10, y = 0, mass = 1 },
	}

	local accel = Gravity.pairwise(bodies, 1, 1)

	assertTrue(accel.b.x > 0, "expected body b to be pushed away from the negative-mass body")
end)
