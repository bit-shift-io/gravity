local Blast = require("src.game.blast")
local Bodies = require("src.sim.bodies")
local Config = require("src.game.config")

local function newCtx(overrides)
	overrides = overrides or {}
	local bodies = Bodies.new()
	local ctx = {
		dt = 1 / 60,
		time = 0,
		sim = { bodies = bodies },
		pools = { ships = {}, projectiles = {}, asteroids = {} },
		config = overrides.config or Config,
		events = {},
	}
	return ctx, bodies
end

local function newShip(bodies, ctx, x, y)
	x = x or 0
	y = y or 0
	local body = { x = x, y = y, vx = 0, vy = 0, angle = 0, mass = 1000, kind = "ship", radius = 9 }
	local bodyId = Bodies.add(bodies, body)
	local ship = {
		id = bodyId,
		body = bodyId,
		player = 1,
		dead = false,
	}
	table.insert(ctx.pools.ships, ship)
	return ship
end

local function newProjectile(bodies, ctx, x, y, shooterId)
	x = x or 0
	y = y or 0
	local body = { x = x, y = y, vx = 0, vy = 0, angle = 0, mass = 0.001, kind = "projectile", radius = 3 }
	local bodyId = Bodies.add(bodies, body)
	local projectile = {
		id = bodyId,
		body = bodyId,
		shooter = shooterId,
		dead = false,
		age = 0,
	}
	table.insert(ctx.pools.projectiles, projectile)
	return projectile
end

local function newAsteroid(bodies, ctx, x, y, mass)
	x = x or 0
	y = y or 0
	mass = mass or 100
	local body = { x = x, y = y, vx = 0, vy = 0, angle = 0, mass = mass, kind = "asteroid", radius = 20 }
	local bodyId = Bodies.add(bodies, body)
	local asteroid = {
		id = bodyId,
		body = bodyId,
		dead = false,
	}
	table.insert(ctx.pools.asteroids, asteroid)
	return asteroid, body
end

test("detonating kills ships within the blast radius", function()
	local ctx, bodies = newCtx()
	local shooter = newShip(bodies, ctx, 0, 0)
	local target = newShip(bodies, ctx, 50, 0)
	local projectile = newProjectile(bodies, ctx, 25, 0, shooter.id)
	local projBody = Bodies.get(bodies, projectile.body)

	Blast.detonate(ctx, projectile, projBody)

	assertTrue(projectile.dead, "expected projectile to be marked dead")
	assertTrue(target.dead, "expected target ship within blast radius to be dead")
end)

test("detonating does not kill ships outside the blast radius", function()
	local ctx, bodies = newCtx()
	local shooter = newShip(bodies, ctx, 0, 0)
	local target = newShip(bodies, ctx, 200, 0) -- Beyond the 100px blast radius
	local projectile = newProjectile(bodies, ctx, 0, 0, shooter.id)
	local projBody = Bodies.get(bodies, projectile.body)

	Blast.detonate(ctx, projectile, projBody)

	assertTrue(projectile.dead, "expected projectile to be marked dead")
	assertFalse(target.dead, "expected target ship outside blast radius to survive")
end)

test("detonating kills the shooter if within the blast radius", function()
	local ctx, bodies = newCtx()
	local shooter = newShip(bodies, ctx, 0, 0)
	local projectile = newProjectile(bodies, ctx, 20, 0, shooter.id)
	local projBody = Bodies.get(bodies, projectile.body)

	Blast.detonate(ctx, projectile, projBody)

	assertTrue(shooter.dead, "expected shooter inside blast radius to be dead")
end)

