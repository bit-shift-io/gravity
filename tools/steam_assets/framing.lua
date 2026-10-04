-- Pure framing math (no `love.*`): where the world and the 1280x720 screen
-- space land in an output of any size. The UI scale fits the virtual
-- resolution inside the output (height-bound at 16:9 and wider, so a wide
-- output shows more world sideways); the world scale adds the camera zoom.
local Framing = {}

local VIRTUAL_WIDTH = 1280
local VIRTUAL_HEIGHT = 720

-- { centreX, centreY, uiScale, worldScale } for an output of width x height.
function Framing.transform(width, height, camera)
	local uiScale = math.min(width / VIRTUAL_WIDTH, height / VIRTUAL_HEIGHT)
	return {
		centreX = width / 2,
		centreY = height / 2,
		uiScale = uiScale,
		worldScale = uiScale * camera.zoom,
	}
end

-- Output pixel of world point (wx, wy) for `camera`; the camera focus point
-- lands on the output centre.
function Framing.project(width, height, camera, wx, wy)
	local f = Framing.transform(width, height, camera)
	return f.centreX + (wx - camera.x) * f.worldScale, f.centreY + (wy - camera.y) * f.worldScale
end

-- Top-left offsets (virtual units) of the 1280x720 starfield tiles needed to
-- cover an output at `uiScale`; the starfield only fills one screen. `col` and
-- `row` let the caller vary each tile so the pattern does not visibly repeat.
function Framing.starTiles(width, height, uiScale)
	local cols = math.ceil(width / uiScale / VIRTUAL_WIDTH - 1e-9)
	local rows = math.ceil(height / uiScale / VIRTUAL_HEIGHT - 1e-9)
	local tiles = {}
	for row = 0, rows - 1 do
		for col = 0, cols - 1 do
			tiles[#tiles + 1] = { x = col * VIRTUAL_WIDTH, y = row * VIRTUAL_HEIGHT, col = col, row = row }
		end
	end
	return tiles
end

return Framing
