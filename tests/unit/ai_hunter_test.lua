local Match = require("src.game.match")
local Config = require("src.game.config")
local Bodies = require("src.sim.bodies")
local Lander = require("src.game.components.lander")
local ProjectileSystem = require("src.game.systems.projectile_system")
local Danger = require("src.game.ai.skills.danger")

local DT = 1 / 60

-- A floor about as heavy as a generated world (top edge y = 100) and a
-- light ledge up and to the left of it. Spawn points: on the ledge at
-- (-300, 0) and on the floor at (200, 100), both normals straight up.
local function huntLevel()
	local floor = {
		vertices = { { x = -400, y = 100 }, { x = 400, y = 100 }, { x = 400, y = 200 }, { x = -400, y = 200 } },
		mass = 40000,
	}
	local ledge = {
		vertices = { { x = -320, y = 0 }, { x = -280, y = 0 }, { x = -280, y = 40 }, { x = -320, y = 40 } },
		mass = 2000,
	}
	local function point(x, y, world)
		return { x = x, y = y, normal = { x = 0, y = -1 }, world = world }
	end
	return { worlds = { floor, ledge }, spawnPoints = { point(-300, 0, ledge), point(200, 100, floor) } }
end

-- Slot 1 is a keyboard target that never moves, on the ledge; slot 2 is an
-- AI hunter at `level` on the floor. Rounds never end, so a kill doesn't
-- respawn anyone mid-scenario. `config` may override Config.
local function newHunt(level, config, opts)
	config = setmetatable({ round = setmetatable({ endDelay = math.huge }, { __index = Config.round }) }, { __index = config or Config })
	local roster = {
		{ color = 1, binding = { kind = "keyboard", layout = "wasd" } },
		{ color = 2, binding = { kind = "ai", level = level, behavior = "hunter" } },
	}
	local ctx = Match.new(huntLevel(), config, 1, { roster = roster, hardcore = opts and opts.hardcore })
	ctx.dt = DT
	-- Spawn points are drawn at random: make slot 1 the one on the ledge.
	local a = Bodies.get(ctx.sim.bodies, ctx.pools.ships[1].body)
	local b = Bodies.get(ctx.sim.bodies, ctx.pools.ships[2].body)
	if a.x > b.x then
		a.x, a.y, b.x, b.y = b.x, b.y, a.x, a.y
	end
	return ctx
end

local function shipOf(ctx, slot)
	for _, ship in ipairs(ctx.pools.ships) do
		if ship.player == slot then
			return ship
		end
	end
	return nil
end

local function bodyOf(ctx, ship)
	return Bodies.get(ctx.sim.bodies, ship.body)
end

local NEUTRAL = { rotate = 0, thrust = false, fire = false }

local function step(ctx)
	ctx.intents[1] = NEUTRAL
	Match.step(ctx)
	ctx.time = ctx.time + ctx.dt
end

