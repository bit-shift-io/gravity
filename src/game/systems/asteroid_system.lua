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
local AsteroidSplit = require("src.game.asteroid_split")

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

-- Adds one asteroid body + pool record. Mass follows density x area, the
-- same convention src/game/level.lua's Level.validate uses for worlds. Shared
-- by the spawner and by splitting, so both build the identical body shape.
local function addAsteroid(ctx, fields)
	local mass = ctx.config.asteroid.density * math.abs(Poly.area(fields.vertices))
	local bodyId = Bodies.add(ctx.sim.bodies, {
		x = fields.x,
		y = fields.y,
		vx = fields.vx,
		vy = fields.vy,
		angle = fields.angle,
		angularVelocity = fields.angularVelocity,
		mass = mass,
		kind = "asteroid",
		radius = fields.radius,
		vertices = fields.vertices,
	})

	local asteroid = {
		id = bodyId,
		body = bodyId,
		dead = false,
		kind = "asteroid",
	}

	-- Fragments of one split share a `fragmentOf` tag (the root parent's body
	-- id). Siblings ignore each other while `siblingImmune`, which
	-- AsteroidSystem.handleContacts clears once a fragment is no longer touching
	-- a sibling.
	asteroid.fragmentOf = fields.fragmentOf
	asteroid.siblingImmune = fields.fragmentOf ~= nil

	table.insert(ctx.pools.asteroids, asteroid)
	return asteroid
end

-- Spawns one asteroid body + pool record from `candidate` (already checked
-- safe by the caller). Mass follows density x area, the same convention
-- src/game/level.lua's Level.validate uses for worlds -- computed here
-- (spawn time) rather than through Level.validate, which only ever
-- processes static level.worlds, never asteroids.
local function spawnAsteroid(ctx, candidate)
	local config = ctx.config.asteroid
	local shape = AsteroidShape.generate(ctx.rng, config)
	local spin = ctx.rng:range(config.spinRange.min, config.spinRange.max)

	return addAsteroid(ctx, {
		x = candidate.position.x,
		y = candidate.position.y,
		vx = candidate.velocity.x,
		vy = candidate.velocity.y,
		angle = 0,
		angularVelocity = spin,
		vertices = shape.vertices,
		radius = shape.radius,
	})
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

-- The live pool record for `asteroidBody`, or nil when it is already dead
-- (a body can be named by several contacts in one step).
local function liveRecordFor(ctx, asteroidBody)
	for _, asteroid in ipairs(ctx.pools.asteroids) do
		if not asteroid.dead and Bodies.get(ctx.sim.bodies, asteroid.body) == asteroidBody then
			return asteroid
		end
	end
	return nil
end

local function killAsteroid(ctx, asteroidBody)
	local asteroid = liveRecordFor(ctx, asteroidBody)
	if asteroid then
		asteroid.dead = true
		Bodies.markDead(ctx.sim.bodies, asteroid.body)
	end
end

local PUSH_OUT_MARGIN = 0.5

-- Replaces `parent` (a live record whose body is `parentBody`) with 3
-- fragments. Fragments inherit the parent's velocity and angular velocity,
-- gain a nudge along parent centre -> fragment centroid, and are moved out
-- along `normal` (pointing away from whatever was hit) until clear of the
-- plane through `point`; a nil `normal` skips the push-out (the thing that hit
-- is gone: a crashed ship or a detonated projectile). `impact` is the world-space direction the hit came
-- from. New fragments are not in this step's contact list, so they are not
-- tested until next step.
local function splitAsteroid(ctx, parent, parentBody, impact, normal, point)
	local config = ctx.config.asteroid
	local origin = { x = parentBody.x, y = parentBody.y }
	local localImpact = Vec2.rotate(impact, -parentBody.angle)

	local fragments = AsteroidSplit.carve(parentBody.vertices, localImpact)

	parent.dead = true
	Bodies.markDead(ctx.sim.bodies, parent.body)

	for _, fragment in ipairs(fragments) do
		local offset = Vec2.rotate(fragment.offset, parentBody.angle)
		local position = Vec2.add(origin, offset)

		local nudge = { x = 0, y = 0 }
		if Vec2.length(offset) > 1e-9 then
			nudge = Vec2.scale(Vec2.normalize(offset), config.splitNudgeSpeed)
		end

		if normal then
			-- Deepest penetration of any fragment vertex past the contact edge.
			local depth = 0
			for _, v in ipairs(fragment.vertices) do
				local p = Vec2.add(position, Vec2.rotate(v, parentBody.angle))
				depth = math.max(depth, Vec2.dot(Vec2.sub(point, p), normal))
			end
			position = Vec2.add(position, Vec2.scale(normal, depth + PUSH_OUT_MARGIN))
		end

		local velocity = { x = parentBody.vx + nudge.x, y = parentBody.vy + nudge.y }
		if normal then
			-- Stop fragments driving back into what was hit (they would be
			-- destroyed or re-split next step) and shove them off it.
			local inward = math.min(0, Vec2.dot(velocity, normal))
			velocity = Vec2.add(Vec2.sub(velocity, Vec2.scale(normal, inward)), Vec2.scale(normal, config.splitNudgeSpeed))
		end

		addAsteroid(ctx, {
			x = position.x,
			y = position.y,
			vx = velocity.x,
			vy = velocity.y,
			angle = parentBody.angle,
			angularVelocity = parentBody.angularVelocity,
			vertices = fragment.vertices,
			radius = fragment.radius,
			fragmentOf = parent.fragmentOf or parent.body,
		})
	end
