local Match = require("src.game.match")
local Config = require("src.game.config")
local Bodies = require("src.sim.bodies")
local Lander = require("src.game.components.lander")
local ProjectileSystem = require("src.game.systems.projectile_system")
local Aim = require("src.game.ai.skills.aim")
local Danger = require("src.game.ai.skills.danger")
local Flight = require("src.game.ai.skills.flight")

local DT = 1 / 60

-- A floor about as heavy as a generated world (~117 px/s^2 at its top edge,
-- y = 100) and a light ledge up and to the left of it, inside a floor
-- tank's turret reach. Spawn points: on the ledge at (-300, 0) and on the
-- floor at (0, 100), both normals straight up.
local function duelLevel()
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
	return { worlds = { floor, ledge }, spawnPoints = { point(-300, 0, ledge), point(0, 100, floor) } }
end

-- Slot 1 is a keyboard enemy on the ledge; slot 2 is on the floor at x = 0,
-- an AI hopper at `level` or a keyboard tank when `level` is nil. Rounds
-- never end, so a kill doesn't respawn anyone mid-scenario.
local function newDuel(level, config)
	config = setmetatable({ round = setmetatable({ endDelay = math.huge }, { __index = Config.round }) }, { __index = config or Config })
	local second = level and { kind = "ai", level = level, behavior = "hopper" } or { kind = "keyboard", layout = "ijkl" }
	local roster = {
		{ color = 1, binding = { kind = "keyboard", layout = "wasd" } },
		{ color = 2, binding = second },
	}
	local ctx = Match.new(duelLevel(), config, 1, { roster = roster })
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

local function step(ctx, intents)
	for slot, intent in pairs(intents or {}) do
		ctx.intents[slot] = intent
	end
	ctx.intents[1] = ctx.intents[1] or NEUTRAL
	Match.step(ctx)
	ctx.time = ctx.time + ctx.dt
end

-- Fires the enemy's gravity-aware shot at slot 2, as a full-skill player
-- would: solved with the aim skill, spawned at the solved speed.
local function fireAtSecond(ctx)
	local enemy = shipOf(ctx, 1)
	local from = bodyOf(ctx, enemy)
	local target = bodyOf(ctx, shipOf(ctx, 2))
	local muzzle = Config.tank.barrelLength
	local solution = Aim.solve(ctx.sim, ctx.level.worlds,
		{ x = from.x, y = from.y, vx = 0, vy = 0, muzzle = muzzle },
		{ x = target.x, y = target.y, radius = target.radius }, Config, { dt = DT, horizon = 3 })
	assertTrue(solution ~= nil, "fixture: the enemy has a shot")
	local dx, dy = math.sin(solution.angle), -math.cos(solution.angle)
	local fraction = solution.charge / Config.weapon.chargeTime
	local speed = Config.weapon.minSpeed + (Config.weapon.maxSpeed - Config.weapon.minSpeed) * fraction
	ProjectileSystem.spawn(ctx, enemy, { x = from.x + dx * muzzle, y = from.y + dy * muzzle }, { x = dx, y = dy }, speed)
end

-- Steps until the enemy's shell is gone (bounded), returning slot 2's record.
local function runOutShell(ctx, maxSteps)
	local second = shipOf(ctx, 2)
	local enemy = shipOf(ctx, 1)
	for _ = 1, maxSteps or 300 do
		if not enemy.weapon.shell then
			break
		end
		step(ctx)
	end
	return second
end

test("Flight.liftOff lifts a tank straight up its surface normal", function()
	local ctx = newDuel(nil)
	local ship = shipOf(ctx, 2)
	local body = bodyOf(ctx, ship)
	local x0, y0 = body.x, body.y

	for _ = 1, 20 do
		step(ctx, { [2] = Flight.liftOff() })
	end

	assertFalse(ship.dead)
	assertFalse(Lander.isGrounded(ship))
	assertTrue(body.y < y0 - 10, "rose off the floor")
	assertTrue(math.abs(body.x - x0) < 0.1 * (y0 - body.y), "rose along the normal, not sideways")
end)

