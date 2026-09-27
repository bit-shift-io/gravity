-- Minimal love.* mock for future slices that need `love.keyboard` /
-- `love.joystick` / `love.timer` under the integration tier without a real
-- window. Nothing in src/game or src/sim touches `love.*` (docs/ARCHITECTURE.md
-- "Layers"), so this slice's tests don't need it yet -- it exists now so the
-- input-mapping slice can extend it instead of inventing the pattern cold.
local LoveMock = {}

-- Builds one fresh love mock (own keyboard/joystick state) per test so
-- tests don't leak input state between each other.
function LoveMock.new()
	local state = {
		keysDown = {},
		joysticks = {},
	}

	local love = {}

	love.keyboard = {
		isDown = function(key)
			return state.keysDown[key] == true
		end,
	}

	love.joystick = {
		getJoysticks = function()
			return state.joysticks
		end,
	}

	love.timer = {
		_getTime = 0,
		getDelta = function()
			return 1 / 60
		end,
		getTime = function()
			love.timer._getTime = love.timer._getTime + 1 / 60
			return love.timer._getTime
		end,
		sleep = function() end,
	}

	love.getVersion = function()
		return 11, 5, 0
	end

	love.graphics = {
		getWidth = function()
			return 1280
		end,
		getHeight = function()
			return 720
		end,
		getDimensions = function()
			return 1280, 720
		end,
		setColor = function() end,
		setBackgroundColor = function() end,
		print = function() end,
		push = function() end,
		pop = function() end,
		translate = function() end,
		scale = function() end,
		line = function() end,
		polygon = function() end,
		circle = function() end,
		setLineWidth = function() end,
		newFont = function()
			return {
				getWidth = function()
					return 0
				end,
				getHeight = function()
					return 0
				end,
			}
		end,
		setFont = function() end,
		getFont = function()
			return {
				getWidth = function()
					return 0
				end,
				getHeight = function()
					return 0
				end,
			}
		end,
	}

	love._state = state
	return love
end

return LoveMock
