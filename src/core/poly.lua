-- Polygon utilities over a plain list of {x, y} vertices, used for both
-- convex and concave worlds (docs/CONTEXT.md "World": not a sphere, no
-- holes). Pure functions only -- no `love.*`, no mutation of the input list
-- (docs/ARCHITECTURE.md "Layers").
--
-- Gotcha: y points down. A polygon wound counter-clockwise on paper is
-- clockwise on screen. Poly.area's shoelace sum is therefore positive for a
-- polygon that looks clockwise on screen; Poly.normalize picks that winding,
-- and Poly.outwardNormals assumes it.
local Vec2 = require("src.core.vec2")

local Poly = {}

-- Signed area via the shoelace formula. Positive when `points` is wound
-- clockwise on screen (see file header); negative for the other winding.
function Poly.area(points)
	local sum = 0
	local n = #points
	for i = 1, n do
		local p1 = points[i]
		local p2 = points[i % n + 1]
		sum = sum + (p1.x * p2.y - p2.x * p1.y)
	end
	return sum / 2
end

-- Polygon centroid (center of mass of the filled shape, not the vertex
-- average). Falls back to the vertex average for a degenerate (zero-area)
-- polygon, where the standard formula would divide by zero.
function Poly.centroid(points)
	local n = #points
	local area = Poly.area(points)

	if area == 0 then
		local sx, sy = 0, 0
		for _, p in ipairs(points) do
			sx = sx + p.x
			sy = sy + p.y
		end
		return { x = sx / n, y = sy / n }
	end

	local cx, cy = 0, 0
	for i = 1, n do
		local p1 = points[i]
		local p2 = points[i % n + 1]
		local cross = p1.x * p2.y - p2.x * p1.y
		cx = cx + (p1.x + p2.x) * cross
		cy = cy + (p1.y + p2.y) * cross
	end

	local factor = 1 / (6 * area)
	return { x = cx * factor, y = cy * factor }
end

-- Ray-casting point-in-polygon test. Winding-independent and correct for
-- concave shapes -- a point in a concave notch returns false even though
-- it's inside the bounding box.
function Poly.pointInPolygon(points, point)
	local n = #points
	local inside = false
	local j = n

	for i = 1, n do
		local pi, pj = points[i], points[j]
		if (pi.y > point.y) ~= (pj.y > point.y) then
			local xCross = (pj.x - pi.x) * (point.y - pi.y) / (pj.y - pi.y) + pi.x
			if point.x < xCross then
				inside = not inside
			end
		end
		j = i
	end

	return inside
end

local function orientation(p, q, r)
	local val = (q.y - p.y) * (r.x - q.x) - (q.x - p.x) * (r.y - q.y)
	if val > 0 then
		return 1
	elseif val < 0 then
		return 2
	end
	return 0
end

-- Assumes p, q, r are collinear; true when q lies on segment p-r.
local function onSegment(p, q, r)
	return q.x <= math.max(p.x, r.x)
		and q.x >= math.min(p.x, r.x)
		and q.y <= math.max(p.y, r.y)
		and q.y >= math.min(p.y, r.y)
end

-- True when segments p1-p2 and p3-p4 properly intersect or touch, including
-- the collinear-overlap case. Standard orientation-based segment test.
function Poly.segmentIntersect(p1, p2, p3, p4)
	local o1 = orientation(p1, p2, p3)
	local o2 = orientation(p1, p2, p4)
	local o3 = orientation(p3, p4, p1)
	local o4 = orientation(p3, p4, p2)

	if o1 ~= o2 and o3 ~= o4 then
		return true
	end

	if o1 == 0 and onSegment(p1, p3, p2) then
		return true
	end
	if o2 == 0 and onSegment(p1, p4, p2) then
		return true
	end
	if o3 == 0 and onSegment(p3, p1, p4) then
		return true
	end
	if o4 == 0 and onSegment(p3, p2, p4) then
		return true
	end

	return false
end

-- True when no two non-adjacent edges cross. Edges that share a vertex
-- (adjacent edges, and the wrap-around first/last pair) are skipped --
-- meeting at a shared endpoint is normal, not a self-intersection.
function Poly.isSimple(points)
	local n = #points
	if n < 3 then
		return false
	end

	for i = 1, n do
		local a1, a2 = points[i], points[i % n + 1]
		for j = i + 1, n do
			local b1, b2 = points[j], points[j % n + 1]
			local sharesVertex = (j == i + 1) or (i == 1 and j == n)
			if not sharesVertex then
				if Poly.segmentIntersect(a1, a2, b1, b2) then
					return false
				end
			end
		end
	end

	return true
end

-- Returns a new vertex list wound so Poly.area is positive (clockwise on
-- screen -- see file header). Never mutates `points`.
function Poly.normalize(points)
	if Poly.area(points) < 0 then
		local reversed = {}
		local n = #points
		for i = n, 1, -1 do
			table.insert(reversed, points[i])
		end
		return reversed
	end

	local copy = {}
	for i, p in ipairs(points) do
		copy[i] = p
	end
	return copy
end

-- One outward unit normal per edge (index i is the normal for the edge
-- points[i] -> points[i+1]). Assumes `points` is already Poly.normalize'd:
-- for that winding, rotating each edge vector by (e.y, -e.x) points away
-- from the interior, for convex and concave polygons alike.
function Poly.outwardNormals(points)
	local n = #points
	local normals = {}

	for i = 1, n do
		local p1 = points[i]
		local p2 = points[i % n + 1]
		local edge = Vec2.sub(p2, p1)
		normals[i] = Vec2.normalize({ x = edge.y, y = -edge.x })
	end

	return normals
end

return Poly
