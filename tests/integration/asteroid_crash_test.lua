-- Any ship-vs-asteroid contact crashes, however slow (docs/CONTEXT.md
-- "Crash"). The asteroid is injected directly so the test controls its
-- exact position and velocity.
local GameHarness = require("tests.support.game_harness")
local FrameStepper = require("tests.support.frame_stepper")
local Bodies = require("src.sim.bodies")
local Poly = require("src.core.poly")

local function injectAsteroid(ctx, fields)
	local body = {
		x = fields.x,
		y = fields.y,
		vx = 0,
		vy = 0,
		angle = 0,
		angularVelocity = 0,
		mass = 500,
		kind = "asteroid",
		radius = 141,
		vertices = Poly.normalize({
			{ x = -100, y = -100 },
			{ x = 100, y = -100 },
			{ x = 100, y = 100 },
			{ x = -100, y = 100 },
		}),
	}
	local bodyId = Bodies.add(ctx.sim.bodies, body)
	table.insert(ctx.pools.asteroids, { id = bodyId, body = bodyId, dead = false, kind = "asteroid" })
	return body
end

test("a slow ship touching an asteroid dies with a crash event", function()
	local level = {
		worlds = {},
		spawnPoints = { { x = 640, y = 100 }, { x = -1000000, y = 100 } },
		asteroids = { maxAlive = 0 },
	}
	local game = GameHarness.startMatch(level)
	local ctx = game.ctx
	local ship = ctx.pools.ships[1]
	local shipBody = Bodies.get(ctx.sim.bodies, ship.body)

	injectAsteroid(ctx, { x = 640, y = 300 })

	-- Already touching the asteroid's top edge (y = 200), nearly at rest.
	shipBody.x = 640
	shipBody.y = 201
	shipBody.vx = 0
	shipBody.vy = 5

	FrameStepper.step(game, 5)

	assertTrue(ship.dead or #ctx.pools.ships == 0, "expected the ship to be destroyed")
	local crashed = false
	for _, event in ipairs(ctx.events) do
		if event.kind == "crash" then
			crashed = true
		end
	end
	assertTrue(crashed, "expected a crash event")
end)
