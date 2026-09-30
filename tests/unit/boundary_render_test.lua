local Match = require("src.game.match")
local Config = require("src.game.config")

test("boundary field has correct parameters for rendering", function()
	local ctx = Match.new({ worlds = {} }, Config)
	local bf = ctx.sim.boundaryField

	-- Hard boundary is a circle with radius = play area edge (640) + boundary distance (640) = 1280
	-- Play area is centered at origin: ±640 in X, ±360 in Y
	assertEqual(-640, bf.playAreaMinX)
	assertEqual(640, bf.playAreaMaxX)
	assertEqual(-360, bf.playAreaMinY)
	assertEqual(360, bf.playAreaMaxY)
	assertEqual(1280, bf.hardBoundary)  -- Total radius from origin, not just the distance beyond edge

	-- The hard boundary radius IS the hardBoundary value
	local expectedRadius = bf.hardBoundary
	assertEqual(1280, expectedRadius)
end)
