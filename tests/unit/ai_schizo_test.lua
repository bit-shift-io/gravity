local Match = require("src.game.match")
local Config = require("src.game.config")
local Bodies = require("src.sim.bodies")
local AI = require("src.game.ai.init")

local DT = 1 / 60

-- Same floor and ledge as tests/unit/ai_chaos_test.lua.
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

-- Slot 1 is a keyboard target on the ledge, slot 2 a hard schizo AI on the
-- floor. A kill starts the next round almost at once and the match never
-- ends, so schizo keeps shooting.
local function newSchizo(seed)
	local config = setmetatable({
		round = { endDelay = 0.1, cardDuration = 0.1, winsToWin = math.huge },
	}, { __index = Config })
	local roster = {
		{ color = 1, binding = { kind = "keyboard", layout = "wasd" } },
		{ color = 2, binding = { kind = "ai", level = "hard", behavior = "schizo" } },
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

local function step(ctx)
	ctx.intents[1] = NEUTRAL
	Match.step(ctx)
	ctx.time = ctx.time + ctx.dt
end

-- Slot 2's ship this round (it respawns each round).
local function schizoShip(ctx)
	for _, ship in ipairs(ctx.pools.ships) do
		if ship.player == 2 then
			return ship
		end
	end
	return nil
end

-- Steps `steps` times. Returns the personalities schizo played, in order,
-- and the number of shells slot 2 launched.
local function run(ctx, steps)
	local played, launches, last = {}, 0, nil
	for _ = 1, steps do
		step(ctx)
		local own = schizoShip(ctx)
		local shell = own and own.weapon.shell
		if shell and shell ~= last then
			launches = launches + 1
		end
		last = shell or last
		local current = ctx.schizo[2].current
		if played[#played] ~= current then
			played[#played + 1] = current
		end
	end
	return played, launches
end

-- Steps until slot 2's first shell is in flight (at most a minute).
local function untilLaunch(ctx)
	local own = ctx.pools.ships[2]
	for _ = 1, 60 * 60 do
		step(ctx)
		if own.weapon.shell then
			return
		end
	end
	error("schizo never launched a shell")
end

test("schizo is a pooled meta kind", function()
	assertTrue(AI.kinds.schizo ~= nil)
	assertTrue(AI.meta.schizo)
	assertFalse(AI.unpooled.schizo)
end)

test("schizo keeps its personality while it launches no shot", function()
	local ctx = newSchizo(7)
	local own = ctx.pools.ships[2]
	step(ctx)
	local first = ctx.schizo[2].current
	for _ = 1, 60 * 60 do
		if own.weapon.shell then
			return
		end
		assertEqual(first, ctx.schizo[2].current)
		assertEqual(0, ctx.schizo[2].switches)
		step(ctx)
	end
	error("schizo never launched a shell")
end)

test("schizo switches personality exactly once per launched shot", function()
	local ctx = newSchizo(7)
	local _, launches = run(ctx, 60 * 60)
	assertTrue(launches >= 5, "launches " .. launches)
	-- The last launch may still be waiting for the next think to see it.
	local switches = ctx.schizo[2].switches
	assertTrue(switches == launches or switches == launches - 1, switches .. " vs " .. launches)
end)

test("each switch picks a different personality, never schizo or chaos", function()
	local played = run(newSchizo(7), 60 * 60)
	assertTrue(#played >= 5, "played " .. #played)
	for i, name in ipairs(played) do
		assertTrue(name ~= "schizo" and name ~= "chaos", name)
		assertTrue(AI.kinds[name] ~= nil, name)
		assertTrue(i == 1 or played[i - 1] ~= name)
	end
end)

test("schizo with the same seed plays the same personality sequence", function()
	local a = run(newSchizo(7), 30 * 60)
	local b = run(newSchizo(7), 30 * 60)
	assertEqual(table.concat(a, ","), table.concat(b, ","))
end)

test("schizo with a different seed plays a different personality sequence", function()
	local a = run(newSchizo(7), 30 * 60)
	local b = run(newSchizo(8), 30 * 60)
	assertTrue(table.concat(a, ",") ~= table.concat(b, ","))
end)

test("a switch resets the slot's AI memory", function()
	local ctx = newSchizo(7)
	untilLaunch(ctx)
	ctx.ai[2].mode = "stale"
	step(ctx)
	assertEqual(1, ctx.schizo[2].switches)
	assertTrue(ctx.ai[2].mode ~= "stale")
end)

-- Hands a live shell to each personality straight after the switch and
-- plays on: the new personality must cope with a shell it did not fire.
test("schizo survives a mid-flight handoff to any personality", function()
	for _, name in ipairs(AI.pool()) do
		if not AI.meta[name] then
			local ctx = newSchizo(7)
			untilLaunch(ctx)
			step(ctx)
			ctx.schizo[2].current = name
			for _ = 1, 10 * 60 do
				step(ctx)
			end
			assertTrue(ctx.schizo[2].switches >= 1, name)
		end
	end
end)
