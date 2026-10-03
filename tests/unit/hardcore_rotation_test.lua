local Match = require("src.game.match")
local Config = require("src.game.config")
local ShipSystem = require("src.game.systems.ship_system")
local Bodies = require("src.sim.bodies")

-- One flying ship on an empty level; ShipSystem.update is driven directly so
-- no round rules can end the round under the test.
local function newFlyingShip(opts)
	local ctx = Match.new({ worlds = {} }, Config, 1, opts)
	local ship = ShipSystem.spawn(ctx, 1, { x = 0, y = 0 })
	ctx.dt = 1 / 60
	return ctx, ship
end

test("hardcore on: rotating drains fuel at hardcore.rotationBurnRate", function()
	local ctx, ship = newFlyingShip({ hardcore = true })
	ctx.intents[1] = { rotate = 1, thrust = false }
	local before = ship.fuel.amount

	ShipSystem.update(ctx)

	assertNear(before - Config.hardcore.rotationBurnRate * ctx.dt, ship.fuel.amount, 1e-9)
end)

test("hardcore on: an empty tank cannot rotate", function()
	local ctx, ship = newFlyingShip({ hardcore = true })
	ship.fuel.amount = 0
	ctx.intents[1] = { rotate = 1, thrust = false }

	ShipSystem.update(ctx)

	local body = Bodies.get(ctx.sim.bodies, ship.body)
	assertEqual(0, body.angularVelocity)
end)

test("hardcore off: rotating is free, even on an empty tank", function()
	local ctx, ship = newFlyingShip()
	ctx.intents[1] = { rotate = 1, thrust = false }
	local before = ship.fuel.amount

	ShipSystem.update(ctx)
	assertEqual(before, ship.fuel.amount)

	ship.fuel.amount = 0
	ShipSystem.update(ctx)
	local body = Bodies.get(ctx.sim.bodies, ship.body)
	assertTrue(body.angularVelocity ~= 0)
end)

-- A landed ship refuels every frame, so the tank-mode fuel level is compared
-- against the same frame with hardcore off rather than against a constant.
local function tankFuelAfterAiming(hardcore)
	local ctx, ship = newFlyingShip({ hardcore = hardcore })
	ship.lander.state = "tank"
	Bodies.get(ctx.sim.bodies, ship.body).pinned = true
	ship.fuel.amount = ship.fuel.capacity / 2
	ctx.intents[1] = { rotate = 1, thrust = false }

	ShipSystem.update(ctx)

	assertTrue(ship.turret.angle ~= 0, "expected the turret to aim")
	return ship.fuel.amount
end

test("hardcore on: aiming the turret in tank mode burns no fuel", function()
	assertEqual(tankFuelAfterAiming(false), tankFuelAfterAiming(true))
end)
