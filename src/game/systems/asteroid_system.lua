-- Asteroid pool system (docs/ARCHITECTURE.md "Systems and frame order"):
-- the only place asteroid records are spawned or driven each frame. Called
-- from src/game/match.lua's Match.step step-3 spawner slot. Spawning is
-- time/delay-gated internally (config.asteroid.spawnDelay), draws only from
-- `ctx.rng` (never `math.random` -- this slice's Gotcha: "same seed -> same
-- asteroid sequence"), and never exceeds `ctx.level.asteroids.maxAlive`.
local Bodies = require("src.sim.bodies")
local Vec2 = require("src.core.vec2")
local Poly = require("src.core.poly")
local AsteroidShape = require("src.game.asteroid_shape")

local AsteroidSystem = {}

local SCREEN_WIDTH = 1280
local SCREEN_HEIGHT = 720
local CENTER = { x = SCREEN_WIDTH / 2, y = SCREEN_HEIGHT / 2 }

-- Long enough to cross the whole arena from any spawn edge, for the
-- "spawn line never passes within a ship's safety radius" check below --
-- comfortably more than the screen's own diagonal (~1468px at 1280x720).
local TRAJECTORY_LENGTH = 3000

-- Closest point on segment p1-p2 to point p, and the distance to it (same
-- shape as src/sim/collide.lua's private closestOnSegment, duplicated here
-- rather than exported from sim/ -- this is a game-layer spawner concern,
-- not a collision concern, and sim/ must stay ignorant of asteroids'
-- spawn-safety rules).
local function distanceToSegment(p1, p2, p)
	local edge = Vec2.sub(p2, p1)
	local len2 = Vec2.dot(edge, edge)
	local t = 0
	if len2 > 0 then
		t = Vec2.dot(Vec2.sub(p, p1), edge) / len2
		t = math.max(0, math.min(1, t))
	end
	local closest = Vec2.add(p1, Vec2.scale(edge, t))
	return Vec2.length(Vec2.sub(p, closest))
end

-- Draws one candidate spawn (position outside the screen on a random edge,
-- aimed roughly at the screen centre with a randomised spread, at a random
-- inward speed), fully from `rng`.
local function drawCandidate(rng, config)
	local margin = config.spawnMargin
	local edge = rng:int(1, 4)
	local position

	if edge == 1 then -- top
		position = { x = rng:range(0, SCREEN_WIDTH), y = -margin }
	elseif edge == 2 then -- bottom
		position = { x = rng:range(0, SCREEN_WIDTH), y = SCREEN_HEIGHT + margin }
	elseif edge == 3 then -- left
		position = { x = -margin, y = rng:range(0, SCREEN_HEIGHT) }
	else -- right
		position = { x = SCREEN_WIDTH + margin, y = rng:range(0, SCREEN_HEIGHT) }
	end

	local towardCenter = Vec2.normalize(Vec2.sub(CENTER, position))
	local spread = rng:range(-config.aimSpread, config.aimSpread)
	local direction = Vec2.rotate(towardCenter, spread)
	local speed = rng:range(config.speedRange.min, config.speedRange.max)

	return {
		position = position,
		velocity = Vec2.scale(direction, speed),
		direction = direction,
	}
end

-- True when `candidate`'s spawn line (its full flight path across the
-- arena) passes within `config.safetyRadius` of any live ship -- this
-- candidate must be rejected and re-drawn (this slice's Test approach:
-- "spawn line never passes within the safety radius of a ship").
local function tooCloseToAnyShip(candidate, ctx)
	local safetyRadius = ctx.config.asteroid.safetyRadius
	local trajectoryEnd = Vec2.add(candidate.position, Vec2.scale(candidate.direction, TRAJECTORY_LENGTH))

	for _, ship in ipairs(ctx.pools.ships) do
		if not ship.dead then
			local body = Bodies.get(ctx.sim.bodies, ship.body)
			if body then
				local dist = distanceToSegment(candidate.position, trajectoryEnd, { x = body.x, y = body.y })
				if dist < safetyRadius then
					return true
				end
			end
		end
	end

	return false
end

-- Spawns one asteroid body + pool record from `candidate` (already checked
-- safe by the caller). Mass follows density x area, the same convention
-- src/game/level.lua's Level.validate uses for worlds -- computed here
-- (spawn time) rather than through Level.validate, which only ever
-- processes static level.worlds, never asteroids.
local function spawnAsteroid(ctx, candidate)
	local config = ctx.config.asteroid
	local shape = AsteroidShape.generate(ctx.rng, config)
	local mass = config.density * math.abs(Poly.area(shape.vertices))
	local spin = ctx.rng:range(config.spinRange.min, config.spinRange.max)

	local body = {
		x = candidate.position.x,
		y = candidate.position.y,
		vx = candidate.velocity.x,
		vy = candidate.velocity.y,
		angle = 0,
		angularVelocity = spin,
		mass = mass,
		kind = "asteroid",
		radius = shape.radius,
		vertices = shape.vertices,
	}
	local bodyId = Bodies.add(ctx.sim.bodies, body)

	local asteroid = {
		id = bodyId,
		body = bodyId,
		dead = false,
		kind = "asteroid",
	}

	table.insert(ctx.pools.asteroids, asteroid)
	return asteroid
