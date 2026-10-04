local Match = require("src.game.match")
local Config = require("src.game.config")
local Bodies = require("src.sim.bodies")
local ShipSystem = require("src.game.systems.ship_system")
local RoundSystem = require("src.game.systems.round_system")

local function floorWorld()
	return {
		vertices = { { x = -300, y = 0 }, { x = 300, y = 0 }, { x = 300, y = 40 }, { x = -300, y = 40 } },
		mass = 1000,
	}
end

-- Two tank spawn points on top of one floor, plus a third candidate.
local function level(withCandidates)
	local world = floorWorld()
	local function point(x)
		return { x = x, y = 0, normal = { x = 0, y = -1 }, world = world }
	end
	local lvl = { worlds = { world }, spawnPoints = { point(-200), point(200) } }
	if withCandidates then
		lvl.spawnCandidates = { point(-250), point(-100), point(0), point(100), point(250) }
	end
	return lvl
end

local function newCtx(withCandidates, seed)
	local ctx = Match.new(level(withCandidates), Config, seed or 1)
	ctx.dt = 1 / 60
	return ctx
end

local function kill(ctx, ship)
	ship.dead = true
	Bodies.markDead(ctx.sim.bodies, ship.body)
end

-- Whole hold: live end delay, then the score card.
local function holdSeconds()
	return Config.round.endDelay + Config.round.cardDuration
end

local function runSeconds(ctx, seconds)
	for _ = 1, math.ceil(seconds * 60) + 3 do
		Match.step(ctx)
	end
end

test("a fresh match is in the playing phase with a 0-0 score", function()
	local ctx = newCtx()
	assertEqual("playing", ctx.round.phase)
	assertEqual(0, ctx.round.score[1])
	assertEqual(0, ctx.round.score[2])
	assertEqual(nil, ctx.round.result)
end)

test("one survivor scores a point for that player", function()
	local ctx = newCtx()
	kill(ctx, ctx.pools.ships[1])
	Match.step(ctx)

	assertEqual("roundOver", ctx.round.phase)
	assertEqual(2, ctx.round.result.winner)
	assertEqual(0, ctx.round.score[1])
	assertEqual(1, ctx.round.score[2])
end)

test("both ships dying in the same step is a draw with no point", function()
	local ctx = newCtx()
	kill(ctx, ctx.pools.ships[1])
	kill(ctx, ctx.pools.ships[2])
	Match.step(ctx)

	assertEqual("roundOver", ctx.round.phase)
	assertTrue(ctx.round.result.draw)
	assertEqual(nil, ctx.round.result.winner)
	assertEqual(0, ctx.round.score[1])
	assertEqual(0, ctx.round.score[2])
end)

test("the result locks once: the survivor dying during the hold changes nothing", function()
	local ctx = newCtx()
	local loser, survivor = ctx.pools.ships[1], ctx.pools.ships[2]
	kill(ctx, loser)
	Match.step(ctx)
	kill(ctx, survivor)
	Match.step(ctx)
	Match.step(ctx)

	assertEqual(2, ctx.round.result.winner)
	assertEqual(1, ctx.round.score[2])
end)

test("nothing respawns before the end delay and card duration elapse", function()
	local ctx = newCtx()
	kill(ctx, ctx.pools.ships[1])
	runSeconds(ctx, holdSeconds() - 0.5)

	assertEqual("roundOver", ctx.round.phase)
end)

