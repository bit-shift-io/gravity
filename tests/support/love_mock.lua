-- Minimal love.* mock for future slices that need `love.keyboard` /
-- `love.joystick` / `love.timer` under the integration tier without a real
-- window. Nothing in src/game or src/sim touches `love.*` (docs/ARCHITECTURE.md
-- "Layers"), so this slice's tests don't need it yet -- it exists now so the
-- input-mapping slice can extend it instead of inventing the pattern cold.
local LoveMock = {}

-- Builds one fresh love mock (own keyboard/joystick state) per test so
-- tests don't leak input state between each other. `files` is the in-memory
-- save directory (path -> contents); pass the same table to a second mock to
-- model a relaunch against the same save directory.
function LoveMock.new(files)
	local state = {
		keysDown = {},
		joysticks = {},
		files = files or {},
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

	love.filesystem = {
		getInfo = function(path)
			if state.files[path] ~= nil then
				return { type = "file", size = #state.files[path] }
			end
			return nil
		end,
		read = function(path)
			if state.files[path] == nil then
				return nil, "Could not open file " .. path
			end
			return state.files[path]
		end,
		write = function(path, data)
			state.files[path] = data
			return true
		end,
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
