local Bodies = require("src.sim.bodies")

test("Bodies.add returns an id that Bodies.get resolves back to the same body", function()
	local store = Bodies.new()
	local body = { x = 10, y = 20 }

	local id = Bodies.add(store, body)

	assertEqual(body, Bodies.get(store, id))
end)

test("Bodies.get returns nil for an id that was never added", function()
	local store = Bodies.new()

	assertTrue(Bodies.get(store, 999) == nil)
end)

test("a stale body id returns nil after sweep and slot reuse", function()
	local store = Bodies.new()
	local firstId = Bodies.add(store, { x = 1, y = 1 })

	Bodies.markDead(store, firstId)
	Bodies.sweep(store)

	-- Reuse the freed slot.
	local secondId = Bodies.add(store, { x = 2, y = 2 })

	assertTrue(Bodies.get(store, firstId) == nil, "expected the stale id to resolve to nil, not the reused slot")
	assertTrue(Bodies.get(store, secondId) ~= nil, "expected the new id to resolve to the new body")
end)

test("Bodies.markDead makes a body invisible to Bodies.get even before sweep", function()
	local store = Bodies.new()
	local id = Bodies.add(store, { x = 1, y = 1 })

	Bodies.markDead(store, id)

	assertTrue(Bodies.get(store, id) == nil)
end)

test("Bodies.effectiveMass is just the body's own mass with no riders", function()
	local store = Bodies.new()
	local id = Bodies.add(store, { x = 0, y = 0, mass = 10 })
	local body = Bodies.get(store, id)

	assertNear(10, Bodies.effectiveMass(store, body))
end)

test("Bodies.effectiveMass sums the body's mass plus every live rider's mass", function()
	local store = Bodies.new()
	local hostId = Bodies.add(store, { x = 0, y = 0, mass = 10 })
	local riderId = Bodies.add(store, { x = 0, y = 0, mass = 3 })
	local host = Bodies.get(store, hostId)
	host.riders = { riderId }

	assertNear(13, Bodies.effectiveMass(store, host))
end)

test("Bodies.effectiveMass skips a stale rider id rather than erroring", function()
	local store = Bodies.new()
	local hostId = Bodies.add(store, { x = 0, y = 0, mass = 10 })
	local riderId = Bodies.add(store, { x = 0, y = 0, mass = 3 })
	local host = Bodies.get(store, hostId)
	host.riders = { riderId }

	Bodies.markDead(store, riderId)
	Bodies.sweep(store)

	assertNear(10, Bodies.effectiveMass(store, host))
end)
