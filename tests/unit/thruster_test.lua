local Thruster = require("src.game.components.thruster")
local Bodies = require("src.sim.bodies")

local function newShip(bodies, overrides)
	overrides = overrides or {}
	local body = { x = 0, y = 0, vx = 0, vy = 0, angle = 0 }
	local bodyId = Bodies.add(bodies, body)

	return {
		body = bodyId,
		player = 1,
		fuel = overrides.fuel or { amount = 1, capacity = 1, burnRate = 0.2 },
		thruster = { accel = overrides.accel or 100 },
	}
end

local function newCtx(bodies, intent, dt)
	return {
		dt = dt or 1,
		sim = { bodies = bodies },
		intents = { [1] = intent },
	}
end

test("Thruster.apply accelerates the body along its facing direction when thrust intent is held", function()
	local bodies = Bodies.new()
	local ship = newShip(bodies)
	local ctx = newCtx(bodies, { thrust = true, rotate = 0 })

	Thruster.apply(ship, ctx)

	local body = Bodies.get(bodies, ship.body)
	assertTrue(body.vx ~= 0 or body.vy ~= 0, "expected thrust to change velocity")
end)

test("Thruster.apply burns fuel while thrust intent is held", function()
	local bodies = Bodies.new()
	local ship = newShip(bodies)
	local ctx = newCtx(bodies, { thrust = true, rotate = 0 })

	Thruster.apply(ship, ctx)

	assertNear(0.8, ship.fuel.amount)
end)

test("Thruster.apply does nothing when thrust intent is not held", function()
	local bodies = Bodies.new()
	local ship = newShip(bodies)
	local ctx = newCtx(bodies, { thrust = false, rotate = 0 })

	Thruster.apply(ship, ctx)

	local body = Bodies.get(bodies, ship.body)
	assertNear(0, body.vx)
	assertNear(0, body.vy)
	assertNear(1, ship.fuel.amount)
end)

test("Thruster.apply does nothing when the tank is empty", function()
	local bodies = Bodies.new()
	local ship = newShip(bodies, { fuel = { amount = 0, capacity = 1, burnRate = 0.2 } })
	local ctx = newCtx(bodies, { thrust = true, rotate = 0 })

	Thruster.apply(ship, ctx)

	local body = Bodies.get(bodies, ship.body)
	assertNear(0, body.vx)
	assertNear(0, body.vy)
	assertNear(0, ship.fuel.amount)
end)
