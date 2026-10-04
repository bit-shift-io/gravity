-- Formats a scouted frame as a pasteable manifest entry (no `love.*`). The
-- output is a Lua table literal: it loads back with load(), passes
-- ManifestCheck.validate and rebuilds the frame with Scene.build. The name is
-- a placeholder to rename on paste.
local EntryFormat = {}

-- Fixed decimals with trailing zeros dropped: 0.8123, -408.25, 60.
local function number(value)
	local text = string.format("%.4f", value):gsub("0+$", ""):gsub("%.$", "")
	return text
end

local function binding(b)
	local keys = {}
	for key in pairs(b) do
		keys[#keys + 1] = key
	end
	table.sort(keys)
	local parts = {}
	for _, key in ipairs(keys) do
		local value = b[key]
		parts[#parts + 1] = key .. " = " .. (type(value) == "string" and string.format("%q", value) or tostring(value))
	end
	return "{ " .. table.concat(parts, ", ") .. " }"
end

-- frame = { seed, step, roster, camera = { x, y, zoom } | false }
function EntryFormat.entry(frame)
	local lines = {
		"{",
		'\tname = "scout",',
		"\twidth = 1920,",
		"\theight = 1080,",
		"\tseed = " .. number(frame.seed) .. ",",
		"\tstep = " .. number(frame.step) .. ",",
		"\troster = {",
	}
	for _, slot in ipairs(frame.roster) do
		lines[#lines + 1] = string.format("\t\t{ color = %d, binding = %s },", slot.color, binding(slot.binding))
	end
	lines[#lines + 1] = "\t},"
	if frame.camera then
		local c = frame.camera
		lines[#lines + 1] = string.format("\tcamera = { x = %s, y = %s, zoom = %s },", number(c.x), number(c.y), number(c.zoom))
	end
	lines[#lines + 1] = "\tglow = true,"
	lines[#lines + 1] = "\tcrt = true,"
	lines[#lines + 1] = "}"
	return table.concat(lines, "\n")
end

return EntryFormat
