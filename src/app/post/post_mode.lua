-- Post mode: which post effects are active. Pure -- no `love.*` -- so it is
-- unit-testable. Session-only, rendering only, never the sim.
local PostMode = {}

PostMode.OFF = "off"
PostMode.GLOW = "glow"
PostMode.GLOW_CRT = "glowCrt"

-- Cycle order for the `P` key.
local ORDER = { PostMode.OFF, PostMode.GLOW, PostMode.GLOW_CRT }

local EFFECTS = {
	off = { glow = false, crt = false },
	glow = { glow = true, crt = false },
	glowCrt = { glow = true, crt = true },
}

-- The mode after `mode`, wrapping back to off.
function PostMode.next(mode)
	for i, m in ipairs(ORDER) do
		if m == mode then
			return ORDER[i % #ORDER + 1]
		end
	end
	return ORDER[1]
end

-- Whether `effect` ("glow" or "crt") is active in `mode`.
function PostMode.has(mode, effect)
	local set = EFFECTS[mode]
	return set ~= nil and set[effect] == true
end

return PostMode
