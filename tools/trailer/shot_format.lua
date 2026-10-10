-- Formats a scouted in/out pair as a pasteable trailer shot entry (no `love.*`).
-- The entry loads with load(), passes ManifestCheck and renders from the moment
-- scout showed at the in mark. The name is a placeholder to rename on paste.
local ShotFormat = {}

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

-- Frame k of a clip shows the state after step from + k (speed 1), so scout's
-- step s is the first frame when from = s - 1. Scout steps from 0, so step s
-- is reachable by shot=NAME as `from + 1`.
function ShotFormat.fromFor(markStep)
	return math.max(0, markStep - 1)
end

-- marks: { step, view = {x,y,zoom} | false (sim camera), sim = {x,y,zoom} (the sim camera at the mark) }
-- Returns true, text or false, message.
function ShotFormat.entry(args)
	local markIn, markOut = args.markIn, args.markOut
	if not markIn then
		return false, "mark in first (i)"
	end
	if not markOut then
		return false, "mark out (o) before printing"
	end
	if markOut.step < markIn.step then
		return false, string.format("out (step %d) is before in (step %d); mark out again", markOut.step, markIn.step)
	end
	local from, to = ShotFormat.fromFor(markIn.step), markOut.step
	if to <= from then
		return false, "the range is empty; mark out after step " .. from
	end

	local lines = {
		"{",
		'\tname = "scout",',
		"\tseed = " .. number(args.seed) .. ",",
		"\troster = {",
	}
	for _, slot in ipairs(args.roster) do
		lines[#lines + 1] = string.format("\t\t{ color = %d, binding = %s },", slot.color, binding(slot.binding))
	end
	lines[#lines + 1] = "\t},"
	lines[#lines + 1] = "\tfrom = " .. number(from) .. ","
	lines[#lines + 1] = "\tto = " .. number(to) .. ","
	-- No camera only when both marks followed the sim; otherwise a mark without
	-- its own view contributes the sim camera as it was at that mark.
	if markIn.view or markOut.view then
		local a, b = markIn.view or markIn.sim, markOut.view or markOut.sim
		lines[#lines + 1] = "\tcamera = {"
		lines[#lines + 1] = string.format("\t\t{ t = 0, x = %s, y = %s, zoom = %s },", number(a.x), number(a.y), number(a.zoom))
		lines[#lines + 1] = string.format("\t\t{ t = 1, x = %s, y = %s, zoom = %s },", number(b.x), number(b.y), number(b.zoom))
		lines[#lines + 1] = "\t},"
	end
	lines[#lines + 1] = "\tglow = true,"
	lines[#lines + 1] = "\tcrt = true,"
	lines[#lines + 1] = "}"
	return true, table.concat(lines, "\n")
end

return ShotFormat
