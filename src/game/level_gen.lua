-- Procedural level generation (docs/CONTEXT.md "Blob world", "Seed"): turns a
-- seed into a plain level table of 1-3 blob or snake worlds. Uses its own
-- Rng stream built from the seed, so the same seed always gives the same level
-- and generation never disturbs the match's own rng. Pure -- no `love.*`.
local Rng = require("src.core.rng")
local Poly = require("src.core.poly")
local Level = require("src.game.level")
local SpawnPoints = require("src.game.spawn_points")
local SnakeShape = require("src.game.snake_shape")

local LevelGen = {}

local function pointSegmentDistance(p, a, b)
	local dx, dy = b.x - a.x, b.y - a.y
	local lengthSquared = dx * dx + dy * dy
	local t = 0
	if lengthSquared > 0 then
		t = math.max(0, math.min(1, ((p.x - a.x) * dx + (p.y - a.y) * dy) / lengthSquared))
	end
	local cx, cy = a.x + dx * t, a.y + dy * t
	return math.sqrt((p.x - cx) ^ 2 + (p.y - cy) ^ 2)
end

-- Shortest distance between the boundaries of two simple polygons, or 0 when
-- they cross or one contains the other.
function LevelGen.polygonDistance(a, b)
	local best = math.huge
	for i, p1 in ipairs(a) do
		local p2 = a[i % #a + 1]
		for j, q1 in ipairs(b) do
			local q2 = b[j % #b + 1]
			if Poly.segmentIntersect(p1, p2, q1, q2) then
				return 0
			end
			best = math.min(best, pointSegmentDistance(p1, q1, q2), pointSegmentDistance(q1, p1, p2))
		end
	end
	if Poly.pointInPolygon(b, a[1]) or Poly.pointInPolygon(a, b[1]) then
		return 0
	end
	return best
end

-- Pulls a run of adjacent vertices toward (cx, cy) to cut a notch. Returns
-- true when the notch was applied and the polygon is still simple; otherwise
-- restores the vertices and returns false.
local function tryNotch(rng, cfg, vertices, cx, cy)
	local count = rng:int(cfg.notchVertices.min, cfg.notchVertices.max)
	local depth = rng:range(cfg.notchDepth.min, cfg.notchDepth.max)
	local first = rng:int(1, #vertices)
	local original = {}
	for k = 0, count - 1 do
		local i = (first + k - 1) % #vertices + 1
		local v = vertices[i]
		original[i] = v
		vertices[i] = { x = v.x + (cx - v.x) * depth, y = v.y + (cy - v.y) * depth }
	end
	if Poly.isSimple(vertices) then
		return true
	end
	for i, v in pairs(original) do
		vertices[i] = v
	end
	return false
end

-- A radial-noise blob: vertexCount points evenly spaced in angle around
-- (cx, cy), each at radius x (1 +/- noiseAmplitude). Radii stay positive, so
-- the plain blob is star-shaped and therefore simple. Sometimes a notch is cut
-- in (see tryNotch), kept only when the result is still simple.
local function blobVertices(rng, cfg, cx, cy)
	local count = rng:int(cfg.vertexCount.min, cfg.vertexCount.max)
	local radius = rng:range(cfg.radius.min, cfg.radius.max)
	local vertices = {}
	for i = 1, count do
		local angle = (i - 1) / count * 2 * math.pi
		local r = radius * (1 + cfg.noiseAmplitude * (rng:next() * 2 - 1))
		vertices[i] = { x = cx + math.cos(angle) * r, y = cy + math.sin(angle) * r }
	end
	if rng:next() < cfg.notchChance then
		for _ = 1, cfg.notchRetries do
			if tryNotch(rng, cfg, vertices, cx, cy) then
				break
			end
		end
	end
	return vertices
end

local function insideMargin(vertices, limitX, limitY)
	for _, v in ipairs(vertices) do
		if math.abs(v.x) > limitX or math.abs(v.y) > limitY then
			return false
		end
	end
	return true
end

local function clearOfWorlds(vertices, worlds, minGap)
	for _, world in ipairs(worlds) do
		if LevelGen.polygonDistance(vertices, world.vertices) < minGap then
			return false
		end
	end
	return true
end

-- A snake (see SnakeShape) slid to a random spot where its bounding box sits
-- inside the margin; nil when no snake could be drawn or it is too big to fit.
local function snakeVertices(rng, config, limitX, limitY)
	local vertices = SnakeShape.generate(rng, config)
	if not vertices then
		return nil
	end
	local minX, maxX, minY, maxY = math.huge, -math.huge, math.huge, -math.huge
	for _, v in ipairs(vertices) do
		minX, maxX = math.min(minX, v.x), math.max(maxX, v.x)
		minY, maxY = math.min(minY, v.y), math.max(maxY, v.y)
	end
	if maxX - minX > 2 * limitX or maxY - minY > 2 * limitY then
		return nil
	end
	local dx = rng:range(-limitX - minX, limitX - maxX)
	local dy = rng:range(-limitY - minY, limitY - maxY)
	for i, v in ipairs(vertices) do
		vertices[i] = { x = v.x + dx, y = v.y + dy }
	end
	return vertices
end

-- Tries up to cfg.placementRetries random worlds (a snake with chance
-- cfg.snakeChance, else a blob) for one more world; returns its vertices, or
-- nil when none fit.
local function placeWorld(rng, config, worlds)
	local cfg = config.levelGen
	local limitX = cfg.playWidth / 2 - cfg.edgeMargin
	local limitY = cfg.playHeight / 2 - cfg.edgeMargin
	for _ = 1, cfg.placementRetries do
		local vertices
		if rng:next() < cfg.snakeChance then
			vertices = snakeVertices(rng, config, limitX, limitY)
		else
			vertices = blobVertices(rng, cfg, rng:range(-limitX, limitX), rng:range(-limitY, limitY))
		end
		if vertices and Poly.isSimple(vertices) and insideMargin(vertices, limitX, limitY) and clearOfWorlds(vertices, worlds, cfg.minGap) then
			return vertices
		end
	end
	return nil
end

-- Returns a validated level `{ worlds, spawnPoints, asteroids }` for `seed`.
-- Aims for a random world count in cfg.worldCount; when a world can't be
-- placed within the retry cap, the level keeps the worlds it has (at least
-- one, whenever the first world fits the play area).
function LevelGen.generate(seed, config)
	local cfg = config.levelGen
	local rng = Rng.new(seed)
	local target = rng:int(cfg.worldCount.min, cfg.worldCount.max)

	local worlds = {}
	while #worlds < target do
		local vertices = placeWorld(rng, config, worlds)
		if not vertices then
			break
		end
		worlds[#worlds + 1] = { vertices = vertices, density = rng:range(cfg.density.min, cfg.density.max) }
	end

	local level = {
		worlds = worlds,
		asteroids = { maxAlive = rng:int(cfg.maxAlive.min, cfg.maxAlive.max) },
	}
	assert(Level.validate(level))
	level.spawnCandidates = SpawnPoints.cleared(level.worlds, config)
	level.spawnPoints = SpawnPoints.choose(level.worlds, config, level.spawnCandidates)
	return level
end

return LevelGen
