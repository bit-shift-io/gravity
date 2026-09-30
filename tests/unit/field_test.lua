local Field = require("src.sim.field")
local Level = require("src.game.level")
local Config = require("src.game.config")
local FixtureLevel = require("src.game.levels.fixture_two_worlds")

local function square(x, y, size)
	return {
		{ x = x, y = y },
		{ x = x + size, y = y },
		{ x = x + size, y = y + size },
		{ x = x, y = y + size },
	}
end

-- A single square world, validated the same way MatchState.enter validates
-- a level before it's ever baked, so this exercises the exact vertex
-- winding and derived mass a real match would produce.
local function singleSquareLevel()
	-- Centered at origin: a square at (-240, -60) with size 100
	local level = { worlds = { { vertices = square(-240, -60, 100), density = 1 } } }
	Level.validate(level)
	return level
end

test("Field.sample points toward a single world's centroid from all four sides", function()
	local level = singleSquareLevel()
	local field = Field.bake(level, Config)
	-- Centered at origin: world square is at (-240, -60) with size 100, so centroid is at (-240, -60)
	local centroid = { x = -240, y = -60 }

	local above = Field.sample(field, centroid.x, -160)
	assertTrue(above.y > 0, "expected a sample above the world to be pulled downward (toward the centroid)")

	local below = Field.sample(field, centroid.x, 40)
	assertTrue(below.y < 0, "expected a sample below the world to be pulled upward (toward the centroid)")

	local left = Field.sample(field, -290, centroid.y)
	assertTrue(left.x > 0, "expected a sample left of the world to be pulled rightward (toward the centroid)")

	local right = Field.sample(field, -190, centroid.y)
	assertTrue(right.x < 0, "expected a sample right of the world to be pulled leftward (toward the centroid)")
end)

test("Field.sample magnitude falls off with distance from the world", function()
	local level = singleSquareLevel()
	local field = Field.bake(level, Config)

	-- World centroid at (-240, -60); sample near and far in the Y direction
	local near = Field.sample(field, -240, -100)  -- near the world (40 units away vertically)
	local far = Field.sample(field, -240, -210)   -- far from the world (150 units away vertically)

	assertTrue(math.abs(far.y) < math.abs(near.y), "expected a farther sample to feel a weaker pull")
end)

