local Lifetime = require("src.game.components.lifetime")

test("Lifetime.tick counts down remaining time", function()
	local record = { dead = false, lifetime = { remaining = 1 } }
	local ctx = { dt = 0.4 }

	Lifetime.tick(record, ctx)

	assertNear(0.6, record.lifetime.remaining)
	assertFalse(record.dead)
end)

test("Lifetime.tick marks the record dead once remaining time runs out", function()
	local record = { dead = false, lifetime = { remaining = 0.3 } }
	local ctx = { dt = 0.4 }

	Lifetime.tick(record, ctx)

	assertTrue(record.dead, "expected the record to be marked dead on expiry")
end)

test("Lifetime.tick does nothing to a record with no lifetime component", function()
	local record = { dead = false }
	local ctx = { dt = 1 }

	Lifetime.tick(record, ctx)

	assertFalse(record.dead)
end)
