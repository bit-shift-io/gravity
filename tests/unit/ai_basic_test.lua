local AI = require("src.game.ai.init")
local Match = require("src.game.match")
local Config = require("src.game.config")
local Bodies = require("src.sim.bodies")

-- Two tank ships on a flat floor, 600 px apart: slot 1 at x=-300, slot 2 at
-- x=300. Both normals point straight up.
local function floorLevel()
	local world = {
		vertices = { { x = -400, y = 100 }, { x = 400, y = 100 }, { x = 400, y = 200 }, { x = -400, y = 200 } },
		mass = 1000,
	}
	local function point(x)
		return { x = x, y = 100, normal = { x = 0, y = -1 }, world = world }
	end
	return { worlds = { world }, spawnPoints = { point(-300), point(300) } }
end

-- Both slots run the basic behaviour by name: it is not in the drawn pool.
local function aiRoster(level1, level2)
	return {
		{ color = 1, binding = { kind = "ai", level = level1, behavior = "basic" } },
		{ color = 2, binding = { kind = "ai", level = level2 or level1, behavior = "basic" } },
	}
end

-- A config whose "slow" level thinks once a second, with a perfect aim.
local function slowConfig()
	return setmetatable({
		ai = setmetatable({
			levels = { slow = { aimError = 0, reactionDelay = 1, predictionHorizon = 0 } },
		}, { __index = Config.ai }),
	}, { __index = Config })
end

local function newCtx(level, config, roster, seed)
	local ctx = Match.new(level, config or Config, seed or 1, { roster = roster })
	ctx.dt = 1 / 60
	return ctx
end

local function moveEnemy(ctx, x, y)
	local body = Bodies.get(ctx.sim.bodies, ctx.pools.ships[2].body)
	body.x, body.y = x, y
end

test("a tank AI lifts off when the enemy is outside turret range", function()
	local ctx = newCtx(floorLevel(), Config, aiRoster("hard"))

	AI.fill(ctx)

	assertTrue(ctx.intents[1].thrust, "enemy level with the floor is beyond the turret limit")
end)

test("a tank AI aims its turret toward an enemy inside turret range", function()
	local ctx = newCtx(floorLevel(), Config, aiRoster("hard"))
	moveEnemy(ctx, -200, 0) -- up and to the right of slot 1

	AI.fill(ctx)

	assertFalse(ctx.intents[1].thrust)
	assertEqual(1, ctx.intents[1].rotate)

	moveEnemy(ctx, -400, 0) -- up and to the left
	ctx.time = 10
	AI.fill(ctx)
	assertEqual(-1, ctx.intents[1].rotate)
end)

test("a tank AI holds fire to charge once aimed, then releases", function()
	local ctx = newCtx(floorLevel(), Config, aiRoster("hard"))
	moveEnemy(ctx, -300, 0) -- straight above slot 1

	AI.fill(ctx)
	assertTrue(ctx.intents[1].fire, "aimed: starts charging")

	ctx.time = Config.weapon.chargeTime + 1
	AI.fill(ctx)
	assertFalse(ctx.intents[1].fire, "charge done: releases")
end)

test("a flying AI rotates toward the enemy and does not thrust", function()
	local ctx = newCtx(floorLevel(), Config, aiRoster("hard"))
	local ship = ctx.pools.ships[1]
	ship.lander.state = "flying"
	local body = Bodies.get(ctx.sim.bodies, ship.body)
	body.pinned = false
	moveEnemy(ctx, -100, 100) -- below-right of slot 1, nose points up

	AI.fill(ctx)

	assertEqual(1, ctx.intents[1].rotate)
	assertFalse(ctx.intents[1].thrust)
end)

test("a flying AI fires once its nose points at the enemy", function()
	local ctx = newCtx(floorLevel(), Config, aiRoster("hard"))
	local ship = ctx.pools.ships[1]
	ship.lander.state = "flying"
	Bodies.get(ctx.sim.bodies, ship.body).pinned = false
	moveEnemy(ctx, -300, -200) -- straight ahead

	AI.fill(ctx)

	assertTrue(ctx.intents[1].fire)
end)