-- Steps the hunt `steps` times (stopping early once the hunter dies),
-- calling `each(hunter, ctx)` after every step. Returns the hunter's
-- record and the modes it passed through, in order.
local function run(ctx, steps, each)
	local hunter = shipOf(ctx, 2)
	local modes = {}
	for _ = 1, steps do
		step(ctx)
		local mode = ctx.ai[2] and ctx.ai[2].mode
		if mode and modes[#modes] ~= mode then
			modes[#modes + 1] = mode
		end
		if each then
			each(hunter, ctx)
		end
		if hunter.dead then
			break
		end
	end
	return hunter, modes
end

local function seen(modes, mode)
	for _, m in ipairs(modes) do
		if m == mode then
			return true
		end
	end
	return false
end

test("a hunter leaves the ground within two seconds of round start", function()
	local ctx = newHunt("easy")
	local hunter = shipOf(ctx, 2)

	local flying = false
	run(ctx, 120, function()
		flying = flying or not Lander.isGrounded(hunter)
	end)

	assertTrue(flying)
end)

for _, level in ipairs({ "easy", "hard" }) do
	test("a " .. level .. " hunter survives a round against a stationary target", function()
		local ctx = newHunt(level)

		local hunter = run(ctx, 20 * 60)

		assertFalse(hunter.dead)
	end)
end

test("a hunter pursues its target and attacks from the air", function()
	local ctx = newHunt("hard")
	local hunter = shipOf(ctx, 2)
	local firedFlying = false

	local _, modes = run(ctx, 20 * 60, function()
		firedFlying = firedFlying or (ctx.intents[2].fire and not Lander.isGrounded(hunter))
	end)

	assertTrue(seen(modes, "pursue"))
	assertTrue(seen(modes, "attack"))
	assertTrue(firedFlying, "charged a shot in flight")
end)

test("a hunter fires only with a gravity-aware solution", function()
	local ctx = newHunt("hard")
	local fires = 0

	run(ctx, 20 * 60, function()
		if ctx.intents[2].fire then
			fires = fires + 1
			assertTrue(ctx.ai[2].aim.solved, "fire held without a solved shot")
		end
	end)

	assertTrue(fires > 0, "fixture: the hunter fires at all")
end)

test("a hunter that can't foresee a hit never fires", function()
	local blind = { predictionHorizon = 0.05 }
	local config = setmetatable({
		ai = setmetatable({ levels = { hard = setmetatable(blind, { __index = Config.ai.levels.hard }) } }, { __index = Config.ai }),
	}, { __index = Config })
	local ctx = newHunt("hard", config)

	run(ctx, 10 * 60, function()
		assertFalse(ctx.intents[2].fire)
	end)
end)

-- Steps until the hunter is airborne (bounded).
local function untilFlying(ctx)
	local hunter = shipOf(ctx, 2)
	for _ = 1, 300 do
		if not Lander.isGrounded(hunter) then
			break
		end
		step(ctx)
	end
	for _ = 1, 30 do
		step(ctx)
	end
	assertFalse(Lander.isGrounded(hunter), "fixture: the hunter is flying")
	return hunter
end

test("a flying hunter low on fuel lands to refuel", function()
	local ctx = newHunt("hard")
	local hunter = untilFlying(ctx)
	hunter.fuel.amount = Config.ai.refuelFuel / 2

	local landed = false
	local _, modes = run(ctx, 15 * 60, function()
		landed = landed or Lander.isGrounded(hunter)
	end)

	assertFalse(hunter.dead)
	assertTrue(seen(modes, "refuel"))
	assertTrue(landed)
end)

test("a refuelling hunter stays landed until its tank is refilled, then lifts off again", function()
	local ctx = newHunt("hard")
	local hunter = untilFlying(ctx)
	hunter.fuel.amount = Config.ai.refuelFuel / 2
	local landedAt, liftedWith

	run(ctx, 20 * 60, function()
		local grounded = Lander.isGrounded(hunter)
		if grounded and not landedAt then
			landedAt = ctx.time
		elseif landedAt and not grounded and not liftedWith then
			liftedWith = hunter.fuel.amount
		end
	end)

	assertTrue(landedAt ~= nil, "landed")
	assertTrue(liftedWith ~= nil, "lifted off again")
	assertTrue(liftedWith >= Config.ai.takeoffFuel - 0.5, "refilled before lifting off")
end)

test("a flying hunter evades a shell fired at it", function()
	local ctx = newHunt("hard")
	local hunter = untilFlying(ctx)
	local enemy = shipOf(ctx, 1)
	local body = bodyOf(ctx, hunter)
	-- Hovering still at (100, -150) with a slow shell 200 px straight above,
	-- falling down the same line.
	body.x, body.y, body.vx, body.vy = 100, -150, 0, 0
	ProjectileSystem.spawn(ctx, enemy, { x = 100, y = -350 }, { x = 0, y = 1 }, Config.weapon.minSpeed)
	local threats = Danger.scan(ctx.sim, ctx.level.worlds, body, Config, { dt = DT, horizon = 3 })
	local onCourse = false
	for _, threat in ipairs(threats) do
		onCourse = onCourse or threat.kind == "shell"
	end
	assertTrue(onCourse, "fixture: the shell is on course to hit")

	local _, modes = run(ctx, 4 * 60)

	assertFalse(hunter.dead)
	assertTrue(seen(modes, "evade"))
end)

-- Rotating burns fuel in hardcore too, so a hunter must head down to refuel
-- sooner: it keeps fuel to brake with (at least half of the landFuel a
-- hopper keeps for braking) at every moment in flight.
for _, level in ipairs({ "easy", "hard" }) do
	test("a hardcore " .. level .. " hunter survives a round and never flies near empty", function()
		local ctx = newHunt(level, nil, { hardcore = true })
		local lowest = math.huge

		local hunter = run(ctx, 40 * 60, function(h)
			if not Lander.isGrounded(h) then
				lowest = math.min(lowest, h.fuel.amount)
			end
		end)

		assertFalse(hunter.dead)
		assertTrue(lowest >= Config.ai.landFuel / 2, "lowest fuel in flight: " .. lowest)
	end)
end