-- Slot 2 flying nose-up 400 px above the floor, falling at 300 px/s: left
-- to coast it strikes the floor faster than the landing check allows.
local function fallingDuel()
	local ctx = newDuel(nil)
	local ship = shipOf(ctx, 2)
	local body = bodyOf(ctx, ship)
	ship.lander.state = "flying"
	body.pinned = false
	body.y, body.vy, body.angle = -300, 300, 0
	return ctx, ship, body
end

local function landIntent(ctx, ship, body)
	local threats = Danger.scan(ctx.sim, ctx.level.worlds, body, Config, { dt = DT, horizon = 3 })
	return Flight.land(ctx.sim, body, threats, Config, { fuel = ship.fuel, hold = DT })
end

test("fixture: a coasting fall onto the floor is a crash", function()
	local ctx, ship = fallingDuel()

	for _ = 1, 300 do
		step(ctx)
		if ship.dead then
			break
		end
	end

	assertTrue(ship.dead)
end)

test("Flight.land brakes so the touchdown passes the landing check", function()
	local ctx, ship, body = fallingDuel()

	for _ = 1, 600 do
		if Lander.isGrounded(ship) or ship.dead then
			break
		end
		step(ctx, { [2] = landIntent(ctx, ship, body) })
	end

	assertFalse(ship.dead)
	assertTrue(Lander.isGrounded(ship))
end)