end

-- "asteroidWorld": above the area threshold the asteroid splits, otherwise
-- it is destroyed. An asteroid already dead this step is skipped.
local function splitOrDestroy(ctx, body, impact, normal, point)
	local record = liveRecordFor(ctx, body)
	if not record then
		return
	end

	local area = math.abs(Poly.area(body.vertices))
	if area > ctx.config.asteroid.splitAreaThreshold then
		splitAsteroid(ctx, record, body, impact, normal, point)
	else
		killAsteroid(ctx, body)
	end
end

-- Direction a hit arrives from: asteroid centre -> contact point, falling
-- back to the reversed contact normal when the point is at the centre.
local function impactDirection(body, contact)
	local impact = Vec2.sub(contact.point, { x = body.x, y = body.y })
	if Vec2.length(impact) < 1e-9 then
		impact = Vec2.scale(contact.normal, -1)
	end
	return impact
end

-- "shipAsteroid": the ship crash is ShipSystem's; here a large asteroid
-- splits and a small one is destroyed. No push-out: the ship is gone.
local function handleShipAsteroid(ctx, contact)
	splitOrDestroy(ctx, contact.b, impactDirection(contact.b, contact), nil, contact.point)
end

-- "projectileAsteroid": runs after ProjectileSystem's Blast.detonate has
-- pushed the asteroid, so fragments inherit the push (see
-- docs/memory/asteroid-contact-handling-order.md). Large asteroids split;
-- small ones are only pushed and survive. No push-out: the projectile is gone.
local function handleProjectileAsteroid(ctx, contact)
	local body = contact.b
	local record = liveRecordFor(ctx, body)
	if not record then
		return
	end
	if math.abs(Poly.area(body.vertices)) > ctx.config.asteroid.splitAreaThreshold then
		splitAsteroid(ctx, record, body, impactDirection(body, contact), nil, contact.point)
	end
end

local function handleAsteroidWorld(ctx, contact)
	local impact = Vec2.sub(contact.point, { x = contact.a.x, y = contact.a.y })
	if Vec2.length(impact) < 1e-9 then
		impact = Vec2.scale(contact.normal, -1)
	end
	splitOrDestroy(ctx, contact.a, impact, contact.normal, contact.point)
end

local function areImmuneSiblings(recordA, recordB)
	return recordA.siblingImmune
		and recordB.siblingImmune
		and recordA.fragmentOf ~= nil
		and recordA.fragmentOf == recordB.fragmentOf
end

-- Ends sibling immunity for every fragment not touching a sibling this step.
-- Must run before this step's splits add fresh (still overlapping) fragments.
local function releaseSeparatedSiblings(ctx, contacts)
	local touching = {}
	for _, contact in ipairs(contacts) do
		if contact.kind == "asteroidAsteroid" then
			local recordA, recordB = liveRecordFor(ctx, contact.a), liveRecordFor(ctx, contact.b)
			if recordA and recordB and areImmuneSiblings(recordA, recordB) then
				touching[recordA] = true
				touching[recordB] = true
			end
		end
	end
	for _, asteroid in ipairs(ctx.pools.asteroids) do
		if asteroid.siblingImmune and not touching[asteroid] then
			asteroid.siblingImmune = false
		end
	end
end

-- "asteroidAsteroid": each asteroid is judged alone. Impact comes from the
-- other asteroid; the contact normal points b -> a, so a is pushed out along
-- +normal and b along -normal. Each side reads the other body's position,
-- which stays valid even once that body has been split (bodies persist until
-- the despawn sweep).
local function handleAsteroidAsteroid(ctx, contact)
	local a, b = contact.a, contact.b
	local recordA, recordB = liveRecordFor(ctx, a), liveRecordFor(ctx, b)
	if recordA and recordB and areImmuneSiblings(recordA, recordB) then
		return
	end
	local toB = Vec2.sub({ x = b.x, y = b.y }, { x = a.x, y = a.y })
	if Vec2.length(toB) < 1e-9 then
		toB = Vec2.scale(contact.normal, -1)
	end
	splitOrDestroy(ctx, a, toB, contact.normal, contact.point)
	splitOrDestroy(ctx, b, Vec2.scale(toB, -1), Vec2.scale(contact.normal, -1), contact.point)
end

-- Systems handle contacts (docs/ARCHITECTURE.md "Systems and frame order",
-- step 5): "asteroidWorld" splits a large asteroid or destroys a small one, and
-- "asteroidAsteroid" judges each asteroid alone the same way, and "shipAsteroid"
-- / "projectileAsteroid" split a large asteroid after ShipSystem (crash) and
-- ProjectileSystem (Blast.detonate push) have already run. The sim only reports contacts; outcomes are decided here,
-- never in src/sim/.
function AsteroidSystem.handleContacts(ctx, contacts)
	releaseSeparatedSiblings(ctx, contacts)
	for _, contact in ipairs(contacts) do
		if contact.kind == "asteroidWorld" then
			handleAsteroidWorld(ctx, contact)
		elseif contact.kind == "asteroidAsteroid" then
			handleAsteroidAsteroid(ctx, contact)
		elseif contact.kind == "shipAsteroid" then
			handleShipAsteroid(ctx, contact)
		elseif contact.kind == "projectileAsteroid" then
			handleProjectileAsteroid(ctx, contact)
		end
	end
end

return AsteroidSystem
