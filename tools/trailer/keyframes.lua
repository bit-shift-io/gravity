-- Camera keyframe interpolation (no `love.*`).
local Keyframes = {}

local function lerp(a, b, f)
	return a + (b - a) * f
end

-- Easing curves over a segment's 0..1 progress.
local EASES = {
	linear = function(f)
		return f
	end,
	["in"] = function(f)
		return f * f
	end,
	out = function(f)
		return 1 - (1 - f) * (1 - f)
	end,
	inOut = function(f)
		return f * f * (3 - 2 * f)
	end,
}
Keyframes.EASES = EASES

function Keyframes.at(keys, t)
	local first, last = keys[1], keys[#keys]
	if t <= first.t then
		return { x = first.x, y = first.y, zoom = first.zoom }
	end
	if t >= last.t then
		return { x = last.x, y = last.y, zoom = last.zoom }
	end
	local from, to = keys[1], keys[2]
	for i = 1, #keys - 1 do
		if t >= keys[i].t then
			from, to = keys[i], keys[i + 1]
		end
	end
	local f = EASES[from.ease or "inOut"]((t - from.t) / (to.t - from.t))
	return { x = lerp(from.x, to.x, f), y = lerp(from.y, to.y, f), zoom = math.exp(lerp(math.log(from.zoom), math.log(to.zoom), f)) }
end

return Keyframes
