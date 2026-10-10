local Highlights = require("tools.trailer.highlights")

-- Per-step feature rows as Highlights.recorder produces them: steps[i] is step i.
local function quiet(count)
	local steps = {}
	for i = 1, count do
		steps[i] = {}
	end
	return steps
end

test("Trailer highlights rank a window dense with deaths above a sparse one", function()
	local steps = quiet(1000)
	-- Three deaths within a second near step 700, a lone death near step 200.
	steps[200].crash = 1
	steps[700].crash, steps[720].crash, steps[740].crash = 1, 1, 1
	local top = Highlights.top(steps, "multikill", { window = 240, count = 2 })
	assertEqual(2, #top)
	assertTrue(top[1].score > top[2].score)
	assertTrue(top[1].from < 700 and top[1].to >= 740, "best window covers the dense deaths")
	assertTrue(top[2].to >= 200 and top[2].from < 200, "runner-up covers the lone death")
end)

-- A match context with just what the recorder reads.
local function newCtx()
	return { events = {}, pools = { ships = {} }, intents = {}, round = { phase = "playing" } }
end

test("Trailer highlights count a retained event once however many steps it stays in ctx.events", function()
	local ctx = newCtx()
	local recorder = Highlights.recorder()
	local crash = { kind = "crash" }
	for step = 1, 5 do
		if step == 2 then
			table.insert(ctx.events, crash)
			table.insert(ctx.events, { kind = "blast" })
		end
		recorder:observe(ctx, step)
	end
	local steps = recorder:steps()
	assertEqual(5, #steps)
	assertEqual(1, steps[2].crash)
	assertEqual(1, steps[2].blast)
	local total = 0
	for _, row in ipairs(steps) do
		total = total + (row.crash or 0)
	end
	assertEqual(1, total)
end)

local Bodies = require("src.sim.bodies")

local function shipCtx()
	local ctx = newCtx()
	ctx.sim = { bodies = Bodies.new() }
	return ctx
end

local function addShip(ctx, state)
	local ship = {
		player = #ctx.pools.ships + 1,
		dead = false,
		fuel = { amount = 1 },
		lander = { state = state },
		weapon = { shell = nil, consumed = false, charging = false },
	}
	table.insert(ctx.pools.ships, ship)
	ctx.intents[ship.player] = { thrust = false }
	return ship
end

test("Trailer highlights count a landing when a flying ship turns tank, not ships that spawn as tanks", function()
	local ctx = shipCtx()
	local spawned = addShip(ctx, "tank")
	local lander = addShip(ctx, "flying")
	local recorder = Highlights.recorder()
	recorder:observe(ctx, 1)
	lander.lander.state = "tank"
	recorder:observe(ctx, 2)
	recorder:observe(ctx, 3)
	local steps = recorder:steps()
	assertEqual(nil, steps[1].landing)
	assertEqual(1, steps[2].landing)
	assertEqual(nil, steps[3].landing)
	assertEqual(spawned.lander.state, "tank")
end)

test("Trailer highlights count thrusting flying ships and tanks charging a shot", function()
	local ctx = shipCtx()
	local flyer = addShip(ctx, "flying")
	local tank = addShip(ctx, "tank")
	ctx.intents[flyer.player].thrust = true
	tank.weapon.charging = true
	local recorder = Highlights.recorder()
	recorder:observe(ctx, 1)
	assertEqual(1, recorder:steps()[1].thrust)
	assertEqual(1, recorder:steps()[1].tankFire)
end)

test("Trailer highlights count a remote detonation when an armed shell is consumed by the fire press", function()
	local ctx = shipCtx()
	local ship = addShip(ctx, "flying")
	local shell = Bodies.add(ctx.sim.bodies, { x = 0, y = 0, vx = 0, vy = 0, kind = "projectile", armed = true })
	ship.weapon.shell = shell
	local recorder = Highlights.recorder()
	recorder:observe(ctx, 1)
	-- Weapon.update on a fire press: shell cleared, consumed set.
	ship.weapon.shell = nil
	ship.weapon.consumed = true
	recorder:observe(ctx, 2)
	-- A shell that merely hit something clears its slot without `consumed`.
	ship.weapon.consumed = false
	ship.weapon.shell = shell
	recorder:observe(ctx, 3)
	ship.weapon.shell = nil
	recorder:observe(ctx, 4)
	-- Fire held from an earlier press (consumed stays true) while the next shell hits something.
	ship.weapon.consumed = true
	ship.weapon.shell = shell
	recorder:observe(ctx, 5)
	ship.weapon.shell = nil
	recorder:observe(ctx, 6)
	local steps = recorder:steps()
	assertEqual(nil, steps[6].detonation)
	assertEqual(nil, steps[1].detonation)
	assertEqual(1, steps[2].detonation)
	assertEqual(nil, steps[4].detonation)
end)

test("Trailer highlights mark the step a round locks and the step the next round resets", function()
	local ctx = newCtx()
	local recorder = Highlights.recorder()
	local phases = { "playing", "roundOver", "roundOver", "playing", "matchOver" }
	for step, phase in ipairs(phases) do
		ctx.round.phase = phase
		recorder:observe(ctx, step)
	end
	local steps = recorder:steps()
	assertEqual(nil, steps[1].roundEnd)
	assertEqual(1, steps[2].roundEnd)
	assertEqual(nil, steps[3].roundEnd)
	assertEqual(1, steps[4].reset)
	assertEqual(1, steps[5].roundEnd)
end)

test("Trailer highlights skip windows that span a round reset", function()
	local steps = quiet(1000)
	steps[500].crash, steps[505].crash, steps[510].crash = 1, 1, 1
	steps[505].reset = 1
	steps[900].crash = 1
	local top = Highlights.top(steps, "multikill", { window = 240, count = 3 })
	for _, hit in ipairs(top) do
		assertTrue(not (hit.from < 505 and hit.to >= 505), "window spans the reset")
	end
	assertTrue(#top >= 1)
end)

test("Trailer highlights end a roundwin window just after the card shows, on the busiest run-ups", function()
	local steps = quiet(2000)
	-- Round locks at step 600 after a pile-up; another locks at 1500 quietly.
	steps[560].crash, steps[580].crash, steps[600].roundEnd = 2, 1, 1
	steps[1500].roundEnd = 1
	steps[1000].crash = 3 -- busy, but no round ends near it
	local top = Highlights.top(steps, "roundwin", { window = 300, count = 2, afterLock = 210 })
	assertEqual(2, #top)
	assertEqual(600 + 210, top[1].to)
	assertEqual(600 + 210 - 300, top[1].from)
	assertEqual(1500 + 210, top[2].to)
end)

local ManifestCheck = require("tools.trailer.manifest_check")
local Config = require("src.game.config")
local LevelGen = require("src.game.level_gen")

test("Trailer highlights print entries that load and pass the manifest check", function()
	local roster = Highlights.roster(6)
	assertEqual(6, #roster)
	local ok, text = Highlights.entry({ name = "brawl_12_0", seed = 12, roster = roster, hit = { from = 300, to = 540, score = 9 } })
	assertTrue(ok, tostring(text))
	local shot = assert(load("return " .. text:gsub("^%-%-[^\n]*\n", "")))()
	assertEqual("brawl_12_0", shot.name)
	assertEqual(300, shot.from)
	assertEqual(540, shot.to)
	assertEqual(12, shot.seed)
	local valid, err = ManifestCheck.validate({ shots = { shot } })
	assertTrue(valid, tostring(err))
end)

test("Trailer highlights call a generated level blob, snake or mixed from its world outlines", function()
	local kinds = {}
	for seed = 1, 40 do
		kinds[Highlights.worldKind(LevelGen.generate(seed, Config))] = true
	end
	assertTrue(kinds.blob and kinds.snake, "both kinds occur in 40 seeds")
	local round, strip = {}, { { x = 0, y = 0 }, { x = 200, y = 0 }, { x = 200, y = 10 }, { x = 0, y = 10 }, { x = -5, y = 5 }, { x = -9, y = 5 } }
	for i = 1, 16 do
		round[i] = { x = 100 * math.cos(i / 16 * 2 * math.pi), y = 100 * math.sin(i / 16 * 2 * math.pi) }
	end
	local square = round
	assertEqual("blob", Highlights.worldKind({ worlds = { { vertices = square } } }))
	assertEqual("snake", Highlights.worldKind({ worlds = { { vertices = strip } } }))
	assertEqual("mixed", Highlights.worldKind({ worlds = { { vertices = square }, { vertices = strip } } }))
end)

test("Trailer highlights count a ship hopping on and off a surface as one landing per second", function()
	local ctx = shipCtx()
	local hopper = addShip(ctx, "flying")
	local recorder = Highlights.recorder()
	for step = 1, 130 do
		hopper.lander.state = step % 2 == 0 and "tank" or "flying"
		recorder:observe(ctx, step)
	end
	local landings = 0
	for _, row in ipairs(recorder:steps()) do
		landings = landings + (row.landing or 0)
	end
	assertEqual(3, landings)
end)
