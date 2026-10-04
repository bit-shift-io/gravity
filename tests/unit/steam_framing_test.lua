local Framing = require("tools.steam_assets.framing")

test("Framing at 16:9 centres the camera and scales by output height over 720", function()
	local f = Framing.transform(1920, 1080, { x = 10, y = 20, zoom = 1 })
	assertEqual(960, f.centreX)
	assertEqual(540, f.centreY)
	assertNear(1.5, f.uiScale, 1e-9)
	assertNear(1.5, f.worldScale, 1e-9)
end)

test("Framing multiplies the world scale by camera zoom, not the UI scale", function()
	local f = Framing.transform(1920, 1080, { x = 0, y = 0, zoom = 0.5 })
	assertNear(1.5, f.uiScale, 1e-9)
	assertNear(0.75, f.worldScale, 1e-9)
end)

test("Framing at a wide ratio fits the height and shows more width", function()
	local f = Framing.transform(3840, 1240, { x = 0, y = 0, zoom = 1 })
	assertEqual(1920, f.centreX)
	assertEqual(620, f.centreY)
	assertNear(1240 / 720, f.uiScale, 1e-9)
end)

test("Framing at a tall ratio fits the width", function()
	local f = Framing.transform(600, 900, { x = 0, y = 0, zoom = 1 })
	assertNear(600 / 1280, f.uiScale, 1e-9)
end)

test("Framing.project puts the camera focus point at the output centre at 748x896", function()
	local camera = { x = 300, y = -120, zoom = 2 }
	local sx, sy = Framing.project(748, 896, camera, 300, -120)
	assertNear(374, sx, 1e-9)
	assertNear(448, sy, 1e-9)
end)

test("Framing.project puts the camera focus point at the output centre at 3840x1240", function()
	local camera = { x = -50, y = 80, zoom = 1.3 }
	local sx, sy = Framing.project(3840, 1240, camera, -50, 80)
	assertNear(1920, sx, 1e-9)
	assertNear(620, sy, 1e-9)
end)

test("Framing.project offsets a point by world distance times world scale", function()
	local camera = { x = 0, y = 0, zoom = 2 }
	local sx, sy = Framing.project(1280, 720, camera, 100, -50)
	assertNear(640 + 200, sx, 1e-9)
	assertNear(360 - 100, sy, 1e-9)
end)

test("Framing.starTiles covers the output with 1280x720 starfield tiles", function()
	local f = Framing.transform(1280, 720, { zoom = 1 })
	assertEqual(1, #Framing.starTiles(1280, 720, f.uiScale))
	-- Hero: 3840x1240 is 2230x720 virtual, so two tiles across and one down.
	f = Framing.transform(3840, 1240, { zoom = 1 })
	assertEqual(2, #Framing.starTiles(3840, 1240, f.uiScale))
	-- Vertical: 748x896 is 1280x1534 virtual, so one across and three down.
	f = Framing.transform(748, 896, { zoom = 1 })
	assertEqual(3, #Framing.starTiles(748, 896, f.uiScale))
end)

test("Framing.starTiles gives each tile its own offset and index", function()
	local tiles = Framing.starTiles(3840, 1240, Framing.transform(3840, 1240, { zoom = 1 }).uiScale)
	assertEqual(0, tiles[1].x)
	assertEqual(1280, tiles[2].x)
	assertEqual(0, tiles[2].y)
	assertTrue(tiles[1].col ~= tiles[2].col)
end)