test("detonating creates a blast event", function()
	local ctx, bodies = newCtx()
	local shooter = newShip(bodies, ctx, 0, 0)
	local projectile = newProjectile(bodies, ctx, 100, 50, shooter.id)
	local projBody = Bodies.get(bodies, projectile.body)

	Blast.detonate(ctx, projectile, projBody)

	assertEqual(1, #ctx.events, "expected a blast event to be created")
	local event = ctx.events[1]
	assertEqual("blast", event.kind, "expected event kind to be 'blast'")
	assertEqual(100, event.x, "expected event x to match projectile x")
	assertEqual(50, event.y, "expected event y to match projectile y")
	assertEqual(ctx.config.projectile.blastRadius, event.radius, "expected event radius to match config")
	assertEqual(0, event.time, "expected event time to be current time")
end)

test("detonating creates crash events for killed ships", function()
	local ctx, bodies = newCtx()
	local shooter = newShip(bodies, ctx, 0, 0)
	local target = newShip(bodies, ctx, 50, 0)
	local projectile = newProjectile(bodies, ctx, 25, 0, shooter.id)
	local projBody = Bodies.get(bodies, projectile.body)

	Blast.detonate(ctx, projectile, projBody)

	-- Should have both a blast event and crash events for each killed ship
	local crashEvents = {}
	local blastCount = 0
	for _, event in ipairs(ctx.events) do
		if event.kind == "crash" then
			table.insert(crashEvents, event)
		elseif event.kind == "blast" then
			blastCount = blastCount + 1
		end
	end

	assertEqual(1, blastCount, "expected one blast event")
	assertEqual(2, #crashEvents, "expected two crash events (one per killed ship)")
end)

test("detonating does nothing if projectile is already dead", function()
	local ctx, bodies = newCtx()
	local shooter = newShip(bodies, ctx, 0, 0)
	local target = newShip(bodies, ctx, 50, 0)
	local projectile = newProjectile(bodies, ctx, 25, 0, shooter.id)
	projectile.dead = true
	local projBody = Bodies.get(bodies, projectile.body)

	local eventsBefore = #ctx.events
	Blast.detonate(ctx, projectile, projBody)

	assertEqual(eventsBefore, #ctx.events, "expected no events to be created for already-dead projectile")
	assertFalse(target.dead, "expected target to survive when projectile was already dead")
end)

test("an asteroid at half the push radius gains half the impulse", function()
	local ctx, bodies = newCtx()
	local shooter = newShip(bodies, ctx, 0, 0)
	local pushRadius = ctx.config.projectile.pushRadius
	local halfRadius = pushRadius / 2

	-- Asteroid directly to the right at half the push radius
	local _, asteroidBody = newAsteroid(bodies, ctx, halfRadius, 0, 100)
	local projectile = newProjectile(bodies, ctx, 0, 0, shooter.id)
	local projBody = Bodies.get(bodies, projectile.body)

	Blast.detonate(ctx, projectile, projBody)

	-- At half radius, the falloff should be (1 - 0.5) = 0.5
	-- So impulse should be pushStrength * 0.5 / mass
	local expectedImpulse = ctx.config.projectile.pushStrength * 0.5 / 100
	assertNear(expectedImpulse, asteroidBody.vx, 0.1, "expected asteroid at half radius to move away with half impulse")
	assertNear(0, asteroidBody.vy, 0.1, "expected asteroid at half radius to move horizontally")
end)

test("an asteroid outside the push radius is not affected", function()
	local ctx, bodies = newCtx()
	local shooter = newShip(bodies, ctx, 0, 0)
	local pushRadius = ctx.config.projectile.pushRadius

	-- Asteroid far outside the push radius
	local _, asteroidBody = newAsteroid(bodies, ctx, pushRadius + 50, 0, 100)
	local projectile = newProjectile(bodies, ctx, 0, 0, shooter.id)
	local projBody = Bodies.get(bodies, projectile.body)

	Blast.detonate(ctx, projectile, projBody)

	assertNear(0, asteroidBody.vx, 0.001, "expected asteroid outside radius to have zero vx")
	assertNear(0, asteroidBody.vy, 0.001, "expected asteroid outside radius to have zero vy")
end)

test("a heavier asteroid moves less for the same blast", function()
	local ctx, bodies = newCtx()
	local shooter = newShip(bodies, ctx, 0, 0)
	local pushRadius = ctx.config.projectile.pushRadius
	local testDist = pushRadius / 2

	local _, lightBody = newAsteroid(bodies, ctx, testDist, 0, 50)
	local _, heavyBody = newAsteroid(bodies, ctx, testDist, 0, 200)
	local projectile = newProjectile(bodies, ctx, 0, 0, shooter.id)
	local projBody = Bodies.get(bodies, projectile.body)

	Blast.detonate(ctx, projectile, projBody)

	assertTrue(lightBody.vx > heavyBody.vx, "expected lighter asteroid to move more than heavier asteroid")
	-- Light: pushStrength * 0.5 / 50 = strength / 50
	-- Heavy: pushStrength * 0.5 / 200 = strength / 200
	-- Light should be 200/50 = 4x heavier's velocity
	assertNear(lightBody.vx / heavyBody.vx, 4, 0.1, "expected velocity ratio to match mass ratio")
end)

test("an asteroid at the blast centre is not pushed (zero direction)", function()
	local ctx, bodies = newCtx()
	local shooter = newShip(bodies, ctx, 0, 0)

	-- Asteroid exactly at the blast centre
	local _, asteroidBody = newAsteroid(bodies, ctx, 0, 0, 100)
	local projectile = newProjectile(bodies, ctx, 0, 0, shooter.id)
	local projBody = Bodies.get(bodies, projectile.body)

	Blast.detonate(ctx, projectile, projBody)

	assertNear(0, asteroidBody.vx, 0.001, "expected asteroid at centre to have zero vx")
	assertNear(0, asteroidBody.vy, 0.001, "expected asteroid at centre to have zero vy")
end)
