local Starfield = require("src.app.render.starfield")

test("the same seed lays out the same stars", function()
	local a = Starfield.generate(7, 40)
	local b = Starfield.generate(7, 40)
	assertEqual(40, #a)
	for i = 1, #a do
		assertEqual(a[i].x, b[i].x)
		assertEqual(a[i].y, b[i].y)
	end
end)

test("every star sits inside the virtual screen and is dim enough to stay background", function()
	for _, s in ipairs(Starfield.generate(3, 100)) do
		assert(s.x >= 0 and s.x < 1280, "x out of range")
		assert(s.y >= 0 and s.y < 720, "y out of range")
		assert(s.alpha > 0 and s.alpha <= 0.8, "alpha out of range")
	end
end)

test("a star drifts with the camera but stays on screen", function()
	local star = { x = 100, y = 100, depth = 0.1 }
	local x, y = Starfield.position(star, 50, 0)
	assertEqual(95, x)
	assertEqual(100, y)
	local wrappedX = Starfield.position(star, 2000, 0)
	assert(wrappedX >= 0 and wrappedX < 1280, "wrapped x out of range")
end)

test("a star rests at its base brightness between twinkles", function()
	local star = { alpha = 0.3, period = 8, offset = 0 }
	assertEqual(0.3, Starfield.brightness(star, 4))
end)

test("a star flashes to full brightness mid-twinkle", function()
	local star = { alpha = 0.3, period = 8, offset = 0 }
	local peak = Starfield.brightness(star, Starfield.TWINKLE_TIME / 2)
	assert(math.abs(peak - 1) < 1e-9, "peak should reach 1, got " .. peak)
end)

test("stars twinkle at different times", function()
	local stars = Starfield.generate(5, 30)
	local offsets = {}
	for _, s in ipairs(stars) do
		offsets[s.offset] = true
		assert(s.period >= 15 and s.period <= 40, "period out of range")
	end
	local distinct = 0
	for _ in pairs(offsets) do
		distinct = distinct + 1
	end
	assertEqual(30, distinct)
end)
