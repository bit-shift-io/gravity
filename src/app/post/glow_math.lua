-- Pure glow maths (no `love.*`): half-resolution size and blur kernel.
local GlowMath = {}

-- Taps on each side of the centre; must match `weights[TAPS + 1]` in blur.glsl.
GlowMath.TAPS = 4

-- Half-resolution size, rounded up, at least 1x1.
function GlowMath.halfSize(width, height)
	return math.max(1, math.ceil(width / 2)), math.max(1, math.ceil(height / 2))
end

-- Distance between blur taps in half-res pixels. Radius is in virtual px, so
-- the halo scales with the game rectangle (fit.scale), not the window.
function GlowMath.tapSpacing(radius, fitScale)
	return math.max(1, radius * fitScale * 0.5 / GlowMath.TAPS)
end

-- Normalised gaussian weights for offsets 0..TAPS (centre counted once,
-- side taps twice, so the whole kernel sums to 1).
function GlowMath.weights()
	local taps = GlowMath.TAPS
	local sigma = taps / 2
	local w, sum = {}, 0
	for i = 0, taps do
		w[i + 1] = math.exp(-(i * i) / (2 * sigma * sigma))
		sum = sum + (i == 0 and w[i + 1] or 2 * w[i + 1])
	end
	for i = 1, taps + 1 do
		w[i] = w[i] / sum
	end
	return w
end

return GlowMath