test("after the end delay and card both ships respawn as full-fuel tanks and play resumes", function()
	local ctx = newCtx()
	local survivor = ctx.pools.ships[2]
	survivor.fuel.amount = 1
	kill(ctx, ctx.pools.ships[1])
	runSeconds(ctx, holdSeconds())

	assertEqual("playing", ctx.round.phase)
	assertEqual(nil, ctx.round.result)
	assertEqual(2, #ctx.pools.ships)
	for player, ship in ipairs(ctx.pools.ships) do
		assertEqual(player, ship.player)
		assertTrue(not ship.dead)
		assertTrue(ship ~= survivor)
		assertEqual("tank", ship.lander.state)
		assertEqual(Config.ship.fuel.capacity, ship.fuel.amount)
		assertEqual(0, ship.turret.angle)
	end
	assertEqual(1, ctx.round.score[2])
end)

test("respawn clears projectiles, asteroids, particles and old crash events", function()
	local ctx = newCtx()
	local function addRecord(pool, kind)
		local id = Bodies.add(ctx.sim.bodies, { x = 50, y = -30, vx = 0, vy = 0, mass = 100, kind = kind, passive = true, angle = 0, vertices = { { x = -5, y = -5 }, { x = 5, y = -5 }, { x = 0, y = 5 } } })
		table.insert(pool, { id = id, body = id, dead = false, age = 0, life = 5 })
	end
	addRecord(ctx.pools.projectiles, "projectile")
	addRecord(ctx.pools.asteroids, "asteroid")
	addRecord(ctx.pools.particles, "particle")
	table.insert(ctx.events, { kind = "crash", x = 0, y = 0, time = ctx.time })
	ctx.asteroidSpawnTimer = 3

	kill(ctx, ctx.pools.ships[1])
	runSeconds(ctx, holdSeconds())

	assertEqual(0, #ctx.pools.projectiles)
	assertEqual(0, #ctx.pools.asteroids)
	assertEqual(0, #ctx.pools.particles)
	assertEqual(0, #ctx.events)
	assertTrue(ctx.asteroidSpawnTimer < 1)
end)

test("later rounds respawn at two distinct spawn candidates", function()
	local ctx = newCtx(true)
	kill(ctx, ctx.pools.ships[1])
	runSeconds(ctx, holdSeconds())

	local candidates = {}
	for _, point in ipairs(ctx.level.spawnCandidates) do
		candidates[point.x] = true
	end
	local a = Bodies.get(ctx.sim.bodies, ctx.pools.ships[1].body)
	local b = Bodies.get(ctx.sim.bodies, ctx.pools.ships[2].body)
	assertTrue(a.x ~= b.x, "ships share a spawn point")
	assertTrue(candidates[a.x] and candidates[b.x], "ships did not spawn at candidates")
end)

test("respawn positions repeat for the same seed and vary across seeds", function()
	local function respawnXs(seed)
		local ctx = newCtx(true, seed)
		kill(ctx, ctx.pools.ships[1])
		runSeconds(ctx, holdSeconds())
		local a = Bodies.get(ctx.sim.bodies, ctx.pools.ships[1].body)
		local b = Bodies.get(ctx.sim.bodies, ctx.pools.ships[2].body)
		return a.x .. "," .. b.x
	end

	assertEqual(respawnXs(5), respawnXs(5))
	local seen = {}
	local distinct = 0
	for seed = 1, 10 do
		local key = respawnXs(seed)
		if not seen[key] then
			seen[key] = true
			distinct = distinct + 1
		end
	end
	assertTrue(distinct > 1, "respawn pair never varies by seed")
end)

test("a level without a candidate list falls back to spawnPoints", function()
	local ctx = newCtx(false)
	kill(ctx, ctx.pools.ships[1])
	runSeconds(ctx, holdSeconds())

	assertEqual(2, #ctx.pools.ships)
	local xs = {}
	for _, ship in ipairs(ctx.pools.ships) do
		xs[#xs + 1] = Bodies.get(ctx.sim.bodies, ship.body).x
	end
	table.sort(xs)
	assertEqual(-200, xs[1])
	assertEqual(200, xs[2])
end)

test("a level with no ships never ends a round", function()
	local ctx = Match.new({ worlds = {} }, Config)
	ctx.dt = 1 / 60
	runSeconds(ctx, 1)
	assertEqual("playing", ctx.round.phase)
end)

test("the card is visible only between the end delay and the respawn", function()
	local RoundSystem = require("src.game.systems.round_system")
	local cfg = Config.round
	local function visibleAt(phase, timer)
		return RoundSystem.cardVisible({ phase = phase, timer = timer }, cfg)
	end

	assertFalse(visibleAt("playing", 0))
	assertFalse(visibleAt("roundOver", 0))
	assertFalse(visibleAt("roundOver", cfg.endDelay - 0.01))
	assertTrue(visibleAt("roundOver", cfg.endDelay))
	assertTrue(visibleAt("roundOver", cfg.endDelay + cfg.cardDuration - 0.01))
	assertFalse(visibleAt("roundOver", cfg.endDelay + cfg.cardDuration))
	assertFalse(visibleAt("playing", cfg.endDelay))
end)

-- Plays one round to a kill: the given player wins.
local function winRound(ctx, player)
	kill(ctx, ctx.pools.ships[3 - player])
	runSeconds(ctx, holdSeconds())
end

test("the round that gives a player their third win ends the match with no card or respawn", function()
	local RoundSystem = require("src.game.systems.round_system")
	local ctx = newCtx()
	winRound(ctx, 2)
	winRound(ctx, 2)
	assertEqual("playing", ctx.round.phase)

	local survivor = ctx.pools.ships[2]
	kill(ctx, ctx.pools.ships[1])
	Match.step(ctx)

	assertEqual("matchOver", ctx.round.phase)
	assertEqual(2, ctx.round.winner)
	assertEqual(3, ctx.round.score[2])
	assertTrue(RoundSystem.matchOver(ctx.round))
	assertFalse(RoundSystem.cardVisible(ctx.round, Config.round))

	runSeconds(ctx, holdSeconds() + 1)
	assertEqual("matchOver", ctx.round.phase)
	assertEqual(1, #ctx.pools.ships)
	assertTrue(ctx.pools.ships[1] == survivor, "ships respawned after match over")
end)

test("a draw at 2-2 does not end the match", function()
	local RoundSystem = require("src.game.systems.round_system")
	local ctx = newCtx()
	winRound(ctx, 1)
	winRound(ctx, 1)
	winRound(ctx, 2)
	winRound(ctx, 2)
	kill(ctx, ctx.pools.ships[1])
	kill(ctx, ctx.pools.ships[2])
	Match.step(ctx)

	assertEqual("roundOver", ctx.round.phase)
	assertFalse(RoundSystem.matchOver(ctx.round))
	runSeconds(ctx, holdSeconds())
	assertEqual("playing", ctx.round.phase)
	assertEqual(nil, ctx.round.winner)
end)

test("no further round locks once the match is over", function()
	local ctx = newCtx()
	winRound(ctx, 1)
	winRound(ctx, 1)
	winRound(ctx, 1)
	assertEqual("matchOver", ctx.round.phase)
	for _, ship in ipairs(ctx.pools.ships) do
		kill(ctx, ship)
	end
	runSeconds(ctx, 1)

	assertEqual("matchOver", ctx.round.phase)
	assertEqual(3, ctx.round.score[1])
	assertEqual(0, ctx.round.score[2])
	assertEqual(1, ctx.round.result.winner)
end)

-- N-slot rounds: a floor with 2 spawn points and 8 candidates.
local function manySlotRoster(n)
	local roster = {}
	for i = 1, n do
		roster[i] = { color = i, binding = { kind = "ai", level = "easy" } }
	end
	return roster
end

local function manySlotCtx(n, seed)
	local world = floorWorld()
	local function point(x)
		return { x = x, y = 0, normal = { x = 0, y = -1 }, world = world }
	end
	local candidates = {}
	for i = 1, 8 do
		candidates[i] = point(-280 + i * 60)
	end
	local lvl = { worlds = { world }, spawnPoints = { candidates[1], candidates[8] }, spawnCandidates = candidates }
	local ctx = Match.new(lvl, Config, seed or 1, { roster = manySlotRoster(n) })
	ctx.dt = 1 / 60
	return ctx
end

test("a 4-slot match starts 4 ships on a 4-entry score", function()
	local ctx = manySlotCtx(4)
	assertEqual(4, #ctx.pools.ships)
	assertEqual(4, #ctx.round.score)
	assertEqual("playing", ctx.round.phase)
end)

test("in a 6-slot round the last ship alive wins the point", function()
	local ctx = manySlotCtx(6)
	for i = 1, 5 do
		kill(ctx, ctx.pools.ships[i])
	end
	Match.step(ctx)

	assertEqual("roundOver", ctx.round.phase)
	assertEqual(6, ctx.round.result.winner)
	assertEqual(1, ctx.round.score[6])
	assertEqual(0, ctx.round.score[1])
end)

test("a round with several ships left alive keeps playing", function()
	local ctx = manySlotCtx(4)
	kill(ctx, ctx.pools.ships[1])
	kill(ctx, ctx.pools.ships[2])
	Match.step(ctx)
	assertEqual("playing", ctx.round.phase)
end)

test("the last several ships dying in the same step is a draw", function()
	local ctx = manySlotCtx(4)
	for _, ship in ipairs(ctx.pools.ships) do
		kill(ctx, ship)
	end
	Match.step(ctx)

	assertTrue(ctx.round.result.draw)
	for slot = 1, 4 do
		assertEqual(0, ctx.round.score[slot])
	end
end)

test("the first of 6 slots to winsToWin ends the match", function()
	local ctx = manySlotCtx(6)
	ctx.round.score[5] = Config.round.winsToWin - 1
	for i = 1, 6 do
		if i ~= 5 then
			kill(ctx, ctx.pools.ships[i])
		end
	end
	Match.step(ctx)

	assertEqual("matchOver", ctx.round.phase)
	assertEqual(5, ctx.round.winner)
end)

test("a 6-slot respawn places six ships on distinct points", function()
	local ctx = manySlotCtx(6, 3)
	for i = 1, 5 do
		kill(ctx, ctx.pools.ships[i])
	end
	runSeconds(ctx, holdSeconds())

	assertEqual("playing", ctx.round.phase)
	local alive, seen = {}, {}
	for _, ship in ipairs(ctx.pools.ships) do
		if not ship.dead then
			alive[#alive + 1] = ship
			local body = Bodies.get(ctx.sim.bodies, ship.body)
			local key = body.x .. "," .. body.y
			assertTrue(not seen[key], "two ships share a spawn point")
			seen[key] = true
		end
	end
	assertEqual(6, #alive)
end)

-- Humans-dead timeout: slot 1 human (keyboard), slots 2-3 AI. Drives the
-- round system directly so the AIs do not act. The timeout is shortened.
local function timeoutCtx(roster)
	local world = floorWorld()
	local function point(x)
		return { x = x, y = 0, normal = { x = 0, y = -1 }, world = world }
	end
	local lvl = { worlds = { world }, spawnPoints = { point(-200), point(200) } }
	lvl.spawnCandidates = { point(-250), point(-100), point(0), point(100), point(250) }
	local cfg = setmetatable({ round = {} }, { __index = Config })
	for key, value in pairs(Config.round) do
		cfg.round[key] = value
	end
	cfg.round.humansDeadTimeout = 2
	local ctx = Match.new(lvl, cfg, 1, { roster = roster })
	ctx.dt = 1 / 60
	return ctx
end

local function humanPlusAis()
	return {
		{ color = 1, binding = { kind = "keyboard", layout = "wasd" } },
		{ color = 2, binding = { kind = "ai", level = "easy" } },
		{ color = 3, binding = { kind = "ai", level = "easy" } },
	}
end

local function allAis()
	return {
		{ color = 1, binding = { kind = "ai", level = "easy" } },
		{ color = 2, binding = { kind = "ai", level = "easy" } },
		{ color = 3, binding = { kind = "ai", level = "easy" } },
	}
end

local function tick(ctx, seconds)
	for _ = 1, math.ceil(seconds * 60) do
		RoundSystem.update(ctx)
	end
end

test("while a human lives the humans-dead timer never runs", function()
	local ctx = timeoutCtx(humanPlusAis())
	kill(ctx, ctx.pools.ships[2])
	tick(ctx, 10)

	assertEqual("playing", ctx.round.phase)
	assertEqual(nil, ctx.round.humansDeadTimer)
end)

test("the humans-dead timer starts once the last human dies", function()
	local ctx = timeoutCtx(humanPlusAis())
	kill(ctx, ctx.pools.ships[1])
	tick(ctx, 1)

	assertEqual("playing", ctx.round.phase)
	assertTrue(math.abs(ctx.round.humansDeadTimer - 1) < 0.05)
end)

test("the round ends as a draw when the humans-dead timeout expires", function()
	local ctx = timeoutCtx(humanPlusAis())
	kill(ctx, ctx.pools.ships[1])
	tick(ctx, ctx.config.round.humansDeadTimeout + 0.1)

	assertEqual("roundOver", ctx.round.phase)
	assertTrue(ctx.round.result.draw)
	assertEqual(0, ctx.round.score[2])
	assertEqual(0, ctx.round.score[3])
end)

test("an AI winning before the timeout wins as usual", function()
	local ctx = timeoutCtx(humanPlusAis())
	kill(ctx, ctx.pools.ships[1])
	tick(ctx, 1)
	kill(ctx, ctx.pools.ships[3])
	tick(ctx, 0.1)

	assertEqual("roundOver", ctx.round.phase)
	assertEqual(2, ctx.round.result.winner)
	assertEqual(1, ctx.round.score[2])
end)

test("an all-AI match never starts the humans-dead timer", function()
	local ctx = timeoutCtx(allAis())
	tick(ctx, ctx.config.round.humansDeadTimeout * 3)

	assertEqual("playing", ctx.round.phase)
	assertEqual(nil, ctx.round.humansDeadTimer)
end)

test("the drawn round replays with the humans-dead timer cleared", function()
	local ctx = timeoutCtx(humanPlusAis())
	kill(ctx, ctx.pools.ships[1])
	tick(ctx, ctx.config.round.humansDeadTimeout + 0.1)
	tick(ctx, holdSeconds())

	assertEqual("playing", ctx.round.phase)
	assertEqual(nil, ctx.round.result)
	assertEqual(nil, ctx.round.humansDeadTimer)
end)

-- Fast-forward: the app runs stepsPerFrame Match.steps per frame.
test("while a human lives the sim runs one step per frame", function()
	local ctx = timeoutCtx(humanPlusAis())
	kill(ctx, ctx.pools.ships[2])

	assertEqual(1, RoundSystem.stepsPerFrame(ctx))
end)

test("once every human is dead the sim fast-forwards at the configured steps", function()
	local ctx = timeoutCtx(humanPlusAis())
	kill(ctx, ctx.pools.ships[1])

	assertEqual(ctx.config.round.fastForwardSteps, RoundSystem.stepsPerFrame(ctx))
	assertTrue(ctx.config.round.fastForwardSteps > 1)
end)

test("an all-AI match never fast-forwards", function()
	local ctx = timeoutCtx(allAis())

	assertEqual(1, RoundSystem.stepsPerFrame(ctx))
end)

test("a level that never spawned two ships never fast-forwards", function()
	local ctx = timeoutCtx(humanPlusAis())
	ctx.pools.ships = {}

	assertEqual(1, RoundSystem.stepsPerFrame(ctx))
end)

test("normal speed returns once the round locks, through the card and the reset", function()
	local ctx = timeoutCtx(humanPlusAis())
	kill(ctx, ctx.pools.ships[1])
	tick(ctx, ctx.config.round.humansDeadTimeout + 0.1)
	assertEqual("roundOver", ctx.round.phase)
	assertEqual(1, RoundSystem.stepsPerFrame(ctx))

	tick(ctx, holdSeconds())
	assertEqual("playing", ctx.round.phase)
	assertEqual(1, RoundSystem.stepsPerFrame(ctx))
end)

-- Match.advance: one frame of the app (and the test harness).
local DT = 1 / 60

test("a frame with a human alive runs one step", function()
	local ctx = timeoutCtx(humanPlusAis())

	assertEqual(1, Match.advance(ctx, DT))
	assertNear(DT, ctx.time, 1e-12)
end)

test("a frame with every human dead runs the fast-forward steps at the normal dt", function()
	local ctx = timeoutCtx(humanPlusAis())
	kill(ctx, ctx.pools.ships[1])

	local steps = Match.advance(ctx, DT)
	assertEqual(ctx.config.round.fastForwardSteps, steps)
	assertEqual(DT, ctx.dt)
	assertNear(steps * DT, ctx.time, 1e-12)
end)

test("a fast-forwarded frame stops at the step that locks the round", function()
	local ctx = timeoutCtx(humanPlusAis())
	kill(ctx, ctx.pools.ships[1])
	kill(ctx, ctx.pools.ships[3])

	assertEqual(1, Match.advance(ctx, DT))
	assertEqual("roundOver", ctx.round.phase)
end)
