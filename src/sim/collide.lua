-- Ship-vs-world contact detection (docs/CONTEXT.md "Contact", "World"):
-- reports a collision as plain data -- point and outward surface normal --
-- and nothing else. It never decides land/crash/bounce; that's
-- src/game/components/lander.lua's job, called from
-- src/game/systems/ship_system.lua's handleContacts. Pure -- no `love.*`
-- (docs/ARCHITECTURE.md "Layers").
--
-- Collide.SHIP_SHAPE is the ship's local-space collision polygon and is the
-- single source of truth for it (docs/ARCHITECTURE.md "Layers": app may
-- depend on sim, never the other way around) -- src/app/render/ships.lua
-- reads this table to draw the ship rather than owning its own copy, so the
-- drawn hull and the collided hull can never drift apart.
local Vec2 = require("src.core.vec2")
local Poly = require("src.core.poly")

local Collide = {}

-- Nose pointing "up" (angle 0), matching the nose direction
-- src/game/components/thruster.lua thrusts along.
Collide.SHIP_SHAPE = {
	{ x = 0, y = -10 },
	{ x = 7, y = 8 },
	{ x = -7, y = 8 },
}

-- Rotates then translates a local-space polygon to world space for one
-- frame's body position/angle. Never mutates `shape`.
function Collide.transform(shape, x, y, angle)
	local points = {}
	for i, v in ipairs(shape) do
		local rotated = Vec2.rotate(v, angle or 0)
		points[i] = { x = x + rotated.x, y = y + rotated.y }
	end
	return points
end

-- Closest point on segment p1-p2 to point p, and the distance to it.
local function closestOnSegment(p1, p2, p)
	local edge = Vec2.sub(p2, p1)
	local len2 = Vec2.dot(edge, edge)
	local t = 0
	if len2 > 0 then
		t = Vec2.dot(Vec2.sub(p, p1), edge) / len2
		t = math.max(0, math.min(1, t))
	end
	local closest = Vec2.add(p1, Vec2.scale(edge, t))
	local dist = Vec2.length(Vec2.sub(p, closest))
	return closest, dist
end

