local ShotRunner = require("tools.trailer.shot_runner")

local function shot(extra)
	local s = {
		seed = 4242,
		roster = {
			{ color = 1, binding = { kind = "ai", level = "hard" } },
			{ color = 2, binding = { kind = "ai", level = "hard" } },
		},
		from = 40,
		to = 50,
		speed = 2,
	}
	for k, v in pairs(extra or {}) do
		s[k] = v
	end
	return s
end

-- Every frame of the stepper as { step, k, x } (x: the sim camera's x).
local function frames(s, extra)
	local stepper = ShotRunner.open(s, extra)
	local list = {}
	while true do
		local view, step, k = stepper:next()
		if not view then
			return list
		end
		list[#list + 1] = { step = step, k = k, x = view.camera.x }
	end
end

test("Trailer ShotRunner open gives the extra frames before and after the shot's own", function()
	local list = frames(shot(), { pre = 3, post = 2 })
	assertEqual(10, #list)
	assertEqual(36, list[1].step)
	assertEqual(-2, list[1].k)
	assertEqual(1, list[4].k)
	assertEqual(42, list[4].step)
	assertEqual(50, list[8].step)
	assertEqual(54, list[10].step)
end)

test("Trailer ShotRunner extra frames leave the frames inside from..to unchanged", function()
	local plain = frames(shot())
	local extended = frames(shot(), { pre = 3, post = 2 })
	assertEqual(5, #plain)
	for i, frame in ipairs(plain) do
		assertEqual(frame.step, extended[i + 3].step)
		assertEqual(frame.x, extended[i + 3].x)
	end
end)

test("Trailer ShotRunner run still gives one frame per speed steps ending on to", function()
	local steps = {}
	ShotRunner.run(shot(), function(_, step)
		steps[#steps + 1] = step
	end)
	assertEqual("42,44,46,48,50", table.concat(steps, ","))
end)

test("Trailer ShotRunner onStep sees the pre-roll before the extended start", function()
	local seen = {}
	local stepper = ShotRunner.open(shot(), { pre = 3 }, function(_, step)
		seen[#seen + 1] = step
	end)
	stepper:next()
	assertEqual(36, #seen)
	assertEqual(36, seen[#seen])
end)

test("Trailer ShotRunner keyframed cameras hold their end views on the extra frames", function()
	local camera = { { t = 0, x = 0, y = 0, zoom = 1 }, { t = 1, x = 100, y = 0, zoom = 1 } }
	local list = frames(shot({ camera = camera }), { pre = 2, post = 2 })
	assertEqual(0, list[1].x)
	assertEqual(0, list[3].x)
	assertEqual(100, list[7].x)
	assertEqual(100, list[9].x)
end)
