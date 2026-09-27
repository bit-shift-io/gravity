local BoundarySystem = require("src.game.systems.boundary_system")
local Bodies = require("src.sim.bodies")

local SCREEN_WIDTH = 1280
local SCREEN_HEIGHT = 720
local MARGIN = 128

local CONFIG = {
	boundary = {
		margin = MARGIN,
	},
}

test("BoundarySystem marks a ship just inside the margin as not dead", function()
	local bodies = Bodies.new()
	local bodyId = Bodies.add(bodies, { x = -MARGIN, y = 360 })
	local pools = {
		ships = {
			{ body = bodyId, dead = false },
		},
		projectiles = {},
		asteroids = {},
	}
	local ctx = { pools = pools, sim = { bodies = bodies }, config = CONFIG }

	BoundarySystem.update(ctx)

	local body = Bodies.get(bodies, bodyId)
	assertFalse(body.dead, "expected a ship just inside the margin to survive")
end)

test("BoundarySystem marks a projectile just outside the margin as dead", function()
	local bodies = Bodies.new()
	local bodyId = Bodies.add(bodies, { x = -MARGIN - 1, y = 360 })
	local pools = {
		ships = {},
		projectiles = {
			{ body = bodyId, dead = false },
		},
		asteroids = {},
	}
	local ctx = { pools = pools, sim = { bodies = bodies }, config = CONFIG }

	BoundarySystem.update(ctx)

	local record = pools.projectiles[1]
	assertTrue(record.dead, "expected a projectile just outside the margin to be marked dead")
end)

test("BoundarySystem marks ships just outside the margin as dead", function()
	local bodies = Bodies.new()
	local bodyId = Bodies.add(bodies, { x = SCREEN_WIDTH + MARGIN + 1, y = 360 })
	local pools = {
		ships = {
			{ body = bodyId, dead = false },
		},
		projectiles = {},
		asteroids = {},
	}
	local ctx = { pools = pools, sim = { bodies = bodies }, config = CONFIG }

	BoundarySystem.update(ctx)

	local record = pools.ships[1]
	assertTrue(record.dead, "expected a ship just outside the margin to be marked dead")
end)

test("BoundarySystem marks an asteroid just outside the margin as dead", function()
	local bodies = Bodies.new()
	local bodyId = Bodies.add(bodies, { x = 640, y = -MARGIN - 1 })
	local pools = {
		ships = {},
		projectiles = {},
		asteroids = {
			{ body = bodyId, dead = false },
		},
	}
	local ctx = { pools = pools, sim = { bodies = bodies }, config = CONFIG }

	BoundarySystem.update(ctx)

	local record = pools.asteroids[1]
	assertTrue(record.dead, "expected an asteroid just outside the margin to be marked dead")
end)
