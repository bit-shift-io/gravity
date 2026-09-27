local Lander = require("src.game.components.lander")
local Fuel = require("src.game.components.fuel")
local Bodies = require("src.sim.bodies")

local CONFIG = {
	landing = {
		maxSpeed = 40,
		maxAngle = 0.4,
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

test("Lander.check lands at 0.9x max speed with the nose aligned to the normal", function()
	local body = { angle = 0 }
	local contact = contactWithSpeed(CONFIG.landing.maxSpeed * 0.9)

	assertEqual("land", Lander.check(body, contact, CONFIG))
end)

test("Lander.check crashes at 1.1x max speed even with the nose aligned to the normal", function()
	local body = { angle = 0 }
	local contact = contactWithSpeed(CONFIG.landing.maxSpeed * 1.1)

	assertEqual("crash", Lander.check(body, contact, CONFIG))
end)

test("Lander.check lands at 0.9x max angle at a safe speed", function()
	local body = { angle = CONFIG.landing.maxAngle * 0.9 }
	local contact = contactWithSpeed(0)

	assertEqual("land", Lander.check(body, contact, CONFIG))
end)

test("Lander.check crashes at 1.1x max angle even at a safe speed", function()
	local body = { angle = CONFIG.landing.maxAngle * 1.1 }
	local contact = contactWithSpeed(0)

	assertEqual("crash", Lander.check(body, contact, CONFIG))
end)

test("Lander.tick refuels a landed ship via Fuel.add", function()
	local ship = {
		fuel = { amount = 0, capacity = 10, burnRate = 1 },
		lander = { state = "landed", host = nil },
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
	local bodyId = Bodies.add(bodies, { x = 0, y = 0, pinned = true })
	local ship = {
		body = bodyId,
		lander = { state = "landed", host = { vertices = {} } },
	}
	local ctx = { sim = { bodies = bodies } }

	Lander.liftOff(ship, ctx)

	assertEqual("flying", ship.lander.state)
	assertTrue(ship.lander.host == nil)
	assertFalse(Bodies.get(bodies, bodyId).pinned)
end)
