-- Snake world shape (docs/CONTEXT.md "Snake world"): a random turning polyline
-- widened into a simple polygon, giving L, U and S shapes. Draws only from the
-- `rng` passed in. Pure -- no `love.*`.
local Poly = require("src.core.poly")

local SnakeShape = {}

-- Polyline of cfg.snakeSegments segments starting at the origin: the first
-- heading is random, each later one turns by +/-90 degrees with chance
-- cfg.turn90Chance, else by a signed cfg.turnAngle draw.
local function polyline(rng, cfg)
	local count = rng:int(cfg.snakeSegments.min, cfg.snakeSegments.max)
	local heading = rng:range(0, 2 * math.pi)
	local points = { { x = 0, y = 0 } }
	for i = 1, count do
		if i > 1 then
			local turn = math.pi / 2
			if rng:next() >= cfg.turn90Chance then
				turn = rng:range(cfg.turnAngle.min, cfg.turnAngle.max)
			end
			if rng:next() < 0.5 then
				turn = -turn
			end
			heading = heading + turn
		end
		local length = rng:range(cfg.segmentLength.min, cfg.segmentLength.max)
		local last = points[#points]
		points[#points + 1] = { x = last.x + math.cos(heading) * length, y = last.y + math.sin(heading) * length }
	end
	return points
end

-- Left unit normal of each polyline segment.
local function segmentNormals(points)
	local normals = {}
	for i = 1, #points - 1 do
		local dx, dy = points[i + 1].x - points[i].x, points[i + 1].y - points[i].y
		local length = math.sqrt(dx * dx + dy * dy)
		normals[i] = { x = -dy / length, y = dx / length }
	end
	return normals
end

-- Offset of polyline point i to one side (side = 1 left, -1 right) by
-- `halfWidth`. Ends offset along their segment's normal; interior points along
-- the mitre (the normals' bisector), stretched so both offset edges keep
-- halfWidth and clamped to cfg.miterLimit x halfWidth at sharp turns.
local function offsetPoint(points, normals, i, side, halfWidth, cfg)
	local nx, ny, scale = 0, 0, 1
	if i == 1 then
		nx, ny = normals[1].x, normals[1].y
	elseif i == #points then
		nx, ny = normals[i - 1].x, normals[i - 1].y
	else
		local a, b = normals[i - 1], normals[i]
		nx, ny = a.x + b.x, a.y + b.y
		local length = math.sqrt(nx * nx + ny * ny)
		nx, ny = nx / length, ny / length
		scale = math.min(1 / (nx * a.x + ny * a.y), cfg.miterLimit)
	end
	return { x = points[i].x + side * nx * halfWidth * scale, y = points[i].y + side * ny * halfWidth * scale }
end

-- Left side forward then right side back, so the polygon is closed by the two
-- end caps.
local function widen(points, armWidth, cfg)
	local normals = segmentNormals(points)
	local vertices = {}
	for i = 1, #points do
		vertices[#vertices + 1] = offsetPoint(points, normals, i, 1, armWidth / 2, cfg)
	end
	for i = #points, 1, -1 do
		vertices[#vertices + 1] = offsetPoint(points, normals, i, -1, armWidth / 2, cfg)
	end
	return vertices
end

-- Returns a simple snake polygon (a plain vertex list) around the origin, or
-- nil when cfg.snakeRetries draws all came out self-touching.
function SnakeShape.generate(rng, config)
	local cfg = config.levelGen
	for _ = 1, cfg.snakeRetries do
		local armWidth = rng:range(cfg.armWidth.min, cfg.armWidth.max)
		local vertices = widen(polyline(rng, cfg), armWidth, cfg)
		for _, v in ipairs(vertices) do
			v.x = v.x + rng:range(-cfg.vertexJitter, cfg.vertexJitter)
			v.y = v.y + rng:range(-cfg.vertexJitter, cfg.vertexJitter)
		end
		if Poly.isSimple(vertices) then
			return vertices
		end
	end
	return nil
end

return SnakeShape
