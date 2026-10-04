-- Easing curves over t in [0, 1]. Pure; no `love.*`.
local Ease = {}

-- Cubic ease-out: fast start, slow finish.
function Ease.easeOut(t)
	return 1 - (1 - t) ^ 3
end

return Ease
