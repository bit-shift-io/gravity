local Bindings = require("src.app.bindings")

-- devices = { isDown = fn(key), joysticks = { [ordinal] = joystick } }
local function keyboard(...)
	local down = {}
	for _, k in ipairs({ ... }) do
		down[k] = true
	end
	return { isDown = function(key) return down[key] == true end, joysticks = {} }
end

local function pad(opts)
	opts = opts or {}
	local buttons, axes = opts.buttons or {}, opts.axes or {}
	return {
		isGamepadDown = function(_, b) return buttons[b] == true end,
		getGamepadAxis = function(_, a) return axes[a] or 0 end,
	}
end

local function padDevices(joystick)
	return { isDown = function() return false end, joysticks = { [1] = joystick } }
end

local function wasd(layout) return { kind = "keyboard", layout = layout } end

test("wasd layout maps a, d, w, q to rotate, thrust and fire", function()
	local b = wasd("wasd")
	local i = Bindings.readIntent(b, keyboard("a", "w", "q"))
	assertEqual(-1, i.rotate)
	assertTrue(i.thrust)
	assertTrue(i.fire)
	assertEqual(1, Bindings.readIntent(b, keyboard("d")).rotate)
end)

test("arrows layout maps arrows and right shift", function()
	local b = wasd("arrows")
	local i = Bindings.readIntent(b, keyboard("right", "up", "rshift"))
	assertEqual(1, i.rotate)
	assertTrue(i.thrust)
	assertTrue(i.fire)
	assertEqual(-1, Bindings.readIntent(b, keyboard("left")).rotate)
end)

test("ijkl layout maps j, l, i, o", function()
	local b = wasd("ijkl")
	local i = Bindings.readIntent(b, keyboard("j", "i", "o"))
	assertEqual(-1, i.rotate)
	assertTrue(i.thrust)
	assertTrue(i.fire)
	assertEqual(1, Bindings.readIntent(b, keyboard("l")).rotate)
end)

test("keys of another layout do nothing", function()
	local i = Bindings.readIntent(wasd("ijkl"), keyboard("a", "d", "w", "q", "up", "left", "rshift"))
	assertEqual(0, i.rotate)
	assertFalse(i.thrust)
	assertFalse(i.fire)
end)

test("opposite rotate keys cancel", function()
	assertEqual(0, Bindings.readIntent(wasd("wasd"), keyboard("a", "d")).rotate)
end)

test("a stick below the deadzone gives rotate 0", function()
	local d = padDevices(pad({ axes = { leftx = 0.2 } }))
	assertEqual(0, Bindings.readIntent({ kind = "gamepad", id = 1 }, d).rotate)
end)

test("a stick past the deadzone rotates in its direction", function()
	local b = { kind = "gamepad", id = 1 }
	assertEqual(1, Bindings.readIntent(b, padDevices(pad({ axes = { leftx = 0.9 } }))).rotate)
	assertEqual(-1, Bindings.readIntent(b, padDevices(pad({ axes = { leftx = -0.9 } }))).rotate)
end)

test("the d-pad rotates too", function()
	local b = { kind = "gamepad", id = 1 }
	assertEqual(-1, Bindings.readIntent(b, padDevices(pad({ buttons = { dpleft = true } }))).rotate)
	assertEqual(1, Bindings.readIntent(b, padDevices(pad({ buttons = { dpright = true } }))).rotate)
end)

test("gamepad a thrusts and x fires", function()
	local b = { kind = "gamepad", id = 1 }
	local i = Bindings.readIntent(b, padDevices(pad({ buttons = { a = true, x = true } })))
	assertTrue(i.thrust)
	assertTrue(i.fire)
end)

test("a gamepad binding with no joystick at its ordinal reads neutral", function()
	local i = Bindings.readIntent({ kind = "gamepad", id = 2 }, padDevices(pad({ buttons = { a = true } })))
	assertEqual(0, i.rotate)
	assertFalse(i.thrust)
	assertFalse(i.fire)
end)
