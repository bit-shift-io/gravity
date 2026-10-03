-- Every LÖVE-11-vs-12 version-sensitive call goes through here (see
-- docs/memory/love-11-and-12-compat.md). Empty wrappers to start -- filled in
-- as later slices hit a real difference (stencils, canvas/mesh formats).
local Compat = {}

function Compat.getVersion()
	return love.getVersion()
end

function Compat.isLove12()
	local major = Compat.getVersion()
	return major >= 12
end

-- Plain RGBA canvas of the given pixel size, nearest-filtered so drawing it
-- 1:1 stays sharp. newCanvas(w, h) is valid on both 11.5 and 12.
function Compat.newCanvas(width, height, filter)
	local canvas = love.graphics.newCanvas(width, height)
	filter = filter or "nearest"
	canvas:setFilter(filter, filter)
	canvas:setWrap("clamp", "clamp")
	return canvas
end

-- Shader from GLSL source. Same signature on 11.5 and 12; kept here so
-- later effect slices have one place to adapt.
function Compat.newShader(source)
	return love.graphics.newShader(source)
end

-- Connected joysticks by ordinal (position in LÖVE's connected list), so a
-- roster binding's `id` survives persistence. Unplugged pads drop out.
function Compat.getJoysticks()
	local joysticks = {}
	for ordinal, joystick in ipairs(love.joystick.getJoysticks()) do
		if joystick:isConnected() then
			joysticks[ordinal] = joystick
		end
	end
	return joysticks
end

-- Loads the SDL controller mapping database if present; same call on 11.5 and 12.
function Compat.loadGamepadMappings(path)
	if love.filesystem.getInfo(path) then
		love.joystick.loadGamepadMappings(path)
	end
end

return Compat