end

local function countLive(pool)
	local count = 0
	for _, record in ipairs(pool) do
		if not record.dead then
			count = count + 1
		end
	end
	return count
end

-- Called once per frame from Match.step's step-3 spawner slot. Accumulates
-- ctx.dt into a per-match timer (lazily initialised on ctx, since
-- src/game/match.lua's Match.new owns no asteroid-specific state); once the
-- timer reaches config.asteroid.spawnDelay, attempts one spawn (subject to
-- the level's maxAlive cap and the safety-radius check, retried a bounded
-- number of times -- Guard Against Hangs) and resets the timer regardless
-- of whether that attempt succeeded, so a run of unsafe draws doesn't stall
-- every future attempt right behind it.
function AsteroidSystem.update(ctx)
	local config = ctx.config.asteroid
	ctx.asteroidSpawnTimer = (ctx.asteroidSpawnTimer or 0) + ctx.dt

	if ctx.asteroidSpawnTimer < config.spawnDelay then
		return
	end
	ctx.asteroidSpawnTimer = 0

	local maxAlive = ctx.level.asteroids and ctx.level.asteroids.maxAlive or 0
	if maxAlive <= 0 then
		return
	end

	if countLive(ctx.pools.asteroids) >= maxAlive then
		return
	end

	for _ = 1, config.maxSpawnAttempts do
		local candidate = drawCandidate(ctx.rng, config)
		if not tooCloseToAnyShip(candidate, ctx) then
			spawnAsteroid(ctx, candidate)
			return
		end
	end
end

local function killAsteroid(ctx, asteroidBody)
	for _, asteroid in ipairs(ctx.pools.asteroids) do
		local body = Bodies.get(ctx.sim.bodies, asteroid.body)
		if body and body == asteroidBody and not asteroid.dead then
			asteroid.dead = true
			Bodies.markDead(ctx.sim.bodies, asteroid.body)
		end
	end
end

-- Resolves an "asteroidAsteroid" bounce (docs "bounce off each other"),
-- mirroring src/game/systems/ship_system.lua's resolveShipBounce -- a
-- mass-weighted elastic impulse along the collision normal, plus a
-- positional separation push.
local function resolveAsteroidBounce(ctx, bodyA, bodyB, normal)
	local relVel = { x = bodyA.vx - bodyB.vx, y = bodyA.vy - bodyB.vy }
	local approachSpeed = Vec2.dot(relVel, normal)

	if approachSpeed < 0 then
		local restitution = ctx.config.asteroid.restitution or 1
		local m1 = Bodies.effectiveMass(ctx.sim.bodies, bodyA)
		local m2 = Bodies.effectiveMass(ctx.sim.bodies, bodyB)
		local impulseMagnitude = -(1 + restitution) * approachSpeed / (1 / m1 + 1 / m2)
		local impulse = Vec2.scale(normal, impulseMagnitude)

		bodyA.vx = bodyA.vx + impulse.x / m1
		bodyA.vy = bodyA.vy + impulse.y / m1
		bodyB.vx = bodyB.vx - impulse.x / m2
		bodyB.vy = bodyB.vy - impulse.y / m2
	end

	local dx = bodyA.x - bodyB.x
	local dy = bodyA.y - bodyB.y
	local dist = math.sqrt(dx * dx + dy * dy)
	local minDist = (bodyA.radius or 0) + (bodyB.radius or 0)
	local depth = minDist - dist
	if depth > 0 then
		bodyA.x = bodyA.x + normal.x * (depth / 2)
		bodyA.y = bodyA.y + normal.y * (depth / 2)
		bodyB.x = bodyB.x - normal.x * (depth / 2)
		bodyB.y = bodyB.y - normal.y * (depth / 2)
	end
end


-- Systems handle contacts (docs/ARCHITECTURE.md "Systems and frame order",
-- step 5): "asteroidWorld" always destroys the asteroid and
-- "asteroidAsteroid" bounces (mass-weighted, effective mass). Projectile-
-- asteroid contacts are now handled by src/game/systems/projectile_system.lua's
-- ProjectileSystem.handleContacts, which calls src/game/blast.lua's
-- Blast.detonate. The sim only reports contacts; outcomes are decided here,
-- never in src/sim/.
function AsteroidSystem.handleContacts(ctx, contacts)
	for _, contact in ipairs(contacts) do
		if contact.kind == "asteroidWorld" then
			killAsteroid(ctx, contact.a)
		elseif contact.kind == "asteroidAsteroid" then
			resolveAsteroidBounce(ctx, contact.a, contact.b, contact.normal)
		end
	end
end

return AsteroidSystem
