-- World line width: how thick outlines draw under the camera zoom, and the
-- user's "line thickness" multiplier. Pure -- no `love.*` -- so it is
-- unit-testable; src/app/states/match_state.lua applies the result with
-- love.graphics. Rendering only, never the sim.
local LineWidth = {}

-- Cycle order for the settings LINES row.
LineWidth.STEPS = { 1, 1.5, 2, 3 }
LineWidth.DEFAULT = 1.5

-- Zoom shrinks every line, so a zoomed-out world draws sub-pixel outlines.
-- Dividing by zoom^EXPONENT gives it back: 1 keeps the on-screen width
-- constant, 0 ignores zoom. 0.5 keeps lines readable without outgrowing the
-- shrunken ships.
LineWidth.ZOOM_EXPONENT = 0.5

function LineWidth.isValid(thickness)
	for _, step in ipairs(LineWidth.STEPS) do
		if step == thickness then
			return true
		end
	end
	return false
end

-- The step after `thickness`, wrapping back to the first.
function LineWidth.next(thickness)
	for i, step in ipairs(LineWidth.STEPS) do
		if step == thickness then
			return LineWidth.STEPS[i % #LineWidth.STEPS + 1]
		end
	end
	return LineWidth.STEPS[1]
end

-- Line width in world units for a world drawn at `zoom` (pixels per world
-- unit). `thickness` defaults to 1 (the Steam capture tools pass none).
function LineWidth.world(zoom, thickness)
	return (thickness or 1) / zoom ^ LineWidth.ZOOM_EXPONENT
end

return LineWidth