test("Field.sample has no discontinuity across a cell edge", function()
	local level = singleSquareLevel()
	local field = Field.bake(level, Config)

	-- A grid line sits at every multiple of cellSize away from minX/minY.
	-- Pick one a few cells above the world and straddle it by a tiny step,
	-- then compare against the change over a whole cell at the same spot:
	-- a genuine step discontinuity would show up as a jump on the same
	-- order as the whole-cell change; smooth interpolation shows a jump
	-- many orders of magnitude smaller (it's still a curving field, not a
	-- flat one, so it isn't exactly zero).
	local boundaryX = field.minX + 20 * field.cellSize
	local y = 250

	local justBefore = Field.sample(field, boundaryX - 0.01, y)
	local justAfter = Field.sample(field, boundaryX + 0.01, y)
	local tinyStepJump = math.abs(justAfter.x - justBefore.x)

	local oneCellBefore = Field.sample(field, boundaryX - field.cellSize / 2, y)
	local oneCellAfter = Field.sample(field, boundaryX + field.cellSize / 2, y)
	local wholeCellChange = math.abs(oneCellAfter.x - oneCellBefore.x)

	assertTrue(
		tinyStepJump < wholeCellChange * 0.01,
		string.format(
			"expected a 0.02px step to change ax far less than a whole cell does (0.02px jump: %.5f, whole-cell change: %.5f)",
			tinyStepJump,
			wholeCellChange
		)
	)
end)

test("Field.sample matches a cell's own baked value exactly at that cell's centre", function()
	local level = singleSquareLevel()
	local field = Field.bake(level, Config)

	local col, row = 10, 5
	local cell = field.cells[row * field.cols + col + 1]
	local sampled = Field.sample(field, cell.x, cell.y)

	assertNear(cell.ax, sampled.x)
	assertNear(cell.ay, sampled.y)
end)

test("Field.sample outside the grid clamps to the nearest edge cell instead of extrapolating", function()
	local level = singleSquareLevel()
	local field = Field.bake(level, Config)

	local edge = Field.sample(field, field.minX, 250)
	local farOutside = Field.sample(field, field.minX - 100000, 250)

	assertNear(edge.x, farOutside.x)
	assertNear(edge.y, farOutside.y)
end)

test("Field.sample is near zero midway between two equal worlds", function()
	-- Grid-aligned (positions and sizes are multiples of cellSize) so the
	-- rasterisation is symmetric between the two worlds and doesn't itself
	-- introduce the asymmetry this test is checking for.
	local level = {
		worlds = {
			{ vertices = square(128, 224, 320), density = 1 },
			{ vertices = square(832, 224, 320), density = 1 },
		},
	}
	Level.validate(level)
	local field = Field.bake(level, Config)

	local centerY = 224 + 160
	local midpoint = Field.sample(field, (128 + 160 + 832 + 160) / 2, centerY)
	local nearOneWorld = Field.sample(field, 128 + 160 - 80, centerY)

	local midMagnitude = math.sqrt(midpoint.x ^ 2 + midpoint.y ^ 2)
	local offMagnitude = math.sqrt(nearOneWorld.x ^ 2 + nearOneWorld.y ^ 2)

	assertTrue(midMagnitude < offMagnitude * 0.01, "expected the symmetric midpoint to be near-zero")
end)

test("Field.bake completes the fixture level under a 2s budget", function()
	local level = FixtureLevel.new()
	Level.validate(level)

	local start = os.clock()
	Field.bake(level, Config)
	local elapsed = os.clock() - start

	-- Expanded grid (to hard boundary at 640px) increases baking time; budget increased from 500ms to 2s
	assertTrue(elapsed < 2, string.format("expected bake under 2s, took %.3fs", elapsed))
end)

test("Field.bake returns both world and boundary fields", function()
	local level = singleSquareLevel()
	local worldField, boundaryField = Field.bake(level, Config)

	assertTrue(worldField ~= nil, "expected worldField to be returned")
	assertTrue(boundaryField ~= nil, "expected boundaryField to be returned")
	assertTrue(worldField.cells ~= nil, "expected worldField to have cells")
	assertTrue(boundaryField.cols ~= nil, "expected boundaryField to have cols (formula-based)")
	assertTrue(boundaryField.hardBoundary ~= nil, "expected boundaryField to have hardBoundary parameter")
end)

test("Field.bake grid extends to cover anti-gravity zone at hard boundary", function()
	local level = singleSquareLevel()
	local worldField = Field.bake(level, Config)

	-- Play area is 1280x720, anti-gravity zone is 50% play area width = 640px beyond edge
	local hardBoundary = 640
	local cellSize = Config.field.cellSize

	-- Grid should extend from -hardBoundary to 1280+hardBoundary in X
	-- and -hardBoundary to 720+hardBoundary in Y
	local expectedMinX = -hardBoundary
	local expectedMaxX = 1280 + hardBoundary
	local expectedMinY = -hardBoundary
	local expectedMaxY = 720 + hardBoundary

	assertNear(expectedMinX, worldField.minX, 0.000001, "expected worldField.minX to cover hard boundary")
	assertNear(expectedMinY, worldField.minY, 0.000001, "expected worldField.minY to cover hard boundary")

	-- Cell count should cover the full area
	local expectedWidth = expectedMaxX - expectedMinX
	local expectedHeight = expectedMaxY - expectedMinY
	local expectedCols = math.ceil(expectedWidth / cellSize)
	local expectedRows = math.ceil(expectedHeight / cellSize)

	assertEqual(expectedCols, worldField.cols, string.format("expected cols=%d, got %d", expectedCols, worldField.cols))
	assertEqual(expectedRows, worldField.rows, string.format("expected rows=%d, got %d", expectedRows, worldField.rows))
end)

test("Field boundary field samples correctly (zero inside, repulsive outside)", function()
	local level = singleSquareLevel()
	local worldField, boundaryField = Field.bake(level, Config)

	-- Inside play area, boundary field should be zero or very small
	-- Play area is centered at origin: -640 to 640 in X, -360 to 360 in Y
	local insideCenter = Field.sample(boundaryField, 0, 0)
	assertTrue(math.abs(insideCenter.x) < 1, "expected boundary field to be near zero at play area center")
	assertTrue(math.abs(insideCenter.y) < 1, "expected boundary field to be near zero at play area center")

	-- Outside play area (anti-gravity zone), boundary field should be repulsive (toward center)
	-- Sample from the anti-gravity zone on the right (beyond X = 640)
	local rightZone = Field.sample(boundaryField, 640 + 100, 0)
	assertTrue(rightZone.x < 0, "expected boundary field to repel leftward (toward center) from right zone")

	-- Sample from the anti-gravity zone on the left (beyond X = -640)
	local leftZone = Field.sample(boundaryField, -640 - 100, 0)
	assertTrue(leftZone.x > 0, "expected boundary field to repel rightward (toward center) from left zone")
end)
