local AsteroidSystem = require("src.game.systems.asteroid_system")
local Bodies = require("src.sim.bodies")
local Rng = require("src.core.rng")
local Config = require("src.game.config")
local Vec2 = require("src.core.vec2")

local function newCtx(seed, maxAlive, shipPositions)
	local bodies = Bodies.new()
	local ships = {}

	for _, pos in ipairs(shipPositions or {}) do
		local bodyId = Bodies.add(bodies, { x = pos.x, y = pos.y, vx = 0, vy = 0, angle = 0, mass = 1, kind = "ship" })
		table.insert(ships, { body = bodyId, dead = false })
	end

	return {
		dt = Config.asteroid.spawnDelay,
		time = 0,
		pools = { ships = ships, projectiles = {}, asteroids = {} },
		sim = { bodies = bodies },
		level = { asteroids = { maxAlive = maxAlive } },
		config = Config,
		rng = Rng.new(seed),
		events = {},
	}
end

test("AsteroidSystem.update spawns nothing before spawnDelay has elapsed", function()
	local ctx = newCtx(1, 2, {})
	ctx.dt = Config.asteroid.spawnDelay / 2

	AsteroidSystem.update(ctx)

	assertEqual(0, #ctx.pools.asteroids)
end)

test("AsteroidSystem.update spawns one asteroid once spawnDelay has elapsed", function()
	local ctx = newCtx(1, 2, {})

	AsteroidSystem.update(ctx)

	assertEqual(1, #ctx.pools.asteroids)
end)

test("AsteroidSystem.update never spawns past the level's maxAlive", function()
	local ctx = newCtx(1, 1, {})

	AsteroidSystem.update(ctx)
	assertEqual(1, #ctx.pools.asteroids)

	ctx.asteroidSpawnTimer = Config.asteroid.spawnDelay
	AsteroidSystem.update(ctx)
	assertEqual(1, #ctx.pools.asteroids, "expected the second attempt to be skipped at maxAlive")
end)

test("AsteroidSystem.update spawns nothing when the level has no asteroids field", function()
	local ctx = newCtx(1, 2, {})
	ctx.level = {}

	AsteroidSystem.update(ctx)

	assertEqual(0, #ctx.pools.asteroids)
end)

test("AsteroidSystem.update: same seed produces the same asteroid sequence", function()
	local ctxA = newCtx(777, 2, {})
	local ctxB = newCtx(777, 2, {})

	AsteroidSystem.update(ctxA)
	AsteroidSystem.update(ctxB)

	local bodyA = Bodies.get(ctxA.sim.bodies, ctxA.pools.asteroids[1].body)
	local bodyB = Bodies.get(ctxB.sim.bodies, ctxB.pools.asteroids[1].body)

	assertNear(bodyA.x, bodyB.x, 0.0000001)
	assertNear(bodyA.y, bodyB.y, 0.0000001)
	assertNear(bodyA.vx, bodyB.vx, 0.0000001)
	assertNear(bodyA.vy, bodyB.vy, 0.0000001)
	assertNear(bodyA.angularVelocity, bodyB.angularVelocity, 0.0000001)
	assertEqual(#bodyA.vertices, #bodyB.vertices)
end)

-- Distance from `point` to the infinite ray from `origin` through
-- `origin + direction`, matching the test approach's own way of checking
-- "the spawn line never passes within the safety radius of a ship" --
-- independent of asteroid_system.lua's internal distanceToSegment (not
-- exported), so this genuinely double-checks the invariant rather than
-- re-running the same code.
local function distanceFromLine(origin, direction, point)
	local toPoint = Vec2.sub(point, origin)
	local t = Vec2.dot(toPoint, direction)
	if t < 0 then
		return Vec2.length(toPoint)
	end
	local closest = Vec2.add(origin, Vec2.scale(direction, t))
	return Vec2.length(Vec2.sub(point, closest))
end

test("AsteroidSystem.update never spawns a trajectory that passes within a ship's safety radius", function()
	-- A ship sitting dead centre of the arena -- any straight inward-aimed
	-- trajectory from any edge, aimed roughly at the centre, would normally
	-- pass close to it, so this is a meaningful check, not a vacuous one.
	local shipPos = { x = 640, y = 360 }

	for seed = 1, 40 do
		local ctx = newCtx(seed, 2, { shipPos })
		AsteroidSystem.update(ctx)

		if #ctx.pools.asteroids == 1 then
			local body = Bodies.get(ctx.sim.bodies, ctx.pools.asteroids[1].body)
			local direction = Vec2.normalize({ x = body.vx, y = body.vy })
			local dist = distanceFromLine({ x = body.x, y = body.y }, direction, shipPos)
			assertTrue(
				dist >= Config.asteroid.safetyRadius - 0.01,
				"expected trajectory to clear the ship's safety radius for seed " .. seed .. " (got " .. dist .. ")"
			)
		end
	end
end)
