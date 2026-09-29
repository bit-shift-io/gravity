local Turret = require("src.game.components.turret")
local Bodies = require("src.sim.bodies")
local Vec2 = require("src.core.vec2")

local CONFIG = {
	tank = {
		turretLimit = math.rad(80),
		turretSpeed = 1,
		barrelLength = 12,
	},
}

test("Turret.reset zeroes the angle", function()
	local ship = {
		turret = { angle = math.rad(45) },
	}

	Turret.reset(ship)

	assertNear(0, ship.turret.angle, 0.0001)
end)

test("Turret.aim clamps to +limit when spinning right beyond the limit", function()
	local ship = {
		turret = { angle = 0 },
	}
	local ctx = {
		config = CONFIG,
		dt = 1,
		intents = {
			[1] = { rotate = 1 },
		},
	}

	-- Spin right for many seconds to exceed the limit
	for _ = 1, 100 do
		Turret.aim(ship, ctx, 1)
	end

	assertNear(CONFIG.tank.turretLimit, ship.turret.angle, 0.0001, "expected angle clamped to +limit")
end)

test("Turret.aim clamps to -limit when spinning left beyond the limit", function()
	local ship = {
		turret = { angle = 0 },
	}
	local ctx = {
		config = CONFIG,
		dt = 1,
		intents = {
			[1] = { rotate = -1 },
		},
	}

	-- Spin left for many seconds to exceed the limit
	for _ = 1, 100 do
		Turret.aim(ship, ctx, 1)
	end

	assertNear(-CONFIG.tank.turretLimit, ship.turret.angle, 0.0001, "expected angle clamped to -limit")
end)

test("Turret.aim does not move when rotate intent is 0", function()
	local ship = {
		turret = { angle = 0 },
	}
	local ctx = {
		config = CONFIG,
		dt = 1,
		intents = {
			[1] = { rotate = 0 },
		},
	}

	Turret.aim(ship, ctx, 1)

	assertNear(0, ship.turret.angle, 0.0001)
end)

test("Turret.muzzle at angle 0 points along body's nose direction", function()
	local bodies = Bodies.new()
	local bodyId = Bodies.add(bodies, {
		x = 100,
		y = 200,
		angle = 0,
	})

	local ship = {
		body = bodyId,
		turret = { angle = 0 },
	}

	local ctx = {
		sim = { bodies = bodies },
		config = CONFIG,
	}

	local tip, dir = Turret.muzzle(ship, ctx)

	-- Nose points at angle 0 means direction (0, -1)
	assertNear(100, tip.x, 0.0001, "expected tip x at body x")
	assertNear(200 - CONFIG.tank.barrelLength, tip.y, 0.0001, "expected tip y at body y - barrel length")
	assertNear(0, dir.x, 0.0001, "expected dir x = 0")
	assertNear(-1, dir.y, 0.0001, "expected dir y = -1 (nose up)")
end)

test("Turret.muzzle at body angle 90 degrees points along body's turned nose", function()
	local bodies = Bodies.new()
	local bodyId = Bodies.add(bodies, {
		x = 100,
		y = 200,
		angle = math.pi / 2,
	})

	local ship = {
		body = bodyId,
		turret = { angle = 0 },
	}

	local ctx = {
		sim = { bodies = bodies },
		config = CONFIG,
	}

	local tip, dir = Turret.muzzle(ship, ctx)

	-- Body at 90 degrees means nose points right (1, 0)
	assertNear(100 + CONFIG.tank.barrelLength, tip.x, 0.0001, "expected tip x at body x + barrel")
	assertNear(200, tip.y, 0.0001, "expected tip y at body y")
	assertNear(1, dir.x, 0.0001, "expected dir x = 1 (nose right)")
	assertNear(0, dir.y, 0.0001, "expected dir y = 0")
end)

test("Turret.muzzle combines body angle and turret angle", function()
	local bodies = Bodies.new()
	local bodyId = Bodies.add(bodies, {
		x = 100,
		y = 200,
		angle = 0,
	})

	local ship = {
		body = bodyId,
		turret = { angle = math.pi / 2 },
	}

	local ctx = {
		sim = { bodies = bodies },
		config = CONFIG,
	}

	local tip, dir = Turret.muzzle(ship, ctx)

	-- Body at 0, turret at 90 means world aim is 90 (pointing right)
	assertNear(100 + CONFIG.tank.barrelLength, tip.x, 0.0001, "expected tip x at body x + barrel")
	assertNear(200, tip.y, 0.0001, "expected tip y at body y")
	assertNear(1, dir.x, 0.0001, "expected dir x = 1 (nose right)")
	assertNear(0, dir.y, 0.0001, "expected dir y = 0")
end)
