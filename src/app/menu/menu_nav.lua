-- Device-agnostic menu navigation: keys, gamepad buttons and stick motion all
-- become the same four actions -- "up", "down", "confirm", "back". Pure (no
-- `love.*`); the callers pass whatever LÖVE reported, from ANY gamepad.
local MenuNav = {}

local KEYS = {
	up = "up", w = "up",
	left = "left", a = "left", right = "right", d = "right",
	down = "down", s = "down",
	["return"] = "confirm", kpenter = "confirm", space = "confirm",
	escape = "back", backspace = "back",
}

local BUTTONS = { dpup = "up", dpdown = "down", dpleft = "left", dpright = "right", a = "confirm", b = "back" }

function MenuNav.fromButton(button)
	return BUTTONS[button]
end

function MenuNav.fromKey(key)
	return KEYS[key]
end

local STICK_THRESHOLD = 0.6

-- Stick tracker: one per app. Returns "up"/"down" (vertical axis) or
-- "left"/"right" (horizontal axis) on the frame the left stick crosses the
-- threshold, then nothing until that axis recentres.
function MenuNav.newStick()
	local directions = {}
	local names = { lefty = { "up", "down" }, leftx = { "left", "right" } }
	local stick = {}
	function stick:axis(axis, value)
		local pair = names[axis]
		if not pair then
			return nil
		end
		local now = nil
		if value >= STICK_THRESHOLD then
			now = pair[2]
		elseif value <= -STICK_THRESHOLD then
			now = pair[1]
		end
		local fired = now ~= directions[axis] and now or nil
		directions[axis] = now
		return fired
	end
	return stick
end

-- New 1-based selection after `action`, wrapping around `count` items.
function MenuNav.move(selected, count, action)
	if action == "down" then
		return selected % count + 1
	elseif action == "up" then
		return (selected - 2) % count + 1
	end
	return selected
end

-- Applies one action to a menu model { items = { { label, action, adjust = fn(dir)|nil } },
-- selected, onBack = fn|nil }: up/down move, confirm runs the selected item,
-- left/right call its `adjust` ("left"/"right") when it has one, back runs onBack.
function MenuNav.apply(menu, action)
	if action == "up" or action == "down" then
		menu.selected = MenuNav.move(menu.selected, #menu.items, action)
	elseif action == "confirm" then
		menu.items[menu.selected].action()
	elseif (action == "left" or action == "right") and menu.items[menu.selected].adjust then
		menu.items[menu.selected].adjust(action)
	elseif action == "back" and menu.onBack then
		menu.onBack()
	end
end

return MenuNav
