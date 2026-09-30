-- Camera system: manages zoom level to fit both players with buffer in viewport.
-- Pure math -- no `love.*` calls -- so it is unit-testable directly.
-- src/app/states/match_state.lua applies the camera transform with love.graphics.
local Camera = {}

-- Create a new camera with default zoom and position
function Camera.new()
	return {
		x = 0,  -- Camera always centered at world origin
		y = 0,  -- Camera always centered at world origin
		zoom = 1.0,  -- Initial zoom level
	}
end

-- Calculate target zoom to fit both player positions with buffer in viewport.
-- Returns a zoom level that fits both players' buffer spheres in the viewport,
-- clamped between minimum (entire play area visible) and maximum (hard boundary visible).
--
-- Parameters:
--   pos1, pos2: player positions { x, y }
--   bufferRadius: additional radius around each player (pixels)
--   viewportWidth, viewportHeight: virtual resolution dimensions
--
-- Formula:
--   1. Find the furthest point from origin considering both players and their buffers
--   2. Calculate zoom needed to fit that distance in viewport: zoom = min(Vw, Vh) / (2 * maxDist)
--   3. Clamp zoom to [minZoom, maxZoom]
function Camera.calculateTargetZoom(pos1, pos2, bufferRadius, viewportWidth, viewportHeight)
	-- Constants from the game
	local PLAY_AREA_WIDTH = 1280
	local PLAY_AREA_HEIGHT = 720
	local HARD_BOUNDARY_RADIUS = 1280  -- Distance from origin to hard boundary

	-- Calculate distances from origin for each player plus buffer
	local dist1 = math.sqrt(pos1.x * pos1.x + pos1.y * pos1.y) + bufferRadius
	local dist2 = math.sqrt(pos2.x * pos2.x + pos2.y * pos2.y) + bufferRadius

	-- Max distance that needs to fit in viewport
	local maxDist = math.max(dist1, dist2)

	-- Unclamped target zoom: fit maxDist in viewport
	-- Zoom = viewportDimension / (2 * maxDist)
	local targetZoom = math.min(viewportWidth, viewportHeight) / (2 * maxDist)

	-- Zoom bounds:
	-- Maximum zoom level (most zoomed in): zoom until play area fits exactly on screen
	--   To fit the play area (1280x720) in viewport (1280x720): zoom = 1.0
	local maxZoomLevel = math.min(viewportWidth / PLAY_AREA_WIDTH, viewportHeight / PLAY_AREA_HEIGHT)

	-- Minimum zoom level (most zoomed out): zoom out until hard boundary fits on screen
	--   Hard boundary is a circle with radius 1280 at origin
	--   To fit diameter 2560 in viewport: zoom = min(Vw, Vh) / 2560
	local minZoomLevel = math.min(viewportWidth, viewportHeight) / (2 * HARD_BOUNDARY_RADIUS)

	-- Clamp target zoom to valid range [minZoomLevel, maxZoomLevel]
	return math.max(minZoomLevel, math.min(maxZoomLevel, targetZoom))
end

-- Update camera zoom toward target zoom with smooth interpolation.
-- Uses linear interpolation: newZoom = oldZoom + (target - oldZoom) * speed * dt
--
-- Parameters:
--   camera: camera table with zoom field
--   targetZoom: desired zoom level
--   zoomSpeed: interpolation speed (units per second)
--   dt: delta time since last frame (seconds)
function Camera.updateZoom(camera, targetZoom, zoomSpeed, dt)
	local diff = targetZoom - camera.zoom
	camera.zoom = camera.zoom + diff * zoomSpeed * dt
end

return Camera
