local Match = require("src.game.match")
local Config = require("src.game.config")
local Bodies = require("src.sim.bodies")
local Lander = require("src.game.components.lander")
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

-- Three generated-size worlds in a row; the enemy sits on top of the right
-- one. Round the left one, 22.5 deg from the top has a direct line to the
-- enemy; at 67.5 deg the middle world blocks it but a lob curves round
-- (tests/unit/ai_vantage_test.lua's hill level). Spawn point 1 is the
-- enemy's, spawn point 2 the artillery's: `from` "hidden" or "exposed".
local function hillLevel(from)
	local left, middle, right = blob(-400, 25000), blob(0, 25000), blob(400, 25000)
	local start = from == "exposed" and onBlob(-400, 22.5, left) or onBlob(-400, 67.5, left)
	return { worlds = { left, middle, right }, spawnPoints = { onBlob(400, 0, right), start } }
end

-- Config with the hard level's numbers overridden by `fields`.
local function hardWith(fields)
	return setmetatable({
		ai = setmetatable({
			levels = setmetatable({ hard = setmetatable(fields, { __index = Config.ai.levels.hard }) }, { __index = Config.ai.levels }),
		}, { __index = Config.ai }),
	}, { __index = Config })
end

-- Slot 1 is a keyboard enemy that never moves, slot 2 a hard AI flying
-- `behavior` (default artillery). Slot i starts on spawn point i. Rounds
-- never end.
local function newBattery(levelData, behavior, config)
	config = setmetatable({ round = setmetatable({ endDelay = math.huge }, { __index = Config.round }) }, { __index = config or Config })
	local roster = {
		{ color = 1, binding = { kind = "keyboard", layout = "wasd" } },
		{ color = 2, binding = { kind = "ai", level = "hard", behavior = behavior or "artillery" } },
	}
	local ctx = Match.new(levelData, config, 1, { roster = roster })
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

local NEUTRAL = { rotate = 0, thrust = false, fire = false }

-- Steps up to `steps` times, stopping early once either ship is dead or
-- `stop(ctx)` returns true; calls `each(ctx)` after every step.
local function run(ctx, steps, each, stop)
	local enemy, own = ctx.pools.ships[1], ctx.pools.ships[2]
	for _ = 1, steps do
		ctx.intents[1] = NEUTRAL
		Match.step(ctx)
		ctx.time = ctx.time + ctx.dt
		if each then
			each(ctx)
		end
		if enemy.dead or own.dead or (stop and stop(ctx)) then
			return
		end
	end
end

-- Whether the AI (slot 2) has a direct line to the enemy (slot 1). Takes
-- the ships at the start: a dead ship leaves ctx.pools.ships.
local function sight(ctx)
	local enemy, own = ctx.pools.ships[1], ctx.pools.ships[2]
	return function()
		return Vantage.inSight(ctx.level.worlds, bodyOf(ctx, own), bodyOf(ctx, enemy))
	end
end

test("fixture: the hill level's hidden start has no direct line to the enemy, the exposed one has", function()
	assertFalse(sight(newBattery(hillLevel("hidden")))())
	assertTrue(sight(newBattery(hillLevel("exposed")))())
end)

test("an artillery on a concealed position lobs a shell round the world that kills the enemy", function()
	local ctx = newBattery(hillLevel("hidden"))
	local enemy, own = ctx.pools.ships[1], ctx.pools.ships[2]
	local inSight = sight(ctx)
	local fired = false

	run(ctx, 20 * 60, function()
		if ctx.intents[2].fire and not enemy.dead then
			fired = true
			assertFalse(inSight(), "fired with a direct line")
		end
	end)

	assertTrue(fired, "fired")
	assertTrue(enemy.dead, "killed the enemy")
	assertFalse(own.dead)
end)

test("an artillery with a direct line holds fire and relocates to a concealed position", function()
	local ctx = newBattery(hillLevel("exposed"))
	local own = ctx.pools.ships[2]
	local inSight = sight(ctx)
	local lifted = false

	run(ctx, 20 * 60, function()
		lifted = lifted or not Lander.isGrounded(own)
		if ctx.intents[2].fire then
			assertFalse(inSight(), "fired with a direct line")
		end
	end, function()
		return lifted and Lander.isGrounded(own)
	end)

	assertTrue(lifted, "lifted off")
	assertTrue(Lander.isGrounded(own), "landed again")
	assertFalse(inSight(), "landed with no direct line")
end)

test("an artillery with no lob anywhere takes the stuck shot after stuckDelay", function()
	local ctx = newBattery(hillLevel("hidden"), "artillery", hardWith({ predictionHorizon = 0.05 }))
	local firstFire

	run(ctx, 10 * 60, function()
		if ctx.intents[2].fire and not firstFire then
			firstFire = ctx.time
		end
	end, function()
		return firstFire ~= nil
	end)

	assertTrue(firstFire ~= nil, "never fired")
	assertTrue(firstFire >= Config.ai.stuckDelay, "fired early: " .. tostring(firstFire))
	assertTrue(Lander.isGrounded(ctx.pools.ships[2]), "stayed put")
end)

test("artillery is in the personality pool", function()
	local fresh = loadfile("src/game/ai/init.lua")()

	assertEqual("ambusher artillery chaos hopper hunter kamikaze schizo skirmisher sniper", table.concat(fresh.pool(), " "))
end)
