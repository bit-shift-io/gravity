local Match = require("src.game.match")
local Config = require("src.game.config")
local Bodies = require("src.sim.bodies")
local Lander = require("src.game.components.lander")
local AI = require("src.game.ai.init")

local DT = 1 / 60

-- Same floor and ledge as tests/unit/ai_hunter_test.lua.
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

-- Slot 1 is a keyboard target on the ledge, slot 2 a hard chaos AI on the
-- floor. Rounds never end. `ai` overrides config.ai fields.
local function newChaos(seed, ai)
	local config = setmetatable({
		round = setmetatable({ endDelay = math.huge }, { __index = Config.round }),
		ai = setmetatable(ai or {}, { __index = Config.ai }),
	}, { __index = Config })
	local roster = {
		{ color = 1, binding = { kind = "keyboard", layout = "wasd" } },
		{ color = 2, binding = { kind = "ai", level = "hard", behavior = "chaos" } },
	}
	local ctx = Match.new(huntLevel(), config, seed, { roster = roster })
	ctx.dt = DT
	local a = Bodies.get(ctx.sim.bodies, ctx.pools.ships[1].body)
	local b = Bodies.get(ctx.sim.bodies, ctx.pools.ships[2].body)
	if a.x > b.x then
		a.x, a.y, b.x, b.y = b.x, b.y, a.x, a.y
	end
	return ctx
end

local NEUTRAL = { rotate = 0, thrust = false, fire = false }

-- Steps `steps` times; returns the chaos AI's intents as strings.
local function trace(ctx, steps)
	local out = {}
	for i = 1, steps do
		ctx.intents[1] = NEUTRAL
		Match.step(ctx)
		ctx.time = ctx.time + ctx.dt
		local intent = ctx.intents[2]
		out[i] = string.format("%d%s%s", intent.rotate, intent.thrust and "T" or "-", intent.fire and "F" or "-")
	end
	return table.concat(out, ",")
end

test("chaos is a pooled meta kind", function()
	assertTrue(AI.kinds.chaos ~= nil)
	assertTrue(AI.meta.chaos)
	assertFalse(AI.unpooled.chaos)
	assertEqual(nil, AI.meta.hunter)
end)

test("chaos with the same seed injects the same action sequence", function()
	local a = trace(newChaos(7, { chaosRate = 0.8 }), 20 * 60)
	local b = trace(newChaos(7, { chaosRate = 0.8 }), 20 * 60)
	assertEqual(a, b)
end)

test("chaos with a different seed injects a different action sequence", function()
	local a = trace(newChaos(7, { chaosRate = 0.8 }), 20 * 60)
	local b = trace(newChaos(8, { chaosRate = 0.8 }), 20 * 60)
	assertTrue(a ~= b)
end)

test("chaos keeps its own seed-derived rng on ctx.ai[slot], apart from ctx.rng", function()
	local ctx = newChaos(7, { chaosRate = 0.8 })
	trace(ctx, 60)
	assertTrue(ctx.ai[2].chaos.rng ~= ctx.rng)
	assertEqual(ctx.seed, 7)
end)

test("chaos injects at the configured rate over many thinks", function()
	local ctx = newChaos(3, { chaosRate = 0.3, chaosInterval = 0.1 })
	trace(ctx, 1)
	local chaos = ctx.ai[2].chaos
	-- The state is dropped when the ship dies, so keep a reference.
	trace(ctx, 300 * 60)
	assertTrue(chaos.rolls > 200, "rolls " .. chaos.rolls)
	local share = chaos.injected / chaos.rolls
	assertTrue(share > 0.2 and share < 0.4, "share " .. share)
end)

test("chaos with rate 0 matches a hunter's intents", function()
	local chaos = newChaos(5, { chaosRate = 0 })
	local hunter = newChaos(5, { chaosRate = 0 })
	hunter.roster[2].binding.behavior = "hunter"
	assertEqual(trace(hunter, 10 * 60), trace(chaos, 10 * 60))
end)

test("chaos still lifts off and fires as a hunter does", function()
	local ctx = newChaos(5, { chaosRate = 0.3 })
	local own = ctx.pools.ships[2]
	local lifted, fired = false, false
	for _ = 1, 30 * 60 do
		ctx.intents[1] = NEUTRAL
		Match.step(ctx)
		ctx.time = ctx.time + ctx.dt
		lifted = lifted or not Lander.isGrounded(own)
		fired = fired or ctx.intents[2].fire
	end
	assertTrue(lifted, "lifted")
	assertTrue(fired, "fired")
end)
