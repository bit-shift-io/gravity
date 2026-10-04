local Match = require("src.game.match")
local Config = require("src.game.config")
local Bodies = require("src.sim.bodies")
local ProjectileSystem = require("src.game.systems.projectile_system")
local Airburst = require("src.game.ai.skills.airburst")

local DT = 1 / 60
local BLAST = Config.projectile.blastRadius

-- A heavy floor (top edge y = 100) with two spawn points on it.
local function floorLevel()
	local floor = {
		vertices = { { x = -600, y = 100 }, { x = 600, y = 100 }, { x = 600, y = 200 }, { x = -600, y = 200 } },
		mass = 40000,
	}
	local function point(x)
		return { x = x, y = 100, normal = { x = 0, y = -1 }, world = floor }
	end
	return { worlds = { floor }, spawnPoints = { point(-300), point(300) } }
end

-- Slot 1 is a keyboard enemy, slot 2 an AI (behaviour `behavior`, default
-- hunter). Ships are placed at fixed points: the enemy at (-300, 92), the
-- AI at (300, 92). Rounds never end.
local function newDuel(behavior)
	local config = setmetatable(
		{ round = setmetatable({ endDelay = math.huge }, { __index = Config.round }) },
		{ __index = Config }
	)
	local roster = {
		{ color = 1, binding = { kind = "keyboard", layout = "wasd" } },
		{ color = 2, binding = { kind = "ai", level = "hard", behavior = behavior or "hunter" } },
	}
	local ctx = Match.new(floorLevel(), config, 1, { roster = roster })
	ctx.dt = DT
	ctx.ai = {}
	local enemy = Bodies.get(ctx.sim.bodies, ctx.pools.ships[1].body)
	local own = Bodies.get(ctx.sim.bodies, ctx.pools.ships[2].body)
	enemy.x, enemy.y = -300, 92
	own.x, own.y = 300, 92
	ctx.intents[1] = { rotate = 0, thrust = false, fire = false }
	ctx.intents[2] = { rotate = 0, thrust = false, fire = false }
	return ctx
end

local function ship(ctx, slot)
	return ctx.pools.ships[slot]
end

local function bodyOf(ctx, slot)
	return Bodies.get(ctx.sim.bodies, ship(ctx, slot).body)
end

-- Fires slot 2's shell from (x, y) with velocity (vx, vy), armed unless
-- `unarmed`. Returns the shell body.
local function shell(ctx, x, y, vx, vy, unarmed)
	local projectile = ProjectileSystem.spawn(ctx, ship(ctx, 2), { x = x, y = y }, { x = 1, y = 0 }, 0)
	local body = Bodies.get(ctx.sim.bodies, projectile.body)
	body.vx, body.vy = vx or 0, vy or 0
	if not unarmed then
		projectile.age = Config.projectile.armDelay
		body.armed = true
	end
	return body
end

local function airburst(ctx)
	ctx.ai[2] = ctx.ai[2] or {}
	Airburst.update(ctx, 2, ship(ctx, 2), ctx.ai[2])
	return ctx.intents[2].fire
end

test("an armed shell with an enemy in blast radius is detonated", function()
	local ctx = newDuel()
	shell(ctx, -300 + BLAST - 5, 92)

	assertTrue(airburst(ctx))
end)

test("an armed shell with nothing in blast radius is held", function()
	local ctx = newDuel()
	shell(ctx, 0, -200)

	assertFalse(airburst(ctx))
end)

test("an unarmed shell is never detonated, even beside an enemy", function()
	local ctx = newDuel()
	shell(ctx, -300 + BLAST - 5, 92, 0, 0, true)

	assertFalse(airburst(ctx))
end)

test("an armed shell grazing an asteroid's edge is detonated", function()
	local ctx = newDuel()
	local radius = 40
	local rock = {
		x = 0, y = -200, vx = 0, vy = 0, angle = 0, angularVelocity = 0, mass = 1000, kind = "asteroid", radius = radius,
		vertices = { { x = -radius, y = -radius }, { x = radius, y = -radius }, { x = radius, y = radius }, { x = -radius, y = radius } },
	}
	table.insert(ctx.pools.asteroids, { body = Bodies.add(ctx.sim.bodies, rock), dead = false })
	shell(ctx, radius + BLAST - 5, -200)

	assertTrue(airburst(ctx))
end)

test("the AI's own ship in blast radius does not stop a detonation that catches an enemy", function()
	local ctx = newDuel()
	local own = bodyOf(ctx, 2)
	own.x, own.y = -300 + 2 * BLAST - 10, 92
	shell(ctx, -300 + BLAST - 5, 92)

	assertTrue(airburst(ctx))
end)

test("the AI's own ship alone in blast radius is not a reason to detonate", function()
	local ctx = newDuel()
	shell(ctx, 300 - BLAST + 5, 92)

	assertFalse(airburst(ctx))
end)

-- Moves a shell along its velocity for `steps` steps, airbursting after each
-- (the press is dropped each step). The fixtures fly left along y = -8,
-- passing 100 px above the enemy at step 60.
local function flyPast(ctx, body, steps)
	local fired = false
	for _ = 1, steps do
		body.x = body.x + body.vx * DT
		fired = airburst(ctx) or fired
		ctx.intents[2].fire = false
	end
	return fired
end

test("a shell closing on the enemy is held", function()
	local ctx = newDuel()
	local body = shell(ctx, 0, -8, -300, 0)

	assertFalse(flyPast(ctx, body, 50))
end)

test("a shell past its closest approach to the enemy is detonated as a miss", function()
	local ctx = newDuel()
	local body = shell(ctx, 0, -8, -300, 0)

	assertTrue(flyPast(ctx, body, 90))
end)

test("a miss is held while the AI's own ship is in blast radius", function()
	local ctx = newDuel()
	local own = bodyOf(ctx, 2)
	own.x, own.y = -400, 0
	local body = shell(ctx, 0, -8, -300, 0)
	flyPast(ctx, body, 75)
	body.x = own.x + BLAST - 5

	assertFalse(airburst(ctx))
end)

test("a held fire is released first so the next step is a fresh press", function()
	local ctx = newDuel()
	shell(ctx, -300 + BLAST - 5, 92)
	ship(ctx, 2).weapon.prevFire = true

	assertFalse(airburst(ctx))
	ship(ctx, 2).weapon.prevFire = false
	assertTrue(airburst(ctx))
end)

test("AI.fill airbursts for a personality and the press starts no charge", function()
	local ctx = newDuel("sniper")
	local body = shell(ctx, -300 + BLAST - 5, 92)
	local enemy = ship(ctx, 1)
	local weapon = ship(ctx, 2).weapon

	Match.step(ctx)

	assertTrue(body.dead, "shell detonated")
	assertTrue(enemy.dead, "enemy caught in the blast")
	assertFalse(weapon.charging, "no charge started")
end)
