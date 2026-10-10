-- Warp transition curves (pure). `t` is the incoming shot's blend weight,
-- 0 on the first overlap frame to 1 on the last (Timeline.blend). Each side
-- gets a radial zoom-blur `strength` (fraction of the radius smeared) and a
-- `scale` (zoom about the frame centre); the first and last frames are plain.
local Warp = {}

Warp.MAX_STRENGTH = 0.35
Warp.MAX_SCALE = 1.25
Warp.MAX_BRIGHTNESS = 0.12

-- The outgoing shot: blurs outward and zooms in as it fades away.
function Warp.outgoing(t)
	return { strength = Warp.MAX_STRENGTH * t, scale = 1 + (Warp.MAX_SCALE - 1) * t }
end

-- The incoming shot: starts blurred (and slightly zoomed in) and settles.
function Warp.incoming(t)
	local u = 1 - t
	return { strength = Warp.MAX_STRENGTH * u, scale = 1 + (Warp.MAX_SCALE - 1) * u }
end

-- Additive white lift, peaking at the midpoint.
function Warp.brightness(t)
	return Warp.MAX_BRIGHTNESS * 4 * t * (1 - t)
end

return Warp
