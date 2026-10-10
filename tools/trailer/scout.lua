-- trailer=scout seed=N (or shot=NAME): the Steam scout plus i / o to mark a
-- shot's in and out points and p to print a pasteable trailer shot entry.
-- shot=NAME loads that shot's seed and roster and steps from 0 to the moment
-- its first frame shows. Never writes files. Dev-only; uses `love.*` only
-- through the Steam scout.
local ShotFormat = require("tools.trailer.shot_format")

local TrailerScout = {}

local function findArg(args, pattern)
	for _, a in ipairs(args or {}) do
		local value = a:match(pattern)
		if value then
			return value
		end
	end
	return nil
end

local function resolve(args)
	local seed = tonumber(findArg(args, "^seed=(.+)$"))
	local name = findArg(args, "^shot=(.+)$")
	if name then
		for _, shot in ipairs(require("tools.trailer.manifest").shots) do
			if shot.name == name then
				-- Frame 1 of the clip shows step from + 1.
				return seed or shot.seed, shot.roster, shot.from + 1
			end
		end
		return nil, "trailer scout: no shot named '" .. name .. "'"
	end
	if not seed then
		return nil, "trailer scout needs seed=N or shot=NAME"
	end
	local function ai(color, level)
		return { color = color, binding = { kind = "ai", level = level } }
	end
	return seed, { ai(1, "hard"), ai(2, "hard"), ai(3, "easy"), ai(4, "easy") }, 0
end

function TrailerScout.start(args)
	local marks = {}
	local function mark(which, api)
		local c = api.simCamera
		marks[which] = {
			step = api.step,
			view = api.view and { x = api.view.x, y = api.view.y, zoom = api.view.zoom } or false,
			sim = { x = c.x, y = c.y, zoom = c.zoom },
		}
		print(string.format("trailer scout: marked %s at step %d", which, api.step))
	end
	require("tools.steam_assets.scout").start(args, {
		title = "TRAILER SCOUT",
		resolve = resolve,
		help = { "i mark in   o mark out   p print shot entry" },
		keypressed = function(key, api)
			if key == "i" then
				mark("in", api)
			elseif key == "o" then
				mark("out", api)
			end
		end,
		print = function(api)
			local ok, text = ShotFormat.entry({
				seed = api.seed,
				roster = api.roster,
				markIn = marks["in"],
				markOut = marks.out,
			})
			if ok then
				print(text)
			else
				io.stderr:write("trailer scout: " .. text .. "\n")
			end
		end,
	})
end

return TrailerScout