test("an AI does not start a charge while its own projectile is alive", function()
	local ctx = newCtx(floorLevel(), Config, aiRoster("hard"))
	moveEnemy(ctx, -300, 0)
	local ship = ctx.pools.ships[1]
	ship.weapon.shell = Bodies.add(ctx.sim.bodies, { x = 0, y = 0, vx = 0, vy = 0, angle = 0, angularVelocity = 0, mass = 1 })

	AI.fill(ctx)

	assertFalse(ctx.intents[1].fire)
end)

local function maxAimOffset(levelName)
	local ctx = newCtx(floorLevel(), Config, aiRoster(levelName), 7)
	moveEnemy(ctx, -200, 0)
	local worst = 0
	for i = 1, 300 do
		ctx.time = i * 10 -- past any reaction delay: a fresh think each call
		AI.fill(ctx)
		worst = math.max(worst, math.abs(ctx.ai[1].aimOffset))
	end
	return worst
end

test("aim error scales with the level's config number", function()
	local easy, hard = maxAimOffset("easy"), maxAimOffset("hard")

	assertTrue(easy > hard, "easy sloppier than hard")
	assertTrue(easy <= Config.ai.levels.easy.aimError)
	assertTrue(hard <= Config.ai.levels.hard.aimError)
end)

test("the reaction delay holds the intent steady between thinks", function()
	local ctx = newCtx(floorLevel(), slowConfig(), aiRoster("slow"))
	moveEnemy(ctx, -200, 0)
	AI.fill(ctx)
	assertEqual(1, ctx.intents[1].rotate)

	moveEnemy(ctx, -400, 0)
	ctx.time = 0.5
	AI.fill(ctx)
	assertEqual(1, ctx.intents[1].rotate, "still the old decision before the delay passes")

	ctx.time = 1.0
	AI.fill(ctx)
	assertEqual(-1, ctx.intents[1].rotate, "thinks again once the delay passes")
end)

test("an AI writes a neutral intent when no enemy is alive", function()
	local ctx = newCtx(floorLevel(), Config, aiRoster("hard"))
	ctx.pools.ships[2].dead = true

	AI.fill(ctx)

	assertEqual(0, ctx.intents[1].rotate)
	assertFalse(ctx.intents[1].thrust)
	assertFalse(ctx.intents[1].fire)
end)

test("a dead AI ship has its intent cleared", function()
	local ctx = newCtx(floorLevel(), Config, aiRoster("hard"))
	ctx.intents[1] = { rotate = 1, thrust = true, fire = true }
	ctx.pools.ships[1].dead = true

	AI.fill(ctx)

	assertEqual(0, ctx.intents[1].rotate)
	assertFalse(ctx.intents[1].thrust)
	assertFalse(ctx.intents[1].fire)
end)

test("AI.fill leaves human slots' intents alone", function()
	local roster = {
		{ color = 1, binding = { kind = "keyboard", layout = "wasd" } },
		{ color = 2, binding = { kind = "ai", level = "hard" } },
	}
	local ctx = newCtx(floorLevel(), Config, roster)
	local human = { rotate = 1, thrust = true, fire = false }
	ctx.intents[1] = human

	AI.fill(ctx)

	assertEqual(human, ctx.intents[1])
	assertTrue(ctx.intents[2] ~= nil)
	assertTrue(ctx.ai[1] == nil, "no AI state for a human slot")
end)

test("a new behaviour kind registers without touching Match.step", function()
	AI.register("always-fire", {
		update = function(ctx, slot)
			ctx.intents[slot] = { rotate = 0, thrust = false, fire = true }
		end,
	}, { pool = false }) -- unpooled: the registry is shared by later test files
	local roster = {
		{ color = 1, binding = { kind = "ai", level = "hard", behavior = "always-fire" } },
		{ color = 2, binding = { kind = "ai", level = "hard" } },
	}
	local ctx = newCtx(floorLevel(), Config, roster)

	Match.step(ctx)

	assertTrue(ctx.intents[1].fire)
end)
