local Match = require("src.game.match")
local Config = require("src.game.config")
local Bodies = require("src.sim.bodies")
local Flight = require("src.game.ai.skills.flight")
local Lander = require("src.game.components.lander")

local DT = 1 / 60

-- A floor about as heavy as a generated world (top edge y = 100) with a
-- pillar standing on it at x = -40..40 up to y = -200. Spawn points on the
-- floor at either end; both ships are keyboard slots, so the test's own
-- intents fly slot 1.
local function pillarLevel()
	local floor = {
		vertices = { { x = -400, y = 100 }, { x = 400, y = 100 }, { x = 400, y = 200 }, { x = -400, y = 200 } },
		mass = 40000,
	}
	local pillar = {
		vertices = { { x = -40, y = -200 }, { x = 40, y = -200 }, { x = 40, y = 100 }, { x = -40, y = 100 } },
		mass = 4000,
	}
	local function point(x)
		return { x = x, y = 100, normal = { x = 0, y = -1 }, world = floor }
	end
	return { worlds = { floor, pillar }, spawnPoints = { point(-380), point(380) } }
end

-- Slot 1 flying at rest, nose up, at (x, y); slot 2 left parked on the
-- floor. Rounds never end, so a crash leaves the record dead in place.
local function flyingAt(x, y)
	local config = setmetatable({ round = setmetatable({ endDelay = math.huge }, { __index = Config.round }) }, { __index = Config })
	local ctx = Match.new(pillarLevel(), config, 1, {})
	ctx.dt = DT
	local ship
	for _, s in ipairs(ctx.pools.ships) do
		if s.player == 1 then
			ship = s
		end
	end
	local body = Bodies.get(ctx.sim.bodies, ship.body)
	ship.lander.state = "flying"
	body.pinned = false
	body.x, body.y, body.vx, body.vy, body.angle = x, y, 0, 0, 0
	return ctx, ship, body
end

local function flyTo(ctx, ship, body, target, hold)
	return Flight.flyTo(ctx.sim, ctx.level.worlds, body, target, Config, {
		fuel = ship.fuel,
		hold = hold or DT,
		dt = DT,
		horizon = 1.5,
	})
end

local function step(ctx, intent)
	ctx.intents[1] = intent
	ctx.intents[2] = { rotate = 0, thrust = false, fire = false }
	Match.step(ctx)
	ctx.time = ctx.time + ctx.dt
end

-- Flies slot 1 with flyTo, re-planning every `hold` seconds, until it is
-- within `reach` px of `target` (bounded). Returns whether it got there.
local function flyUntilThere(ctx, ship, body, target, hold, reach)
	hold = hold or DT
	local intent, nextThink = nil, 0
	for _ = 1, 900 do
		if ship.dead then
			return false
		end
		local dx, dy = body.x - target.x, body.y - target.y
		if dx * dx + dy * dy <= reach * reach then
			return true
		end
		if ctx.time >= nextThink then
			intent = flyTo(ctx, ship, body, target, hold)
			nextThink = ctx.time + hold
		end
		step(ctx, intent)
	end
	return false
end

test("fixture: coasting from the start point comes down on a world", function()
	local ctx, ship = flyingAt(-150, -50)

	for _ = 1, 600 do
		step(ctx, { rotate = 0, thrust = false, fire = false })
		if ship.dead or Lander.isGrounded(ship) then
			break
		end
	end

	assertTrue(ship.dead or Lander.isGrounded(ship))
end)

test("Flight.flyTo heads straight for a target with nothing in the way", function()
	local ctx, ship, body = flyingAt(-150, -300)
	local target = { x = 150, y = -300 }

	local _, plan = flyTo(ctx, ship, body, target)

	assertTrue(plan.clear)
	assertNear(Flight.angleOf(target.x - body.x, target.y - body.y), plan.angle, 1e-6)
end)

test("Flight.flyTo plans around a world in the straight path", function()
	local ctx, ship, body = flyingAt(-150, -50)
	local target = { x = 150, y = -50 }
	local direct = Flight.angleOf(target.x - body.x, target.y - body.y)

	local _, plan = flyTo(ctx, ship, body, target)

	assertTrue(plan.clear)
	assertTrue(math.abs(plan.angle - direct) >= Config.ai.detourStep - 1e-6, "turned off the direct line")
end)

test("Flight.flyTo reaches a point past a world without crashing", function()
	local ctx, ship, body = flyingAt(-150, -50)

	local reached = flyUntilThere(ctx, ship, body, { x = 150, y = -50 }, DT, 40)

	assertFalse(ship.dead)
	assertTrue(reached)
end)

test("Flight.flyTo still gets there re-planning only every hard think", function()
	local ctx, ship, body = flyingAt(-150, -50)

	local reached = flyUntilThere(ctx, ship, body, { x = 150, y = -50 }, Config.ai.levels.hard.reactionDelay, 40)

	assertFalse(ship.dead)
	assertTrue(reached)
end)

test("Flight.flyTo plans no thrust on an empty tank", function()
	local ctx, ship, body = flyingAt(-150, -300)
	ship.fuel.amount = 0

	local intent = flyTo(ctx, ship, body, { x = 150, y = -300 })

	assertFalse(intent.thrust)
end)

-- Slot 1 near the hard boundary's left edge, racing outward at 318 px/s,
-- with a goal further round the boundary: flying straight at the goal
-- swings it into the boundary before it can turn.
local function racingOut()
	local ctx, ship, body = flyingAt(-1028, 186)
	body.vx, body.vy = -318, 28
	return ctx, ship, body, { x = -843, y = 652 }
end

-- Flies slot 1 at `goal` with flyTo under `config` for 5 s (bounded).
local function flyFor(ctx, ship, body, goal, config)
	for _ = 1, 300 do
		local intent = Flight.flyTo(ctx.sim, ctx.level.worlds, body, goal, config, { fuel = ship.fuel, hold = DT, dt = DT, horizon = 1.5 })
		step(ctx, intent)
		if ship.dead then
			break
		end
	end
end

test("fixture: flying straight at the goal hits the hard boundary", function()
	local ctx, ship, body, goal = racingOut()
	local straight = setmetatable({ ai = setmetatable({ detours = 0 }, { __index = Config.ai }) }, { __index = Config })

	flyFor(ctx, ship, body, goal, straight)

	assertTrue(ship.dead)
end)

test("Flight.flyTo steers clear of the hard boundary", function()
	local ctx, ship, body, goal = racingOut()

	flyFor(ctx, ship, body, goal, Config)

	assertFalse(ship.dead)
end)
