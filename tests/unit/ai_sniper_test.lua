local Match = require("src.game.match")
local Config = require("src.game.config")
local Bodies = require("src.sim.bodies")
local Lander = require("src.game.components.lander")
local ProjectileSystem = require("src.game.systems.projectile_system")
local Aim = require("src.game.ai.skills.aim")
local Vantage = require("src.game.ai.skills.vantage")
local Artillery = require("src.game.ai.artillery")

local DT = 1 / 60

local function point(x, y, world)
	return { x = x, y = y, normal = { x = 0, y = -1 }, world = world }
end

local function floorWorld()
	return {
		vertices = { { x = -400, y = 100 }, { x = 400, y = 100 }, { x = 400, y = 200 }, { x = -400, y = 200 } },
		mass = 40000,
	}
end

-- A light 40 px block whose top centre is (x, y).
local function ledgeAt(x, y)
	return {
		vertices = { { x = x - 20, y = y }, { x = x + 20, y = y }, { x = x + 20, y = y + 40 }, { x = x - 20, y = y + 40 } },
		mass = 2000,
	}
end

-- A floor about as heavy as a generated world (top edge y = 100) and a
-- light ledge up and to the left. Spawn points: the target on the ledge at
-- (-300, 0), the sniper on the floor at (200, 100) -- about 510 px apart.
local function openLevel()
	local floor, ledge = floorWorld(), ledgeAt(-300, 0)
	return { worlds = { floor, ledge }, spawnPoints = { point(-300, 0, ledge), point(200, 100, floor) } }
end

-- openLevel with a second target on a high ledge at (-100, -300).
local function twoTargetLevel()
	local floor, low, high = floorWorld(), ledgeAt(-300, 0), ledgeAt(-100, -300)
	return {
		worlds = { floor, low, high },
		spawnPoints = { point(-300, 0, low), point(-100, -300, high), point(200, 100, floor) },
	}
end

-- The same floor split by a light wall standing on it, too tall to lob
-- over: the target at (300, 100) right of it, the sniper at (-200, 100)
-- left of it, with no shot until it moves.
local function walledLevel()
	local floor = floorWorld()
	local wall = {
		vertices = { { x = -20, y = -340 }, { x = 20, y = -340 }, { x = 20, y = 100 }, { x = -20, y = 100 } },
		mass = 2000,
	}
	return { worlds = { floor, wall }, spawnPoints = { point(300, 100, floor), point(-200, 100, floor) } }
end

