local Match = require("src.game.match")
local Config = require("src.game.config")
local Bodies = require("src.sim.bodies")
local ShipSystem = require("src.game.systems.ship_system")

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
