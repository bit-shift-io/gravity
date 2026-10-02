local Match = require("src.game.match")
local Config = require("src.game.config")
local Bodies = require("src.sim.bodies")
local AsteroidSystem = require("src.game.systems.asteroid_system")

local function addAsteroid(ctx, vertices, x, y, angle)
	local id = Bodies.add(ctx.sim.bodies, {
		x = x, y = y, vx = 0, vy = 0, angle = angle, angularVelocity = 0, mass = 1,
		kind = "asteroid", radius = 5, vertices = vertices,
	})
	local record = { id = id, body = id, dead = false, kind = "asteroid" }
	table.insert(ctx.pools.asteroids, record)
	return record, Bodies.get(ctx.sim.bodies, id)
end

local function hitWorld(ctx, body)
	AsteroidSystem.handleContacts(ctx, {
		{ kind = "asteroidWorld", a = body, b = {}, point = { x = body.x + 1, y = body.y }, normal = { x = -1, y = 0 } },
	})
end

local SMALL = { { x = -3, y = -3 }, { x = 3, y = -3 }, { x = 0, y = 4 } }

test("a small asteroid destroyed by an impact emits an asteroidDeath event with its outline", function()
	local ctx = Match.new({ worlds = {} }, Config)
	ctx.time = 4
	local record, body = addAsteroid(ctx, SMALL, 100, 50, 0.5)

	hitWorld(ctx, body)

	assertTrue(record.dead)
	local event = ctx.events[#ctx.events]
	assertEqual("asteroidDeath", event.kind)
	assertEqual(100, event.x)
	assertEqual(50, event.y)
	assertEqual(0.5, event.angle)
	assertEqual(4, event.time)
	assertEqual(3, #event.vertices)
end)

test("a large asteroid that splits emits no asteroidDeath event", function()
	local ctx = Match.new({ worlds = {} }, Config)
	local big = { { x = -40, y = -40 }, { x = 40, y = -40 }, { x = 40, y = 40 }, { x = -40, y = 40 } }
	local _, body = addAsteroid(ctx, big, 100, 50, 0)

	hitWorld(ctx, body)

	assertEqual(0, #ctx.events)
end)

test("an asteroidDeath event survives Match.step long enough to animate, then is pruned", function()
	local ctx = Match.new({ worlds = {} }, Config)
	ctx.dt = 1 / 60
	local _, body = addAsteroid(ctx, SMALL, 100, 50, 0)
	hitWorld(ctx, body)

	for _ = 1, 40 do -- ~0.67s
		ctx.time = ctx.time + ctx.dt -- the app advances time (match_state.lua)
		Match.step(ctx)
	end
	assertEqual("asteroidDeath", ctx.events[1] and ctx.events[1].kind)

	for _ = 1, 120 do -- ~2.7s total
		ctx.time = ctx.time + ctx.dt -- the app advances time (match_state.lua)
		Match.step(ctx)
	end
	assertEqual(0, #ctx.events)
end)
