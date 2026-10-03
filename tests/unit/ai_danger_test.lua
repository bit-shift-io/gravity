local Danger = require("src.game.ai.skills.danger")
local Config = require("src.game.config")
local Field = require("src.sim.field")
local Bodies = require("src.sim.bodies")

local DT = 1 / 60
local SHIP_RADIUS = Config.ship.collisionRadius

-- A massless floor (no pull, so straight-line times are exact) whose top
-- edge is y = 100.
local function floorWorld(mass)
	return {
		vertices = { { x = -400, y = 100 }, { x = 400, y = 100 }, { x = 400, y = 200 }, { x = -400, y = 200 } },
		mass = mass or 0,
	}
end

local function newSim(worlds)
	local field, boundaryField = Field.bake({ worlds = worlds }, Config)
	return { field = field, boundaryField = boundaryField, bodies = Bodies.new() }
end

local function addShip(sim, x, y, vx, vy, pinned)
	local body = {
		x = x, y = y, vx = vx or 0, vy = vy or 0, angle = 0, angularVelocity = 0,
		mass = Config.ship.mass, kind = "ship", radius = SHIP_RADIUS, pinned = pinned,
	}
	Bodies.add(sim.bodies, body)
	return body
end

local function addShell(sim, x, y, vx, vy)
	Bodies.add(sim.bodies, {
		x = x, y = y, vx = vx, vy = vy, angle = 0,
		mass = Config.projectile.mass, kind = "projectile", radius = Config.projectile.radius, armed = true,
	})
end

local function addAsteroid(sim, x, y, vx, vy, radius)
	Bodies.add(sim.bodies, {
		x = x, y = y, vx = vx, vy = vy, angle = 0, angularVelocity = 0,
		mass = 1000, kind = "asteroid", radius = radius,
		vertices = { { x = -radius, y = -radius }, { x = radius, y = -radius }, { x = radius, y = radius }, { x = -radius, y = radius } },
	})
end

local function scan(sim, worlds, ship, horizon)
	return Danger.scan(sim, worlds, ship, Config, { dt = DT, horizon = horizon or 3 })
end

test("a shell on a collision course reports its time to impact", function()
	local sim = newSim({})
	local ship = addShip(sim, 0, 0, 0, 0, true)
	addShell(sim, -200, 0, 400, 0)

	local threats = scan(sim, {}, ship)

	assertEqual(1, #threats)
	assertEqual("shell", threats[1].kind)
	-- Contact once the gap closes to ship + shell radius: 188 px at 400 px/s.
	assertNear((200 - SHIP_RADIUS - Config.projectile.radius) / 400, threats[1].time, DT)
end)

test("a shell that passes by reports no threat", function()
	local sim = newSim({})
	local ship = addShip(sim, 0, 0, 0, 0, true)
	addShell(sim, -200, -50, 400, 0)

	assertEqual(0, #scan(sim, {}, ship))
end)

test("a shell beyond the horizon reports no threat", function()
	local sim = newSim({})
	local ship = addShip(sim, 0, 0, 0, 0, true)
	addShell(sim, -200, 0, 400, 0)

	assertEqual(0, #scan(sim, {}, ship, 0.25))
end)

test("a shell landing within blast radius of a landed ship is a threat", function()
	local worlds = { floorWorld() }
	local sim = newSim(worlds)
	local ship = addShip(sim, 0, 92, 0, 0, true)
	addShell(sim, 20, -100, 0, 300) -- falls past the hull, onto the floor beside it

	local threats = scan(sim, worlds, ship)

	assertEqual(1, #threats)
	assertEqual("shell", threats[1].kind)
	assertNear(200 / 300, threats[1].time, 2 * DT)
end)

test("an asteroid on a collision course reports its time to impact", function()
	local sim = newSim({})
	local ship = addShip(sim, 0, 0, 0, 0, true)
	addAsteroid(sim, 300, 0, -100, 0, 30)

	local threats = scan(sim, {}, ship)

	assertEqual(1, #threats)
	assertEqual("asteroid", threats[1].kind)
	assertNear((300 - 30 - SHIP_RADIUS) / 100, threats[1].time, DT)
end)

test("a flying ship falling onto a world reports the world with impact speed", function()
	local worlds = { floorWorld() }
	local sim = newSim(worlds)
	local ship = addShip(sim, 0, 0, 0, 200)

	local threats = scan(sim, worlds, ship)

	assertEqual(1, #threats)
	assertEqual("world", threats[1].kind)
	assertNear(0.5, threats[1].time, DT)
	assertNear(200, threats[1].speed, 1)
end)

test("a landed ship reports no world threat", function()
	local worlds = { floorWorld() }
	local sim = newSim(worlds)
	local ship = addShip(sim, 0, 92, 0, 0, true)

	assertEqual(0, #scan(sim, worlds, ship))
end)

test("a flying ship heading out of the arena reports the hard boundary", function()
	local sim = newSim({})
	local hard = sim.boundaryField.hardBoundary
	local ship = addShip(sim, hard - 80, 0, 200, 0)

	local threats = scan(sim, {}, ship)

	assertEqual(1, #threats)
	assertEqual("boundary", threats[1].kind)
	assertNear((80 - SHIP_RADIUS) / 200, threats[1].time, 0.05)
end)

test("threats are listed soonest first", function()
	local sim = newSim({})
	local ship = addShip(sim, 0, 0, 0, 0, true)
	addShell(sim, -300, 0, 400, 0)
	addShell(sim, 0, -150, 0, 400)

	local threats = scan(sim, {}, ship)

	assertEqual(2, #threats)
	assertTrue(threats[1].time < threats[2].time)
	assertNear(0, threats[1].x, 1e-9, "the shell from above arrives first")
end)
