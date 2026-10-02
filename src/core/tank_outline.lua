-- Merges a tank's dome polygon and its turret barrel into one outline, so
-- the tank draws as a single shape with no line crossing the dome. Pure
-- geometry over plain {x, y} tables -- no `love.*` (docs/ARCHITECTURE.md
-- "Layers"). Everything is in the dome's local space; the caller rotates the
-- result by the body angle.
local TankOutline = {}

-- Where the ray `origin + dir * t` leaves the convex `dome` (origin must be
-- inside it). Returns the edge position s = edgeIndex - 1 + u (u in [0, 1]
-- along the edge), the point, and t -- or nil if no edge is hit.
local function exitPoint(dome, origin, dir)
	local n = #dome
	local bestT, bestS
	for i = 1, n do
		local a = dome[i]
		local b = dome[i % n + 1]
		local ex, ey = b.x - a.x, b.y - a.y
		local denom = dir.x * ey - dir.y * ex
		if denom ~= 0 then
			local px, py = a.x - origin.x, a.y - origin.y
			local t = (px * ey - py * ex) / denom
			local u = (px * dir.y - py * dir.x) / denom
			if t > 0 and u >= 0 and u <= 1 and (not bestT or t > bestT) then
				bestT, bestS = t, i - 1 + u
			end
		end
	end
	if not bestT then
		return nil
	end
	return bestS, { x = origin.x + dir.x * bestT, y = origin.y + dir.y * bestT }, bestT
end

-- Returns the merged outline of `dome` (a convex polygon containing the
-- local origin) and a barrel of `length` and half-width `halfWidth` leaving
-- the origin at `angle` radians from local "up" (the same convention as
-- Turret.muzzle). A barrel that stays inside the dome leaves the dome
-- unchanged. Assumes a barrel narrow enough that the dome arc it covers is
-- the shorter of the two.
function TankOutline.build(dome, angle, length, halfWidth)
	local dir = { x = math.sin(angle), y = -math.cos(angle) }
	local side = { x = math.cos(angle), y = math.sin(angle) }

	local rootA = { x = side.x * halfWidth, y = side.y * halfWidth }
	local rootB = { x = -side.x * halfWidth, y = -side.y * halfWidth }
	local sA, exitA, tA = exitPoint(dome, rootA, dir)
	local sB, exitB, tB = exitPoint(dome, rootB, dir)
	if not sA or not sB or tA >= length or tB >= length then
		return dome
	end

	local n = #dome
	-- Walk the dome forward from exit A to exit B, or the other way round --
	-- whichever arc is longer is the one the barrel does not cover.
	local forward = (sB - sA) % n
	local from, to, startExit, endExit, sFrom, sTo
	if forward >= n - forward then
		from, to, startExit, endExit, sFrom, sTo = rootA, rootB, exitA, exitB, sA, sB
	else
		from, to, startExit, endExit, sFrom, sTo = rootB, rootA, exitB, exitA, sB, sA
	end

	local outline = { startExit }
	-- Edge position s sits on edge floor(s); the first vertex past it is the
	-- edge's end point.
	local i = (math.floor(sFrom) + 1) % n + 1
	local steps = math.floor(sTo) - math.floor(sFrom)
	if steps < 0 or (steps == 0 and sTo < sFrom) then
		steps = steps + n
	end
	for _ = 1, steps do
		outline[#outline + 1] = dome[i]
		i = i % n + 1
	end
	outline[#outline + 1] = endExit
	outline[#outline + 1] = { x = to.x + dir.x * length, y = to.y + dir.y * length }
	outline[#outline + 1] = { x = from.x + dir.x * length, y = from.y + dir.y * length }
	return outline
end

return TankOutline
