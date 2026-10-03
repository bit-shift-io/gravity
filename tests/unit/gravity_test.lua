local Gravity = require("src.sim.gravity")

test("Gravity.pointMass pulls a sample point back toward the mass", function()
	local ax, ay = Gravity.pointMass(10, 0, 1, 1, 1)

	assertTrue(ax < 0, "expected acceleration to point toward the mass (negative x)")
	assertNear(0, ay)
end)

test("Gravity.pointMass magnitude falls off with distance", function()
	local axNear = Gravity.pointMass(10, 0, 1, 1, 1)
	local axFar = Gravity.pointMass(40, 0, 1, 1, 1)

	assertTrue(math.abs(axFar) < math.abs(axNear), "expected a farther sample to feel weaker pull")
end)

test("Gravity.pointMass scales linearly with mass", function()
	local ax1 = Gravity.pointMass(10, 0, 1, 1, 1)
	local ax2 = Gravity.pointMass(10, 0, 2, 1, 1)

	assertNear(ax1 * 2, ax2)
end)

test("Gravity.pointMass is zero at the mass's own location, even with no softening", function()
	local ax, ay = Gravity.pointMass(0, 0, 5, 1, 0)

	assertNear(0, ax)
	assertNear(0, ay)
end)

test("Gravity.pointMass stays finite at very small softened distances", function()
	local ax, ay = Gravity.pointMass(0.0001, 0, 1000, 1, 1)

	assertTrue(ax == ax, "expected a real number, got NaN") -- NaN ~= NaN
	assertTrue(ax > -math.huge and ax < math.huge, "expected a finite number")
end)

test("Gravity.pointMass with falloff = 1 decays linearly (1/r), slower than inverse-square", function()
	-- eps = 0 so magnitude is exactly G*m / r^falloff.
	local near = Gravity.pointMass(10, 0, 1, 1, 0, 1)
	local far = Gravity.pointMass(40, 0, 1, 1, 0, 1)
	assert(math.abs(near / far - 4) < 1e-9, "1/r: 4x the distance gives 1/4 the pull")
	local nearSq = Gravity.pointMass(10, 0, 1, 1, 0)
	local farSq = Gravity.pointMass(40, 0, 1, 1, 0)
	assert(math.abs(nearSq / farSq - 16) < 1e-9, "default stays inverse-square")
end)