-- Every slot but the last is a keyboard target that never moves; the last
-- is an AI sniper at `level`. Slot i starts on the level's spawn point i.
-- Rounds never end, so a kill doesn't respawn anyone mid-scenario. `config`
-- may override Config.
local function newSnipe(levelData, level, config)
	config = setmetatable({ round = setmetatable({ endDelay = math.huge }, { __index = Config.round }) }, { __index = config or Config })
	local roster = {}
	for i = 1, #levelData.spawnPoints - 1 do
		roster[i] = { color = i, binding = { kind = "keyboard", layout = i == 1 and "wasd" or "ijkl" } }
	end
	roster[#roster + 1] = { color = #roster + 1, binding = { kind = "ai", level = level, behavior = "sniper" } }
	local ctx = Match.new(levelData, config, 1, { roster = roster })
	ctx.dt = DT
	-- Spawn points are drawn at random: move each ship onto its slot's.
	local placed = {}
	for _, ship in ipairs(ctx.pools.ships) do
		local body = Bodies.get(ctx.sim.bodies, ship.body)
		placed[#placed + 1] = { x = body.x, y = body.y }
	end
	for _, ship in ipairs(ctx.pools.ships) do
		local want = levelData.spawnPoints[ship.player]
		for _, p in ipairs(placed) do
			if math.abs(p.x - want.x) < 1 then
				local body = Bodies.get(ctx.sim.bodies, ship.body)
				body.x, body.y = p.x, p.y
			end
		end
	end
	return ctx
end

-- Config with the hard level's numbers overridden by `fields`.
local function hardWith(fields)
	return setmetatable({
		ai = setmetatable({
			levels = setmetatable({ hard = setmetatable(fields, { __index = Config.ai.levels.hard }) }, { __index = Config.ai.levels }),
		}, { __index = Config.ai }),
	}, { __index = Config })
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
	for slot = 1, #ctx.roster - 1 do
		ctx.intents[slot] = NEUTRAL
	end
	Match.step(ctx)
	ctx.time = ctx.time + ctx.dt
end

-- Steps `steps` times (stopping early once the sniper or every target is
-- dead, or `stop(sniper, ctx)` returns true), calling `each(sniper, ctx)`
-- after every step. Returns the sniper's record and the modes it passed
-- through, in order.
local function run(ctx, steps, each, stop)
	local slot = #ctx.roster
	local sniper = shipOf(ctx, slot)
	local targets = {}
	for i = 1, slot - 1 do
		targets[i] = shipOf(ctx, i)
	end
	local modes = {}
	for _ = 1, steps do
		step(ctx)
		local mode = ctx.ai[slot] and ctx.ai[slot].mode
		if mode and modes[#modes] ~= mode then
			modes[#modes + 1] = mode
		end
		if each then
			each(sniper, ctx)
		end
		local alive = 0
		for _, target in ipairs(targets) do
			alive = alive + (target.dead and 0 or 1)
		end
		if sniper.dead or alive == 0 or (stop and stop(sniper, ctx)) then
			break
		end
	end
	return sniper, modes
end

local function seen(modes, mode)
	for _, m in ipairs(modes) do
		if m == mode then
			return true
		end
	end
	return false
end

test("the personality pool is ambusher, artillery, chaos, hopper, hunter, kamikaze, schizo, skirmisher and sniper", function()
	local fresh = loadfile("src/game/ai/init.lua")()

	assertEqual("ambusher artillery chaos hopper hunter kamikaze schizo skirmisher sniper", table.concat(fresh.pool(), " "))
end)

test("a sniper hits a stationary far target across the gravity well", function()
	local ctx = newSnipe(openLevel(), "hard")
	local target = shipOf(ctx, 1)

	local sniper = run(ctx, 20 * 60)

	assertTrue(target.dead)
	assertFalse(sniper.dead)
end)

test("a sniper keeps firing from the one spot while it has shots", function()
	local ctx = newSnipe(twoTargetLevel(), "hard")
	local low, high = shipOf(ctx, 1), shipOf(ctx, 2)
	local sniper = shipOf(ctx, 3)
	local body = bodyOf(ctx, sniper)
	local x0, y0 = body.x, body.y
	local shots, wasFiring = 0, false

	local _, modes = run(ctx, 30 * 60, function()
		local firing = ctx.intents[3].fire
		if wasFiring and not firing then
			shots = shots + 1
		end
		wasFiring = firing
		assertTrue(Lander.isGrounded(sniper), "stays landed")
		assertNear(x0, body.x, 1e-6)
		assertNear(y0, body.y, 1e-6)
	end)

	assertTrue(low.dead and high.dead, "shot both targets")
	assertTrue(shots >= 2, "released " .. shots .. " shots")
	assertEqual("shoot", table.concat(modes, " "))
end)

-- Steps until the sniper has lifted off and is back in tank mode (bounded).
-- Returns the sniper's record, the modes it passed through, and the time it
-- lifted off.
local function untilRelanded(ctx, maxSteps)
	local liftedAt
	local sniper, modes = run(ctx, maxSteps, function(s)
		if not liftedAt and not Lander.isGrounded(s) then
			liftedAt = ctx.time
		end
	end, function(s)
		return liftedAt and Lander.isGrounded(s)
	end)
	return sniper, modes, liftedAt
end

test("a sniper with no shot settles, then relocates after relocateDelay", function()
	local ctx = newSnipe(walledLevel(), "hard")

	local _, modes, liftedAt = untilRelanded(ctx, 10 * 60)

	assertEqual("settle", modes[1])
	assertEqual("relocate", modes[2])
	assertTrue(liftedAt ~= nil, "lifted off")
	assertTrue(liftedAt >= Config.ai.relocateDelay, "waited: " .. liftedAt)
	assertTrue(liftedAt < Config.ai.relocateDelay + 0.5, "then went: " .. liftedAt)
end)

test("a sniper picks a vantage once per relocation, not every think", function()
	local ctx = newSnipe(walledLevel(), "hard")
	local pick, calls = Vantage.pick, 0
	Vantage.pick = function(...)
		calls = calls + 1
		return pick(...)
	end

	local ok, err = pcall(untilRelanded, ctx, 20 * 60)
	Vantage.pick = pick

	assertTrue(ok, err)
	assertEqual(1, calls)
end)

test("a relocating sniper lands on its picked vantage, then shoots from it", function()
	local ctx = newSnipe(walledLevel(), "hard")
	local target = shipOf(ctx, 1)

	local sniper, modes = untilRelanded(ctx, 20 * 60)
	local vantage = ctx.ai[2].vantage
	local body = bodyOf(ctx, sniper)

	assertFalse(sniper.dead)
	assertTrue(Lander.isGrounded(sniper), "landed")
	assertTrue(vantage, "picked a vantage")
	local dx, dy = body.x - vantage.x, body.y - vantage.y
	assertTrue(dx * dx + dy * dy <= 20 * 20, string.format("landed %.0f px off the vantage", math.sqrt(dx * dx + dy * dy)))

	run(ctx, 20 * 60)

	assertTrue(target.dead, "shot the target from the vantage")
	assertTrue(seen(modes, "relocate"))
end)

-- Fires slot 1's gravity-aware shot at the sniper, as a full-skill player
-- would: solved with the aim skill, spawned at the solved speed.
local function fireAtSniper(ctx)
	local enemy = shipOf(ctx, 1)
	local from = bodyOf(ctx, enemy)
	local target = bodyOf(ctx, shipOf(ctx, #ctx.roster))
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

test("fixture: the enemy's shot kills a sniper that can't dodge", function()
	local ctx = newSnipe(openLevel(), "hard")
	local sniper = shipOf(ctx, 2)
	step(ctx)
	fireAtSniper(ctx)

	run(ctx, 300, function(s)
		s.fuel.amount = 0 -- no fuel to lift off with
	end)

	assertTrue(sniper.dead)
end)

test("a threatened sniper dodges, then relocates and lands again", function()
	local ctx = newSnipe(openLevel(), "hard")
	step(ctx)
	fireAtSniper(ctx)

	local sniper, modes = untilRelanded(ctx, 20 * 60)

	assertFalse(sniper.dead)
	assertTrue(Lander.isGrounded(sniper), "landed again")
	assertEqual("dodge", modes[2])
	assertEqual("relocate", modes[3])
end)

test("a sniper that can't foresee a hit fires nothing before the stuck delay", function()
	local ctx = newSnipe(twoTargetLevel(), "hard", hardWith({ predictionHorizon = 0.05 }))

	run(ctx, (Config.ai.stuckDelay - 0.5) * 60, function()
		assertFalse(ctx.intents[3].fire)
	end)
end)

test("a sniper whose vantage pick finds nothing hands over to artillery", function()
	local ctx = newSnipe(twoTargetLevel(), "hard", hardWith({ predictionHorizon = 0.05 }))
	local update, calls = Artillery.update, 0
	Artillery.update = function(...)
		calls = calls + 1
		return update(...)
	end

	local ok, err = pcall(run, ctx, (Config.ai.relocateDelay + 1) * 60)
	Artillery.update = update

	assertTrue(ok, err)
	assertTrue(ctx.ai[3].handover, "handed over")
	assertTrue(calls > 0, "artillery thinks for it")
end)

test("a sniper with no vantage no longer stalls: it fires once stuck", function()
	local ctx = newSnipe(twoTargetLevel(), "hard", hardWith({ predictionHorizon = 0.05 }))
	local firstFire

	run(ctx, 10 * 60, function()
		firstFire = firstFire or (ctx.intents[3].fire and ctx.time) or nil
	end, function()
		return firstFire ~= nil
	end)

	assertTrue(firstFire ~= nil, "never fired")
	assertTrue(firstFire >= Config.ai.stuckDelay, "fired early: " .. tostring(firstFire))
end)
