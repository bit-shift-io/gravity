local Fuel = require("src.game.components.fuel")

test("Fuel.consume burns burnRate * dt from amount", function()
	local fuel = { amount = 1, capacity = 1, burnRate = 0.2 }

	Fuel.consume(fuel, 1)

	assertNear(0.8, fuel.amount)
end)

test("Fuel.consume never goes below 0", function()
	local fuel = { amount = 0.1, capacity = 1, burnRate = 0.2 }

	Fuel.consume(fuel, 1)

	assertNear(0, fuel.amount)
end)

test("Fuel.isEmpty is true once amount reaches 0", function()
	local fuel = { amount = 0, capacity = 1, burnRate = 0.2 }

	assertTrue(Fuel.isEmpty(fuel))
end)

test("Fuel.isEmpty is false while amount remains", function()
	local fuel = { amount = 0.01, capacity = 1, burnRate = 0.2 }

	assertFalse(Fuel.isEmpty(fuel))
end)

test("Fuel.add refuels without exceeding capacity", function()
	local fuel = { amount = 0.9, capacity = 1, burnRate = 0.2 }

	Fuel.add(fuel, 0.5)

	assertNear(1, fuel.amount)
end)