-- Tests a world-space polygon (`points`) against one world's vertices.
-- Returns the deepest-penetrating contact {point, normal}, or nil if no
-- vertex of `points` is inside the world. "Deepest" is found by checking
-- every vertex that's inside the world against every edge and keeping the
-- closest edge overall -- for a concave world this is what makes a vertex
-- resting in a notch report the notch's own edge rather than some outer
-- edge (this slice's test approach).
function Collide.polygonContact(points, world)
	local vertices = world.vertices
	local normals = Poly.outwardNormals(vertices)
	local n = #vertices

	local best = nil
	for _, v in ipairs(points) do
		if Poly.pointInPolygon(vertices, v) then
			for i = 1, n do
				local p1 = vertices[i]
				local p2 = vertices[i % n + 1]
				local closest, dist = closestOnSegment(p1, p2, v)
				if not best or dist < best.dist then
					best = { point = closest, normal = normals[i], dist = dist }
				end
			end
		end
	end

	if not best then
		return nil
	end

	return { point = best.point, normal = best.normal }
end

-- Ship-vs-world contact for one body this frame: transforms
-- Collide.SHIP_SHAPE to the body's position/angle and tests it against every
-- world in `worlds`, in order, returning the first contact found (nil if the
-- ship touches none). `relVel` assumes a stationary world -- worlds don't
-- move (docs/CONTEXT.md "World": "Does not move in v1") -- so it's simply
-- the body's own velocity; a moving host (asteroids, slice 09) is
-- src/game/components/landable.lua's concern, applied by
-- src/game/systems/ship_system.lua before the landing check.
-- Circle-circle contact (ship-vs-ship, projectile-vs-ship, docs/CONTEXT.md
-- "Contact"): reports plain data only, same as Collide.polygonContact --
-- outcome (bounce vs kill) is entirely the calling system's job. `normal`
-- points from b toward a (the direction a would need to move to separate
-- from b); `point` is the point on b's circle closest to a, used only for
-- effects/debugging, never for resolution math. Returns nil when the
-- circles don't overlap. Two exactly-coincident centers fall back to a
-- fixed normal (0,-1) rather than dividing by zero -- an edge case that
-- should never come up in practice (two bodies never spawn on the same
-- point) but must not crash if it somehow does.
function Collide.circleContact(ax, ay, aRadius, bx, by, bRadius)
	local dx = ax - bx
	local dy = ay - by
	local dist = math.sqrt(dx * dx + dy * dy)
	local minDist = (aRadius or 0) + (bRadius or 0)

	if dist >= minDist then
		return nil
	end

	local normal
	if dist > 0 then
		normal = { x = dx / dist, y = dy / dist }
	else
		normal = { x = 0, y = -1 }
	end

	local point = { x = bx + normal.x * (bRadius or 0), y = by + normal.y * (bRadius or 0) }

	return { point = point, normal = normal, distance = dist }
end

-- Point where segment p1-p2 crosses line p3-p4, assuming
-- Poly.segmentIntersect(p1, p2, p3, p4) has already returned true (this
-- function doesn't itself check for a crossing). Standard line-line
-- intersection via parametric form; returns nil only for the degenerate
-- parallel/collinear case (denom == 0), which Poly.segmentIntersect's
-- collinear-overlap branches can produce -- callers fall back to `p2` (the
-- segment's own endpoint) when that happens, since the two segments still
-- touch, just not at a single well-defined point.
local function segmentIntersectionPoint(p1, p2, p3, p4)
	local d1x, d1y = p2.x - p1.x, p2.y - p1.y
	local d2x, d2y = p4.x - p3.x, p4.y - p3.y
	local denom = d1x * d2y - d1y * d2x

	if denom == 0 then
		return nil
	end

	local t = ((p3.x - p1.x) * d2y - (p3.y - p1.y) * d2x) / denom
	return { x = p1.x + t * d1x, y = p1.y + t * d1y }
end

-- Swept segment-vs-world-polygon test for a projectile (this slice's own
-- Test approach: "a fast projectile crossing a thin world edge in one step
-- is caught by the swept test"). Unlike Collide.checkShipWorlds (which
-- tests only the body's current-frame position/hull), this tests the whole
-- segment from the body's previous-frame position to its current one --
-- otherwise a fast body can tunnel clean through a thin edge between two
-- position samples at a fixed 1/60s timestep. Tests every world in order,
-- every edge of each, and returns the first crossing found (nil if the
-- segment crosses no world's edge). Falls back to reporting `to` as the
-- contact point when the crossing point can't be computed (the degenerate
-- collinear case above) -- still a valid contact, just an approximate
-- point.
function Collide.checkProjectileWorlds(fromX, fromY, toX, toY, worlds)
	local p1 = { x = fromX, y = fromY }
	local p2 = { x = toX, y = toY }

	for _, world in ipairs(worlds) do
		local vertices = world.vertices
		local normals = Poly.outwardNormals(vertices)
		local n = #vertices

		for i = 1, n do
			local e1 = vertices[i]
			local e2 = vertices[i % n + 1]
			if Poly.segmentIntersect(p1, p2, e1, e2) then
				local point = segmentIntersectionPoint(p1, p2, e1, e2) or p2
				return { point = point, normal = normals[i], world = world }
			end
		end

		-- Covers a segment that ends fully inside the world without its
		-- endpoint-to-endpoint path having crossed a reported edge (e.g. a
		-- projectile that spawns already inside, or floating point noise
		-- right on a vertex) -- still a contact, just with no single edge
		-- normal to report, so this falls back to the segment's own
		-- direction reversed as a "pointing back out" approximation.
		if Poly.pointInPolygon(vertices, p2) then
			local fallbackNormal = Vec2.normalize({ x = p1.x - p2.x, y = p1.y - p2.y })
			if fallbackNormal.x == 0 and fallbackNormal.y == 0 then
				fallbackNormal = { x = 0, y = -1 }
			end
			return { point = p2, normal = fallbackNormal, world = world }
		end
	end

	return nil
end

function Collide.checkShipWorlds(body, worlds)
	local shipPoints = Collide.transform(Collide.SHIP_SHAPE, body.x, body.y, body.angle)

	for _, world in ipairs(worlds) do
		local hit = Collide.polygonContact(shipPoints, world)
		if hit then
			return {
				point = hit.point,
				normal = hit.normal,
				relVel = { x = body.vx, y = body.vy },
				world = world,
			}
		end
	end

	return nil
end

-- Transforms an asteroid body's own local-space `vertices` (src/game/
-- asteroid_shape.lua) by its CURRENT position/angle -- unlike a world, an
-- asteroid drifts and spins, so this must be redone every frame rather than
-- baked once (slice 09).
local function asteroidWorldPoints(asteroid)
	return Collide.transform(asteroid.vertices, asteroid.x, asteroid.y, asteroid.angle)
end

-- Ship-vs-asteroid contact for one ship body this frame (docs/CONTEXT.md
-- "Landing"/"Riding", slice 09): mirrors Collide.checkShipWorlds almost
-- exactly, except each "world" here is a moving/rotating asteroid body --
-- its vertices are transformed by ITS current position/angle before the
-- same Collide.polygonContact test (which already accepts any table with a
-- `.vertices` field, so no new polygon-vs-polygon code is needed). `relVel`
-- is the ship's own velocity only, exactly like checkShipWorlds -- surface
-- velocity (the host's own motion plus its spin) is
-- src/game/components/landable.lua's job, applied by the calling system
-- before the landing check, same split checkShipWorlds already relies on
-- for a static host.
function Collide.checkShipAsteroids(body, asteroids)
	local shipPoints = Collide.transform(Collide.SHIP_SHAPE, body.x, body.y, body.angle)

	for _, asteroid in ipairs(asteroids) do
		local asteroidPoints = asteroidWorldPoints(asteroid)
		local hit = Collide.polygonContact(shipPoints, { vertices = asteroidPoints })
		if hit then
			return {
				point = hit.point,
				normal = hit.normal,
				relVel = { x = body.vx, y = body.vy },
				asteroid = asteroid,
			}
		end
	end

	return nil
end

-- Asteroid-vs-world contact (docs "Destroyed on world contact", slice 09):
-- same transform trick, the other way around -- the asteroid's transformed
-- vertices tested against each world in turn. A contact here always
-- destroys the asteroid; there's no land/crash decision to make (unlike a
-- ship), so this only ever needs point+normal, never relVel.
function Collide.checkAsteroidWorlds(asteroidBody, worlds)
	local asteroidPoints = asteroidWorldPoints(asteroidBody)

	for _, world in ipairs(worlds) do
		local hit = Collide.polygonContact(asteroidPoints, world)
		if hit then
			return {
				point = hit.point,
				normal = hit.normal,
				world = world,
			}
		end
	end

	return nil
end

-- Projectile-vs-asteroid contact (docs "absorb projectiles without being
-- pushed", slice 09): a projectile is effectively a point, so this tests
-- its centre with Collide.polygonContact against the asteroid's transformed
-- vertices, passing a single-point list -- no new polygon-vs-point code
-- needed. Returns nil when the projectile's centre isn't inside the
-- asteroid. Reports plain data only, like every other function here --
-- never touches the asteroid's velocity/angularVelocity itself; the calling
-- system (src/game/systems/asteroid_system.lua) is what must never apply an
-- impulse for this contact kind.
function Collide.checkProjectileAsteroid(projectileBody, asteroidBody)
	local asteroidPoints = asteroidWorldPoints(asteroidBody)
	local point = { x = projectileBody.x, y = projectileBody.y }
	return Collide.polygonContact({ point }, { vertices = asteroidPoints })
end

return Collide
