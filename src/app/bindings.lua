-- Binding -> intent. A roster slot's binding (src/game/roster.lua) decides
-- which device it reads; `readIntent` turns that device's state into the
-- { rotate = -1|0|1, thrust, fire } intent shape in ctx.intents[slot].
-- No `love.*` here: callers pass `devices`, so this stays unit-testable.
--   devices = { isDown = fn(key) -> bool, joysticks = { [ordinal] = joystick } }
-- A joystick needs `isGamepadDown(button)` and `getGamepadAxis(axis)`.
local Config = require("src.game.config")

local Bindings = {}

Bindings.LAYOUTS = {
	wasd = { left = "a", right = "d", thrust = "w", fire = "q" },
	arrows = { left = "left", right = "right", thrust = "up", fire = "rshift" },
	ijkl = { left = "j", right = "l", thrust = "i", fire = "o" },
}

-- Gamepad defaults: stick or d-pad rotates (and aims the turret), A thrusts,
-- X fires (hold to charge, release to fire).
Bindings.GAMEPAD = {
	axis = "leftx",
	left = "dpleft",
	right = "dpright",
	thrust = "a",
	fire = "x",
}

local function neutral()
	return { rotate = 0, thrust = false, fire = false }
end

local function readKeyboard(layoutName, devices)
	local keys = Bindings.LAYOUTS[layoutName]
	if not keys then
		return neutral()
	end
	local rotate = 0
	if devices.isDown(keys.left) then
		rotate = rotate - 1
	end
	if devices.isDown(keys.right) then
		rotate = rotate + 1
	end
	return { rotate = rotate, thrust = devices.isDown(keys.thrust), fire = devices.isDown(keys.fire) }
end

local function readGamepad(joystick)
	local map = Bindings.GAMEPAD
	local rotate = 0
	local x = joystick:getGamepadAxis(map.axis)
	if math.abs(x) >= Config.players.gamepadDeadzone then
		rotate = x < 0 and -1 or 1
	end
	if joystick:isGamepadDown(map.left) then
		rotate = rotate - 1
	end
	if joystick:isGamepadDown(map.right) then
		rotate = rotate + 1
	end
	if rotate < -1 then
		rotate = -1
	elseif rotate > 1 then
		rotate = 1
	end
	return { rotate = rotate, thrust = joystick:isGamepadDown(map.thrust), fire = joystick:isGamepadDown(map.fire) }
end

function Bindings.readIntent(binding, devices)
	if binding.kind == "keyboard" then
		return readKeyboard(binding.layout, devices)
	elseif binding.kind == "gamepad" then
		local joystick = devices.joysticks[binding.id]
		if joystick then
			return readGamepad(joystick)
		end
	end
	return neutral()
end

return Bindings
