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
		config = Config,
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
		weapon = overrides.weapon or { kind = "cannon", cooldown = 0 },
	}
	table.insert(ctx.pools.ships, ship)
	return ship
end

test("Weapon.tryFire spawns a projectile when fire intent is held and off cooldown", function()
	local ctx, bodies = newCtx()
	local ship = newShip(bodies, ctx)
	ctx.intents[1] = { fire = true }

	Weapon.tryFire(ship, ctx)

	assertEqual(1, #ctx.pools.projectiles, "expected one projectile to be spawned")
end)

test("Weapon.tryFire does nothing without a fire intent", function()
	local ctx, bodies = newCtx()
	local ship = newShip(bodies, ctx)
	ctx.intents[1] = { fire = false }

	Weapon.tryFire(ship, ctx)

	assertEqual(0, #ctx.pools.projectiles)
end)

test("cooldown blocks a second shot on the very next frame", function()
	local ctx, bodies = newCtx()
	local ship = newShip(bodies, ctx)
	ctx.intents[1] = { fire = true }

	Weapon.tryFire(ship, ctx)
	assertEqual(1, #ctx.pools.projectiles)
	assertTrue(ship.weapon.cooldown > 0, "expected firing to set the cooldown")

	-- Same frame's worth of dt elapsed, cooldown not yet ticked down --
	-- still on cooldown, so a second tryFire this "frame" must not fire.
	Weapon.tryFire(ship, ctx)
	assertEqual(1, #ctx.pools.projectiles, "expected the cooldown to block a second shot")
end)

test("Weapon.tick counts the cooldown down over time, and a shot fires again once it reaches zero", function()
	local ctx, bodies = newCtx()
	local ship = newShip(bodies, ctx)
	ctx.intents[1] = { fire = true }

	Weapon.tryFire(ship, ctx)
	assertEqual(1, #ctx.pools.projectiles)

	local cooldown = ctx.config.projectile.cooldown
	local frames = math.ceil(cooldown / ctx.dt) + 1
	for _ = 1, frames do
		Weapon.tick(ship, ctx)
	end
	assertNear(0, ship.weapon.cooldown)

	Weapon.tryFire(ship, ctx)
	assertEqual(2, #ctx.pools.projectiles, "expected a second shot once the cooldown reached zero")
end)

test("Weapon.tryFire errors clearly on an unknown weapon kind", function()
	local ctx, bodies = newCtx()
	local ship = newShip(bodies, ctx, { weapon = { kind = "laser", cooldown = 0 } })
	ctx.intents[1] = { fire = true }

	local ok, err = pcall(Weapon.tryFire, ship, ctx)

	assertFalse(ok, "expected an unknown weapon kind to error")
	assertTrue(string.find(tostring(err), "laser") ~= nil, "expected the error to name the unknown kind")
end)

test("Weapon.tryFire does nothing without a weapon component", function()
	local ctx, bodies = newCtx()
	local ship = newShip(bodies, ctx)
	ship.weapon = nil
	ctx.intents[1] = { fire = true }

	Weapon.tryFire(ship, ctx)

	assertEqual(0, #ctx.pools.projectiles)
end)
