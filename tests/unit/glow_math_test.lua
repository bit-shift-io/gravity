local GlowMath = require("src.app.post.glow_math")

test("GlowMath.halfSize rounds up and never reaches zero", function()
	local w, h = GlowMath.halfSize(1281, 720)
	assertEqual(641, w)
	assertEqual(360, h)
	local mw, mh = GlowMath.halfSize(1, 1)
	assertEqual(1, mw)
	assertEqual(1, mh)
end)

test("GlowMath.weights is a normalised, decreasing kernel", function()
	local w = GlowMath.weights()
	assertEqual(GlowMath.TAPS + 1, #w)
	local sum = w[1]
	for i = 2, #w do
		sum = sum + 2 * w[i]
		assertEqual(true, w[i] < w[i - 1])
	end
	assertEqual(true, math.abs(sum - 1) < 1e-9)
end)

test("GlowMath.tapSpacing scales with the fit and floors at one pixel", function()
	assertEqual(true, GlowMath.tapSpacing(16, 2) > GlowMath.tapSpacing(16, 1))
	assertEqual(1, GlowMath.tapSpacing(16, 0.1))
end)
