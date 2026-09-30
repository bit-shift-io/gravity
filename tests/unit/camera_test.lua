local Camera = require("src.app.camera")
local Config = require("src.game.config")

local VIRTUAL_WIDTH = 1280
local VIRTUAL_HEIGHT = 720
local PLAY_AREA_MIN_X = 0
local PLAY_AREA_MAX_X = 1280
local PLAY_AREA_MIN_Y = 0
local PLAY_AREA_MAX_Y = 720
local HARD_BOUNDARY_RADIUS = 1280

-- Target zoom calculation: two players close together
test("Camera.calculateTargetZoom with two players close together fits both with buffer", function()
	local pos1 = { x = 0, y = 0 }
	local pos2 = { x = 100, y = 100 }
	local bufferRadius = 50

	local targetZoom = Camera.calculateTargetZoom(pos1, pos2, bufferRadius, VIRTUAL_WIDTH, VIRTUAL_HEIGHT)

	-- When two players are very close, the max distance is roughly bufferRadius
	-- The zoom must fit both buffers (distance to furthest point from origin)
	-- Expected max distance: sqrt(100^2 + 100^2) + 50 ≈ 191.4
	-- Zoom to fit: min(1280 / 382.8, 720 / 382.8) ≈ 1.88
	assertTrue(targetZoom > 0, "zoom should be positive")
	assertTrue(targetZoom < 2, "zoom for close players should be less than 2")
end)

-- Target zoom calculation: two players far apart
test("Camera.calculateTargetZoom with two players far apart increases zoom", function()
	local pos1 = { x = -300, y = -200 }
	local pos2 = { x = 300, y = 200 }
	local bufferRadius = 50

	local targetZoomClose = Camera.calculateTargetZoom({ x = 0, y = 0 }, { x = 100, y = 100 }, 50, VIRTUAL_WIDTH, VIRTUAL_HEIGHT)
	local targetZoomFar = Camera.calculateTargetZoom(pos1, pos2, bufferRadius, VIRTUAL_WIDTH, VIRTUAL_HEIGHT)

	-- Further players should require a smaller zoom (more of the world visible)
	assertTrue(targetZoomFar < targetZoomClose, "farther players should require smaller zoom")
	assertTrue(targetZoomFar > 0, "zoom should still be positive")
end)

-- Target zoom calculation: one player at boundary
test("Camera.calculateTargetZoom with one player at hard boundary respects max zoom", function()
	-- Hard boundary is a circle at origin with radius 1280
	-- A player at the edge of the boundary plus buffer
	local pos1 = { x = 0, y = 0 }
	local pos2 = { x = 1280, y = 0 }  -- At hard boundary edge
	local bufferRadius = 50

	local targetZoom = Camera.calculateTargetZoom(pos1, pos2, bufferRadius, VIRTUAL_WIDTH, VIRTUAL_HEIGHT)

	-- Max distance from origin: 1280 + 50 = 1330
	-- Zoom to fit: min(1280 / 2660, 720 / 2660) ≈ 0.27
	assertTrue(targetZoom > 0, "zoom should be positive")
	assertTrue(targetZoom < 0.5, "zoom with boundary player should be small")
end)

-- Zoom clamping: respects minimum zoom
test("Camera.calculateTargetZoom respects minimum zoom (entire play area visible)", function()
	local pos1 = { x = 0, y = 0 }
	local pos2 = { x = 0, y = 0 }
	local bufferRadius = 10

	local targetZoom = Camera.calculateTargetZoom(pos1, pos2, bufferRadius, VIRTUAL_WIDTH, VIRTUAL_HEIGHT)

	-- Minimum zoom should fit the entire play area (1280x720)
	-- Min zoom = min(1280 / 1280, 720 / 720) = 1.0
	assertTrue(targetZoom >= 1.0, "zoom should be at least 1.0 to fit play area")
end)

-- Zoom clamping: respects maximum zoom
test("Camera.calculateTargetZoom respects maximum zoom (hard boundary visible)", function()
	-- If both players are inside a small area, the unclamped zoom might exceed max
	-- We clamp at the play area boundary, not at the hard boundary
	local pos1 = { x = 0, y = 0 }
	local pos2 = { x = 50, y = 50 }
	local bufferRadius = 10

	local targetZoom = Camera.calculateTargetZoom(pos1, pos2, bufferRadius, VIRTUAL_WIDTH, VIRTUAL_HEIGHT)

	-- Maximum zoom is clamped to fit the play area (1280x720) = zoom 1.0
	assertTrue(targetZoom <= 1.0, "zoom should be clamped to max of 1.0 (play area fits on screen)")
	-- For very close players, we should be at or near the max zoom
	assertTrue(targetZoom >= 0.8, "zoom for close players should be fairly high")
end)

-- Smooth transitions: zoom interpolates toward target
test("Camera.updateZoom interpolates toward target zoom", function()
	local camera = Camera.new()
	camera.zoom = 1.0
	local targetZoom = 0.5
	local zoomSpeed = 2.0
	local dt = 0.1

	Camera.updateZoom(camera, targetZoom, zoomSpeed, dt)

	-- Should move toward target: newZoom = oldZoom + (target - oldZoom) * speed * dt
	-- newZoom = 1.0 + (0.5 - 1.0) * 2.0 * 0.1 = 1.0 - 0.1 = 0.9
	assertTrue(camera.zoom > 1.0 * (1 - zoomSpeed * dt), "zoom should move toward target")
	assertTrue(camera.zoom < 1.0, "zoom should not overshoot in the direction of target")
end)

-- Smooth transitions: converges toward target
test("Camera.updateZoom converges to target over multiple frames", function()
	local camera = Camera.new()
	camera.zoom = 1.0
	local targetZoom = 0.5
	local zoomSpeed = 5.0  -- Higher speed constant for exponential convergence

	-- Run 300 frames (~5 seconds at 60 FPS) to reach target
	for i = 1, 300 do
		Camera.updateZoom(camera, targetZoom, zoomSpeed, 0.016)
	end

	-- With zoomSpeed = 5.0, the difference decays by (1 - 5*0.016)^n = 0.92^n
	-- After 300 frames: 0.5 * 0.92^300 is essentially 0
	assertTrue(math.abs(camera.zoom - targetZoom) < 0.01, "should converge to target zoom")
end)

-- Integration: camera center and zoom work together
test("Camera.new initializes with sensible defaults", function()
	local camera = Camera.new()

	assertTrue(camera.zoom ~= nil, "camera should have zoom")
	assertTrue(camera.x ~= nil, "camera should have x position")
	assertTrue(camera.y ~= nil, "camera should have y position")
	assertTrue(camera.zoom > 0, "zoom should be positive")
	assertEqual(0, camera.x, "camera should be centered at origin x")
	assertEqual(0, camera.y, "camera should be centered at origin y")
end)

-- Regression: camera position is always at origin
test("Camera stays centered on play area origin", function()
	local camera = Camera.new()
	local pos1 = { x = 300, y = 200 }
	local pos2 = { x = -200, y = -300 }
	local bufferRadius = 50

	-- Update camera with new player positions
	local targetZoom = Camera.calculateTargetZoom(pos1, pos2, bufferRadius, VIRTUAL_WIDTH, VIRTUAL_HEIGHT)
	Camera.updateZoom(camera, targetZoom, 2.0, 0.016)

	-- Camera center should remain at origin
	assertEqual(0, camera.x, "camera x should remain at origin")
	assertEqual(0, camera.y, "camera y should remain at origin")
end)
