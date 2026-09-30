local Lander = require("src.game.components.lander")
local Fuel = require("src.game.components.fuel")
local Bodies = require("src.sim.bodies")

local CONFIG = {
	landing = {
		maxSpeed = 400,
		refuelRate = 5,
	},
}

-- A contact whose normal points straight up (matching Lander's NOSE at
-- angle 0), with `speed` along that same normal so relVel's magnitude is
-- exactly `speed`.
local function contactWithSpeed(speed)
	return {
		point = { x = 0, y = 0 },
		normal = { x = 0, y = -1 },
		relVel = { x = 0, y = -speed },
	}
end

test("Lander.check lands at 0.9x max speed", function()
	local body = { angle = 0 }
	local contact = contactWithSpeed(CONFIG.landing.maxSpeed * 0.9)

	assertEqual("land", Lander.check(body, contact, CONFIG))
end)

test("Lander.check crashes at 1.1x max speed", function()
	local body = { angle = 0 }
	local contact = contactWithSpeed(CONFIG.landing.maxSpeed * 1.1)

	assertEqual("crash", Lander.check(body, contact, CONFIG))
end)

test("Lander.check lands a 360 px/s touch with the nose 90 degrees off the normal", function()
	local body = { angle = math.pi / 2 }
	local contact = contactWithSpeed(360)

	assertEqual("land", Lander.check(body, contact, CONFIG))
end)

test("Lander.check crashes a 440 px/s touch", function()
	local body = { angle = 0 }
	local contact = contactWithSpeed(440)

	assertEqual("crash", Lander.check(body, contact, CONFIG))
end)

test("Lander.tick refuels a tank ship via Fuel.add", function()
	local ship = {
		fuel = { amount = 0, capacity = 10, burnRate = 1 },
		lander = { state = "tank", host = nil },
	}
	local ctx = { dt = 1, config = CONFIG }

	Lander.tick(ship, ctx)

	assertNear(CONFIG.landing.refuelRate, ship.fuel.amount)
end)

test("Lander.tick does nothing while flying", function()
	local ship = {
		fuel = { amount = 0, capacity = 10, burnRate = 1 },
		lander = { state = "flying", host = nil },
	}
	local ctx = { dt = 1, config = CONFIG }

	Lander.tick(ship, ctx)

	assertNear(0, ship.fuel.amount)
end)

test("Lander.liftOff sets state back to flying and un-pins the body", function()
	local bodies = Bodies.new()
	local bodyId = Bodies.add(bodies, { x = 0, y = 0, vx = 0, vy = 0, pinned = true })
	local ship = {
		body = bodyId,
		lander = { state = "tank", host = { vertices = {} } },
	}
	local ctx = { sim = { bodies = bodies }, config = { ship = { thrustAccel = 100 } }, dt = 1 / 60, time = 0 }

	Lander.liftOff(ship, ctx)

	assertEqual("flying", ship.lander.state)
	assertTrue(ship.lander.host == nil)
	assertFalse(Bodies.get(bodies, bodyId).pinned)
end)
