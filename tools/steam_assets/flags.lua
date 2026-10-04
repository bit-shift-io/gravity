-- Pure flag resolution (no `love.*`): an entry's hud/glow/crt override the
-- saved in-game look; omitted flags inherit it (HUD on, glow/CRT from the
-- saved post mode).
local PostMode = require("src.app.post.post_mode")

local Flags = {}

local function pick(override, inherited)
	if override == nil then
		return inherited
	end
	return override
end

-- { hud, glow, crt } booleans for `entry` given the saved `postMode`.
function Flags.resolve(entry, postMode)
	return {
		hud = pick(entry.hud, true),
		glow = pick(entry.glow, PostMode.has(postMode, "glow")),
		crt = pick(entry.crt, PostMode.has(postMode, "crt")),
	}
end

return Flags