test("Flight.land thrusts down toward a world it cannot see yet", function()
	local ctx, ship, body = fallingDuel()
	body.y, body.vy, body.angle = -900, 0, math.pi -- high above, nose down
	local threats = Danger.scan(ctx.sim, ctx.level.worlds, body, Config, { dt = DT, horizon = 0.5 })
	assertEqual(0, #threats, "fixture: no world within the horizon")

	local intent = Flight.land(ctx.sim, body, threats, Config, { fuel = ship.fuel, hold = DT })

	assertTrue(intent.thrust)
	assertEqual(0, intent.rotate)
end)

test("Flight.land plans no thrust on an empty tank", function()
	local ctx, ship, body = fallingDuel()
	ship.fuel.amount = 0

	assertFalse(landIntent(ctx, ship, body).thrust)
end)

test("fixture: the enemy's shot kills a tank that sits still", function()
	local ctx = newDuel(nil)
	fireAtSecond(ctx)

	local second = runOutShell(ctx)

	assertTrue(second.dead)
end)

test("a landed hopper aims its turret and fires at an enemy in reach", function()
	local ctx = newDuel("hard")
	local fired = false

	for _ = 1, 120 do
		step(ctx)
		assertFalse(ctx.intents[2].thrust, "stays landed")
		fired = fired or ctx.intents[2].fire
	end

	assertTrue(fired)
	assertTrue(Lander.isGrounded(shipOf(ctx, 2)))
end)

-- Runs a dodge: fires at the hopper, then steps (bounded) until it is back
-- in tank mode after leaving it. Returns the hopper's record, the modes it
-- passed through in order, the step it lifted off on, and the closest the
-- shell came.
local function dodge(level)
	local ctx = newDuel(level)
	local hopper = shipOf(ctx, 2)
	step(ctx) -- first think: settles into tank mode
	fireAtSecond(ctx)
	local enemy = shipOf(ctx, 1)
	local modes, liftOff, closest = {}, nil, math.huge
	for i = 1, 900 do
		step(ctx)
		local mode = ctx.ai[2] and ctx.ai[2].mode
		if mode and modes[#modes] ~= mode then
			modes[#modes + 1] = mode
		end
		if not liftOff and not Lander.isGrounded(hopper) then
			liftOff = i
		end
		local shell = enemy.weapon.shell and Bodies.get(ctx.sim.bodies, enemy.weapon.shell)
		local body = bodyOf(ctx, hopper)
		if shell and body then
			closest = math.min(closest, math.sqrt((shell.x - body.x) ^ 2 + (shell.y - body.y) ^ 2))
		end
		if hopper.dead or (liftOff and Lander.isGrounded(hopper) and not enemy.weapon.shell) then
			break
		end
	end
	return hopper, modes, liftOff or math.huge, closest
end

test("a hopper dodges a shell fired straight at it", function()
	local hopper = dodge("hard")

	assertFalse(hopper.dead)
end)

test("a hopper hops, lands, and is back in tank mode after a dodge", function()
	local hopper, modes = dodge("hard")

	assertFalse(hopper.dead)
	assertTrue(Lander.isGrounded(hopper))
	assertEqual("landed hop land landed", table.concat(modes, " "))
end)

test("a hopper with too little fuel to hop stays landed", function()
	local ctx = newDuel("hard")
	local hopper = shipOf(ctx, 2)
	step(ctx)
	hopper.fuel.amount = Config.ai.hopFuel / 2
	fireAtSecond(ctx)

	for _ = 1, 30 do
		step(ctx)
		hopper.fuel.amount = math.min(hopper.fuel.amount, Config.ai.hopFuel / 2)
		assertFalse(ctx.intents[2].thrust)
	end
end)

test("an easy hopper reacts later and dodges worse than a hard one", function()
	local _, _, easyLift, easyClosest = dodge("easy")
	local _, _, hardLift, hardClosest = dodge("hard")

	assertTrue(hardLift < easyLift, "hard lifts off first")
	assertTrue(hardClosest > easyClosest, "hard keeps the shell further off")
end)

-- A duel where the enemy stands on the floor 300 px to the left, level with
-- the hopper: its aim is about 90 degrees off the surface normal, past the
-- turret's 80 degree limit. `fuel` is the hopper's tank; `stuckFor` seeds
-- how long ago it last fired (in stuckDelay periods).
local function unreachableDuel(fuel, stuckFor)
	local ctx = newDuel("hard")
	local enemy = bodyOf(ctx, shipOf(ctx, 1))
	enemy.x, enemy.y, enemy.vx, enemy.vy = -300, 100 - enemy.radius, 0, 0
	local hopper = shipOf(ctx, 2)
	hopper.fuel.amount = fuel
	ctx.time = Config.ai.stuckDelay * 4
	ctx.ai = { [2] = { ship = hopper, nextThink = 0, firedAt = ctx.time - Config.ai.stuckDelay * stuckFor } }
	return ctx, hopper
end

-- Steps until slot 2 fires or thrusts (bounded); returns "fire", "thrust" or nil.
local function firstAction(ctx, maxSteps)
	for _ = 1, maxSteps do
		step(ctx)
		if ctx.intents[2].fire then
			return "fire"
		elseif ctx.intents[2].thrust then
			return "thrust"
		end
	end
	return nil
end

test("a hopper that cannot reach its target and has no fuel to hop waits until stuck", function()
	local ctx = unreachableDuel(0, 0.5)

	for _ = 1, 60 do
		step(ctx)
		assertFalse(ctx.intents[2].fire)
		assertFalse(ctx.intents[2].thrust)
	end
end)

test("a stuck hopper with no fuel to hop fires an unsolved shot at its turret's limit", function()
	local ctx, hopper = unreachableDuel(0, 1)

	assertEqual("fire", firstAction(ctx, 600))
	assertFalse(ctx.ai[2].aim.solved, "unsolved")
	assertTrue(Lander.isGrounded(hopper))
end)

test("a hopper stuck one delay fires at the limit instead of hopping", function()
	local ctx = unreachableDuel(Config.ai.hopFuel * 2, 1)

	assertEqual("fire", firstAction(ctx, 600))
end)

test("a hopper stuck two delays with fuel hops toward the target", function()
	local ctx = unreachableDuel(Config.ai.hopFuel * 2, 2)

	assertEqual("thrust", firstAction(ctx, 600))
end)

test("a firing hopper's stuck clock restarts", function()
	local ctx = unreachableDuel(0, 1)

	firstAction(ctx, 600)

	assertEqual(0, require("src.game.ai.skills.stuck").cycles(ctx, ctx.ai[2]))
end)
