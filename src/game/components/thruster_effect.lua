-- ThrusterEffect component (docs/ARCHITECTURE.md "Component"): a pure
-- function over a ship record that works out where an exhaust particle is
-- born and how fast it moves. It never spawns anything -- the owning
-- src/game/systems/ship_system.lua passes the result to ParticleSystem.spawn.
local Bodies = require("src.sim.bodies")
local Collide = require("src.sim.collide")
local Vec2 = require("src.core.vec2")

local ThrusterEffect = {}

-- Returns the alpha (opacity) for a particle at a given age.
-- Full alpha (1) during holdTime, then linear fade over fadeTime, then 0.
function ThrusterEffect.alpha(age, holdTime, fadeTime)
	if age <= holdTime then
		return 1
	end
	local fadeAge = age - holdTime
	if fadeAge >= fadeTime then
		return 0
	end
	return 1 - (fadeAge / fadeTime)
end

-- The rear edge of the hull in local space, derived from Collide.SHIP_SHAPE:
-- the edge whose midpoint sits furthest behind the nose (local +y is rear,
-- since the nose points up at angle 0). Returns its endpoints and its
-- outward unit normal.
local function rearEdge()
	local shape = Collide.SHIP_SHAPE
	local bestA, bestB, bestY
	for i = 1, #shape do
		local a, b = shape[i], shape[i % #shape + 1]
		local midY = (a.y + b.y) / 2
		if not bestY or midY > bestY then
			bestA, bestB, bestY = a, b, midY
		end
	end

	local edge = Vec2.sub(bestB, bestA)
	local length = Vec2.length(edge)
	-- Perpendicular to the edge, flipped if needed so it points away from the
	-- hull's centroid at the local origin.
	local normal = { x = edge.y / length, y = -edge.x / length }
	local mid = Vec2.scale(Vec2.add(bestA, bestB), 0.5)
	if Vec2.dot(normal, mid) < 0 then
		normal = Vec2.scale(normal, -1)
	end
	return bestA, bestB, normal
end

local EDGE_A, EDGE_B, REAR_NORMAL = rearEdge()

-- Returns (position, velocity) for one exhaust particle: a random point on
-- the centre `edgeFraction` of the rear edge, moving at the ship's velocity
-- plus `exhaustSpeed` along the rotated rear normal plus a random sideways
-- spread of up to `spreadSpeed`. Returns nil if the ship's body is gone.
function ThrusterEffect.emit(ship, ctx)
	local body = Bodies.get(ctx.sim.bodies, ship.body)
	if not body then
		return nil
	end

	local config = ctx.config.thrusterEffect
	local angle = body.angle or 0

	local margin = (1 - config.edgeFraction) / 2
	local t = ctx.rng:range(margin, 1 - margin)
	local local_ = Vec2.add(EDGE_A, Vec2.scale(Vec2.sub(EDGE_B, EDGE_A), t))
	local offset = Vec2.rotate(local_, angle)
	local position = { x = body.x + offset.x, y = body.y + offset.y }

	local rear = Vec2.rotate(REAR_NORMAL, angle)
	local sideways = { x = -rear.y, y = rear.x }
	local side = ctx.rng:range(-config.spreadSpeed, config.spreadSpeed)
	local velocity = {
		x = body.vx + rear.x * config.exhaustSpeed + sideways.x * side,
		y = body.vy + rear.y * config.exhaustSpeed + sideways.y * side,
	}

	return position, velocity
end

return ThrusterEffect
