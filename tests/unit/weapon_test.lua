local Weapon = require("src.game.components.weapon")
local Bodies = require("src.sim.bodies")
local Config = require("src.game.config")

local function newCtx(overrides)
	overrides = overrides or {}
	local bodies = Bodies.new()
	local ctx = {
		dt = 1 / 60,
		sim = { bodies = bodies },
		pools = { ships = {}, projectiles = {}, asteroids = {} },
		config = overrides.config or Config,
		intents = {},
	}
	return ctx, bodies
end

local function newShip(bodies, ctx, overrides)
	overrides = overrides or {}
	local body = { x = 0, y = 0, vx = 0, vy = 0, angle = 0 }
	local bodyId = Bodies.add(bodies, body)
	local ship = {
		id = bodyId,
		body = bodyId,
		player = 1,
		weapon = overrides.weapon or { kind = "shell", charging = false, charge = 0, prevFire = false },
	}
	table.insert(ctx.pools.ships, ship)
	return ship
end

test("a one-frame tap fires very close to minSpeed", function()
	local ctx, bodies = newCtx()
	local ship = newShip(bodies, ctx)
	local origin = { x = 0, y = 0 }
	local direction = { x = 0, y = -1 }

	ctx.intents[1] = { fire = true }
	Weapon.update(ship, ctx, origin, direction)
	ctx.intents[1] = { fire = false }
	Weapon.update(ship, ctx, origin, direction)

	assertEqual(1, #ctx.pools.projectiles, "expected the release to spawn a projectile")
	local projectile = ctx.pools.projectiles[1]
	local body = Bodies.get(bodies, projectile.body)
	local minSpeed = ctx.config.weapon.minSpeed
	local speed = math.abs(body.vy) -- direction.y is -1, so vy is negative
	-- One frame of charge accumulates slightly above minSpeed; tolerance accounts for this
	assertNear(minSpeed, speed, 5, "expected the shot to fire very close to minSpeed")
end)

test("a 1.5s hold fires at the midpoint speed", function()
	local ctx, bodies = newCtx()
	local ship = newShip(bodies, ctx)
	local origin = { x = 0, y = 0 }
	local direction = { x = 0, y = -1 }

	ctx.intents[1] = { fire = true }
	Weapon.update(ship, ctx, origin, direction)

	-- Hold for 1.5 seconds (half of chargeTime). Start with 1 frame already added,
	-- so loop for chargeTime/2 / dt - 1 frames to reach exactly 1.5 seconds
	local chargeTime = ctx.config.weapon.chargeTime
	local framesForHalfCharge = math.floor(chargeTime / 2 / ctx.dt) - 1
	for _ = 1, framesForHalfCharge do
		Weapon.update(ship, ctx, origin, direction)
	end

	ctx.intents[1] = { fire = false }
	Weapon.update(ship, ctx, origin, direction)

	assertEqual(1, #ctx.pools.projectiles, "expected the release to spawn a projectile")
	local projectile = ctx.pools.projectiles[1]
	local body = Bodies.get(bodies, projectile.body)
	local minSpeed = ctx.config.weapon.minSpeed
	local maxSpeed = ctx.config.weapon.maxSpeed
	local midSpeed = minSpeed + (maxSpeed - minSpeed) * 0.5
	-- Tolerance accounts for frame rounding and floating point precision
	assertNear(midSpeed, body.vy * -1, 5, "expected the shot to fire at approximately midpoint speed")
end)

test("a 5s hold fires at maxSpeed", function()
	local ctx, bodies = newCtx()
	local ship = newShip(bodies, ctx)
	local origin = { x = 0, y = 0 }
	local direction = { x = 0, y = -1 }

	ctx.intents[1] = { fire = true }
	Weapon.update(ship, ctx, origin, direction)

	-- Hold for 5 seconds (well over chargeTime of 3)
	local frames = math.floor(5 / ctx.dt)
	for _ = 1, frames do
		Weapon.update(ship, ctx, origin, direction)
	end

	ctx.intents[1] = { fire = false }
	Weapon.update(ship, ctx, origin, direction)

	assertEqual(1, #ctx.pools.projectiles, "expected the release to spawn a projectile")
	local projectile = ctx.pools.projectiles[1]
	local body = Bodies.get(bodies, projectile.body)
	local maxSpeed = ctx.config.weapon.maxSpeed
	local expectedVy = 0 + direction.y * maxSpeed
	assertNear(expectedVy, body.vy, 0.1, "expected the shot to fire at maxSpeed")
end)

test("no projectile spawns while fire is held", function()
	local ctx, bodies = newCtx()
	local ship = newShip(bodies, ctx)
	local origin = { x = 0, y = 0 }
	local direction = { x = 0, y = -1 }

	ctx.intents[1] = { fire = true }
	Weapon.update(ship, ctx, origin, direction)
	Weapon.update(ship, ctx, origin, direction)
	Weapon.update(ship, ctx, origin, direction)

	assertEqual(0, #ctx.pools.projectiles, "expected no projectile to spawn while fire is held")
end)

test("a dead ship mid-charge does not fire when prevFire is released", function()
	local ctx, bodies = newCtx()
	local ship = newShip(bodies, ctx)
	local origin = { x = 0, y = 0 }
	local direction = { x = 0, y = -1 }

	ctx.intents[1] = { fire = true }
	Weapon.update(ship, ctx, origin, direction)

	-- Hold for 1 second
	local frames = math.floor(1 / ctx.dt)
	for _ = 1, frames do
		Weapon.update(ship, ctx, origin, direction)
	end

	-- Ship dies mid-charge
	ship.dead = true

	-- Release fire on next frame
	ctx.intents[1] = { fire = false }
	Weapon.update(ship, ctx, origin, direction)

	assertEqual(0, #ctx.pools.projectiles, "expected no projectile to spawn when ship dies mid-charge and fire is released")
end)

test("Weapon.update does nothing without a weapon component", function()
	local ctx, bodies = newCtx()
	local ship = newShip(bodies, ctx)
	ship.weapon = nil
	local origin = { x = 0, y = 0 }
	local direction = { x = 0, y = -1 }

	ctx.intents[1] = { fire = true }
	Weapon.update(ship, ctx, origin, direction)

	assertEqual(0, #ctx.pools.projectiles)
end)
