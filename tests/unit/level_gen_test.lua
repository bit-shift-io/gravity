local LevelGen = require("src.game.level_gen")
local Level = require("src.game.level")
local Config = require("src.game.config")
local Poly = require("src.core.poly")
local SpawnPoints = require("src.game.spawn_points")

local SEEDS = 200

local function eachSeed(fn)
	for seed = 1, SEEDS do
		fn(seed, LevelGen.generate(seed, Config))
	end
end

test("LevelGen.generate returns a validated level of 1 to 3 worlds for 200 seeds", function()
	eachSeed(function(seed, level)
		local ok, err = Level.validate(level)
		assertTrue(ok, "seed " .. seed .. ": " .. tostring(err))
		assertTrue(#level.worlds >= 1 and #level.worlds <= 3, "seed " .. seed .. " world count")
	end)
end)

test("LevelGen.generate keeps every world inside the play area edge margin", function()
	local cfg = Config.levelGen
	local limitX = cfg.playWidth / 2 - cfg.edgeMargin
	local limitY = cfg.playHeight / 2 - cfg.edgeMargin
	eachSeed(function(seed, level)
		for _, world in ipairs(level.worlds) do
			for _, v in ipairs(world.vertices) do
				assertTrue(math.abs(v.x) <= limitX and math.abs(v.y) <= limitY, "seed " .. seed .. " vertex outside margin")
			end
		end
	end)
end)

test("LevelGen.generate keeps the min gap between worlds, so none overlap", function()
	eachSeed(function(seed, level)
		for i = 1, #level.worlds - 1 do
			for j = i + 1, #level.worlds do
				local d = LevelGen.polygonDistance(level.worlds[i].vertices, level.worlds[j].vertices)
				assertTrue(d >= Config.levelGen.minGap, "seed " .. seed .. " gap " .. d)
			end
		end
	end)
end)

test("LevelGen.polygonDistance is zero for crossing or nested polygons and measures a gap otherwise", function()
	local function square(x, y, size)
		return { { x = x, y = y }, { x = x + size, y = y }, { x = x + size, y = y + size }, { x = x, y = y + size } }
	end
	assertEqual(0, LevelGen.polygonDistance(square(0, 0, 10), square(5, 5, 10)))
	assertEqual(0, LevelGen.polygonDistance(square(0, 0, 100), square(40, 40, 10)))
	assertEqual(7, LevelGen.polygonDistance(square(0, 0, 10), square(17, 0, 10)))
end)

local function deepEqual(a, b)
	if type(a) ~= "table" or type(b) ~= "table" then
		return a == b
	end
	for k, v in pairs(a) do
		if not deepEqual(v, b[k]) then
			return false
		end
	end
	for k in pairs(b) do
		if a[k] == nil then
			return false
		end
	end
	return true
end

test("LevelGen.generate gives a deeply equal level for the same seed", function()
	for seed = 1, 20 do
		assertTrue(deepEqual(LevelGen.generate(seed, Config), LevelGen.generate(seed, Config)), "seed " .. seed)
	end
end)

test("LevelGen.generate gives different levels for different seeds", function()
	assertTrue(not deepEqual(LevelGen.generate(1, Config), LevelGen.generate(2, Config)))
end)

test("LevelGen.generate draws per-world density and asteroid maxAlive within config ranges", function()
	local cfg = Config.levelGen
	local densities = {}
	eachSeed(function(seed, level)
		assertTrue(level.asteroids.maxAlive >= cfg.maxAlive.min and level.asteroids.maxAlive <= cfg.maxAlive.max)
		for _, world in ipairs(level.worlds) do
			assertTrue(world.density >= cfg.density.min and world.density <= cfg.density.max)
			densities[world.density] = true
		end
	end)
	local distinct = 0
	for _ in pairs(densities) do
		distinct = distinct + 1
	end
	assertTrue(distinct > 1, "density should vary")
end)

test("LevelGen.generate chooses two spawn points on its own worlds", function()
	eachSeed(function(seed, level)
		assertEqual(2, #level.spawnPoints)
		for _, point in ipairs(level.spawnPoints) do
			assertTrue(point.normal ~= nil, "seed " .. seed .. " spawn needs a normal")
			local hosted = false
			for _, world in ipairs(level.worlds) do
				hosted = hosted or point.world == world
			end
			assertTrue(hosted, "seed " .. seed .. " spawn host must be a level world")
		end
	end)
end)

test("LevelGen.generate falls back to fewer worlds and terminates when the gap is impossible", function()
	local config = { levelGen = {} }
	for k, v in pairs(Config.levelGen) do
		config.levelGen[k] = v
	end
	config.levelGen.minGap = 100000
	for k, v in pairs(Config) do
		config[k] = config[k] or v
	end
	for seed = 1, 20 do
		local level = LevelGen.generate(seed, config)
		assertEqual(1, #level.worlds)
		assertTrue(Level.validate(level))
	end
end)

-- Config copy whose levelGen section has `overrides` applied.
local function configWith(overrides)
	local config = {}
	for k, v in pairs(Config) do
		config[k] = v
	end
	config.levelGen = {}
	for k, v in pairs(Config.levelGen) do
		config.levelGen[k] = v
	end
	for k, v in pairs(overrides) do
		config.levelGen[k] = v
	end
	return config
end

-- True when some vertex turns against the polygon's winding.
local function hasReflexVertex(vertices)
	local sign = Poly.area(vertices) > 0 and 1 or -1
	local n = #vertices
	for i = 1, n do
		local a, b, c = vertices[(i - 2) % n + 1], vertices[i], vertices[i % n + 1]
		local cross = (b.x - a.x) * (c.y - b.y) - (b.y - a.y) * (c.x - b.x)
		if cross * sign < -1e-6 then
			return true
		end
	end
	return false
end

test("LevelGen.generate notches some blobs concave and keeps every world simple", function()
	-- Noise-free blobs are convex, so any reflex vertex comes from a notch.
	local config = configWith({ noiseAmplitude = 0, snakeChance = 0 })
	local concave = 0
	for seed = 1, SEEDS do
		local level = LevelGen.generate(seed, config)
		assertTrue(Level.validate(level))
		for _, world in ipairs(level.worlds) do
			assertTrue(Poly.isSimple(world.vertices), "seed " .. seed .. " world not simple")
			if hasReflexVertex(world.vertices) then
				concave = concave + 1
			end
		end
	end
	assertTrue(concave > 0, "no notched world in " .. SEEDS .. " seeds")
end)

test("LevelGen.generate rejects a notch forced past self-intersection and keeps the blob simple", function()
	-- Depth 1.5 throws the pulled vertices across the centre, crossing edges.
	local config = configWith({ noiseAmplitude = 0, snakeChance = 0, notchChance = 1, notchDepth = { min = 1.5, max = 1.5 } })
	for seed = 1, 50 do
		local level = LevelGen.generate(seed, config)
		assertTrue(#level.worlds >= 1, "seed " .. seed .. " lost its worlds to rejected notches")
		for _, world in ipairs(level.worlds) do
			assertTrue(Poly.isSimple(world.vertices), "seed " .. seed .. " world not simple")
			assertTrue(not hasReflexVertex(world.vertices), "seed " .. seed .. " accepted a self-crossing notch")
		end
	end
end)

test("LevelGen.generate keeps spawn clearance on heavily notched worlds", function()
	local config = configWith({ notchChance = 1 })
	for seed = 1, SEEDS do
		local level = LevelGen.generate(seed, config)
		assertTrue(level.spawnPoints ~= nil, "seed " .. seed .. " has no spawn points")
		for _, point in ipairs(level.spawnPoints) do
			assertTrue(SpawnPoints.hasClearance(level.worlds, point, config), "seed " .. seed .. " spawn lacks clearance")
		end
	end
end)

-- A snake has 2 vertices per polyline point (6-10); a blob has at least vertexCount.min.
local function isSnake(world)
	return #world.vertices < Config.levelGen.vertexCount.min
end

test("LevelGen.generate mixes snake worlds with blobs and validates every level", function()
	local snakes, blobs = 0, 0
	eachSeed(function(seed, level)
		assertTrue(Level.validate(level))
		for _, world in ipairs(level.worlds) do
			assertTrue(Poly.isSimple(world.vertices), "seed " .. seed .. " world not simple")
			if isSnake(world) then
				snakes = snakes + 1
			else
				blobs = blobs + 1
			end
		end
	end)
	assertTrue(snakes > 0, "no snake world in " .. SEEDS .. " seeds")
	assertTrue(blobs > 0, "no blob world in " .. SEEDS .. " seeds")
end)

test("LevelGen.generate with only snakes keeps them in the margin, apart, and spawnable", function()
	local config = configWith({ snakeChance = 1 })
	local cfg = config.levelGen
	local limitX = cfg.playWidth / 2 - cfg.edgeMargin
	local limitY = cfg.playHeight / 2 - cfg.edgeMargin
	for seed = 1, SEEDS do
		local level = LevelGen.generate(seed, config)
		assertTrue(Level.validate(level))
		assertTrue(level.spawnPoints ~= nil, "seed " .. seed .. " has no spawn points")
		for i, world in ipairs(level.worlds) do
			assertTrue(isSnake(world), "seed " .. seed .. " world is not a snake")
			assertTrue(Poly.isSimple(world.vertices), "seed " .. seed .. " world not simple")
			for _, v in ipairs(world.vertices) do
				assertTrue(math.abs(v.x) <= limitX and math.abs(v.y) <= limitY, "seed " .. seed .. " vertex outside margin")
			end
			for j = i + 1, #level.worlds do
				assertTrue(LevelGen.polygonDistance(world.vertices, level.worlds[j].vertices) >= cfg.minGap, "seed " .. seed .. " gap")
			end
		end
		for _, point in ipairs(level.spawnPoints) do
			assertTrue(SpawnPoints.hasClearance(level.worlds, point, config), "seed " .. seed .. " spawn lacks clearance")
		end
	end
end)
