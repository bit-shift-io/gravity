require("src.game.ai.init")
local Match = require("src.game.match")
local Config = require("src.game.config")
local Bodies = require("src.sim.bodies")
local Lander = require("src.game.components.lander")
local LevelGen = require("src.game.level_gen")
local Vantage = require("src.game.ai.skills.vantage")

local DT = 1 / 60

-- A 16-sided round world of radius 100 centred on (cx, 0).
local function blob(cx, mass)
	local vertices = {}
	for i = 0, 15 do
		local a = i / 16 * 2 * math.pi
		vertices[#vertices + 1] = { x = cx + 100 * math.sin(a), y = -100 * math.cos(a) }
	end
	return { vertices = vertices, mass = mass }
end

-- The surface vertex `deg` degrees clockwise from the top of the blob
-- centred on (cx, 0), with its outward normal.
local function onBlob(cx, deg, world)
	local a = math.rad(deg)
	local nx, ny = math.sin(a), -math.cos(a)
	return { x = cx + 100 * nx, y = 100 * ny, normal = { x = nx, y = ny }, world = world }
end

-- Three generated-size worlds in a row (tests/unit/ai_artillery_test.lua's
-- hill level). Spawn point 1, the enemy's, sits on top of the right one,
-- about 710 px from spawn point 2, the ambusher's, hidden behind the middle
-- world 67.5 deg round the left one -- or, `exposed`, 22.5 deg round it,
-- with a direct line to the enemy.
local function hillLevel(exposed)
	local left, middle, right = blob(-400, 25000), blob(0, 25000), blob(400, 25000)
	local start = exposed and onBlob(-400, 22.5, left) or onBlob(-400, 67.5, left)
	return { worlds = { left, middle, right }, spawnPoints = { onBlob(400, 0, right), start } }
end

-- Where an approaching enemy stops: on the middle world's left flank,
-- about 215 px from the ambusher's spawn, with a direct line to it.
local NEAR = onBlob(0, -67.5)

-- Rounds never end, so a kill doesn't respawn anyone mid-scenario.
local function endless(config)
	return setmetatable({ round = setmetatable({ endDelay = math.huge }, { __index = Config.round }) }, { __index = config })
end

-- Slot 1 is a keyboard enemy that never moves, slot 2 a hard ambusher.
-- Slot i starts on spawn point i.
local function newAmbush(exposed)
	local levelData = hillLevel(exposed)
	local roster = {
		{ color = 1, binding = { kind = "keyboard", layout = "wasd" } },
		{ color = 2, binding = { kind = "ai", level = "hard", behavior = "ambusher" } },
	}
	local ctx = Match.new(levelData, endless(Config), 1, { roster = roster })
	ctx.dt = DT
	-- Spawn points are drawn at random: swap the ships' bodies if slot 1
	-- didn't get spawn point 1.
	local a, b = ctx.pools.ships[1], ctx.pools.ships[2]
	if a.lander.host ~= levelData.spawnPoints[a.player].world then
		a.body, b.body = b.body, a.body
		a.id, b.id = b.id, a.id
		a.lander.host, b.lander.host = b.lander.host, a.lander.host
	end
	return ctx
end

local function bodyOf(ctx, ship)
	return Bodies.get(ctx.sim.bodies, ship.body)
end

-- Moves the landed enemy (slot 1) to `point`: it arrived there.
local function moveEnemy(ctx, point)
	local body = bodyOf(ctx, ctx.pools.ships[1])
	body.x, body.y, body.vx, body.vy = point.x, point.y, 0, 0
end

local NEUTRAL = { rotate = 0, thrust = false, fire = false }

-- Steps up to `steps` times, stopping early once the ambusher is dead or
-- `stop(ctx)` returns true; calls `each(ctx)` after every step.
local function run(ctx, steps, each, stop)
	local own = ctx.pools.ships[2]
	for _ = 1, steps do
		ctx.intents[1] = NEUTRAL
		Match.step(ctx)
		ctx.time = ctx.time + ctx.dt
		if each then
			each(ctx)
		end
		if own.dead or (stop and stop(ctx)) then
			return
		end
	end
end

test("fixture: the ambusher starts hidden from the enemy and out of ambush range", function()
	local ctx = newAmbush()
	local enemy, own = bodyOf(ctx, ctx.pools.ships[1]), bodyOf(ctx, ctx.pools.ships[2])
	local dx, dy = enemy.x - own.x, enemy.y - own.y

	assertFalse(Vantage.inSight(ctx.level.worlds, own, enemy))
	assertTrue(math.sqrt(dx * dx + dy * dy) > Config.ai.ambushRange)
end)

test("an ambusher with no enemy in range holds its position and fire", function()
	local ctx = newAmbush()
	local own = ctx.pools.ships[2]
	local start = { x = bodyOf(ctx, own).x, y = bodyOf(ctx, own).y }
	local fired = false

	run(ctx, math.floor((Config.ai.stuckDelay - 1) / DT), function()
		fired = fired or ctx.intents[2].fire
		assertTrue(Lander.isGrounded(own), "stayed landed")
	end)

	assertFalse(fired)
	assertEqual(start.x, bodyOf(ctx, own).x)
	assertEqual(start.y, bodyOf(ctx, own).y)
end)

test("an ambusher lifts off and fires when an enemy comes within range", function()
	local ctx = newAmbush()
	local own = ctx.pools.ships[2]
	run(ctx, 60)
	moveEnemy(ctx, NEAR)
	local lifted, firedAt = false, nil

	run(ctx, 4 * 60, function()
		lifted = lifted or not Lander.isGrounded(own)
		if ctx.intents[2].fire and not firedAt then
			firedAt = ctx.time
		end
	end, function()
		return firedAt ~= nil
	end)

	assertTrue(lifted, "lifted off")
	assertTrue(firedAt ~= nil, "fired")
	assertTrue(firedAt < 1 + Config.ai.stuckDelay, "struck before it was stuck")
	assertFalse(own.dead)
end)

test("an ambusher whose enemy leaves range lands hidden from it again", function()
	local ctx = newAmbush()
	local enemy, own = ctx.pools.ships[1], ctx.pools.ships[2]
	local home = { x = bodyOf(ctx, enemy).x, y = bodyOf(ctx, enemy).y }
	moveEnemy(ctx, NEAR)
	local fired = false
	run(ctx, 4 * 60, function()
		fired = fired or ctx.intents[2].fire
	end, function()
		return fired
	end)
	assertTrue(fired, "struck")
	moveEnemy(ctx, home)
	local lifted = false

	run(ctx, 20 * 60, function()
		lifted = lifted or not Lander.isGrounded(own)
	end, function()
		return lifted and Lander.isGrounded(own) and not ctx.intents[2].thrust
	end)

	assertFalse(own.dead)
	assertTrue(Lander.isGrounded(own), "landed again")
	assertFalse(Vantage.inSight(ctx.level.worlds, bodyOf(ctx, own), bodyOf(ctx, enemy)), "landed hidden")
end)

test("an ambusher landed in sight of an enemy out of range moves to a hidden spot", function()
	local ctx = newAmbush(true)
	local enemy, own = ctx.pools.ships[1], ctx.pools.ships[2]
	assertTrue(Vantage.inSight(ctx.level.worlds, bodyOf(ctx, own), bodyOf(ctx, enemy)), "fixture: starts in sight")
	local lifted, fired = false, false

	run(ctx, 15 * 60, function()
		lifted = lifted or not Lander.isGrounded(own)
		fired = fired or ctx.intents[2].fire
	end, function()
		return lifted and Lander.isGrounded(own) and not ctx.intents[2].thrust
	end)

	assertFalse(own.dead)
	assertFalse(fired, "fired")
	assertTrue(Lander.isGrounded(own), "landed again")
	assertFalse(Vantage.inSight(ctx.level.worlds, bodyOf(ctx, own), bodyOf(ctx, enemy)), "landed hidden")
end)

test("an ambusher with no enemy ever in range fires once it is stuck", function()
	local ctx = newAmbush()
	local firedAt

	run(ctx, 15 * 60, function()
		if ctx.intents[2].fire and not firedAt then
			firedAt = ctx.time
		end
	end, function()
		return firedAt ~= nil
	end)

	assertTrue(firedAt ~= nil, "never fired")
	assertTrue(firedAt >= Config.ai.stuckDelay, "fired early: " .. tostring(firedAt))
end)

-- Generated levels with asteroids switched off; three idle enemies.
for _, level in ipairs({ "easy", "hard" }) do
	test("a seeded " .. level .. " ambusher fires in every match", function()
		for _, seed in ipairs({ 2, 5, 6 }) do
			local levelData = LevelGen.generate(seed, Config)
			levelData.asteroids.maxAlive = 0
			local roster = {}
			for slot = 1, 3 do
				roster[slot] = { color = slot, binding = { kind = "keyboard", layout = "wasd" } }
			end
			roster[4] = { color = 4, binding = { kind = "ai", level = level, behavior = "ambusher" } }
			local ctx = Match.new(levelData, endless(Config), seed, { roster = roster })
			ctx.dt = DT
			local own = ctx.pools.ships[4]
			local shots, lastShell = 0, nil

			for _ = 1, 20 * 60 do
				for slot = 1, 3 do
					ctx.intents[slot] = NEUTRAL
				end
				Match.step(ctx)
				ctx.time = ctx.time + ctx.dt
				local shell = own.weapon.shell
				if shell and shell ~= lastShell then
					shots = shots + 1
				end
				lastShell = shell
				if own.dead then
					break
				end
			end

			assertTrue(shots >= 1, "seed " .. seed .. ": never fired")
		end
	end)
end

test("ambusher is in the personality pool", function()
	local fresh = loadfile("src/game/ai/init.lua")()

	assertEqual("ambusher artillery chaos hopper hunter kamikaze schizo skirmisher sniper", table.concat(fresh.pool(), " "))
end)
