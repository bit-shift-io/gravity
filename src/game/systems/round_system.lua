-- Round rules (docs/ARCHITECTURE.md "Systems and frame order", step 6).
-- Round state lives on ctx.round:
--   { phase = "playing" | "roundOver" | "matchOver",
--     winner = nil | slot,   -- the match winner, set with matchOver
--     result = nil | { winner = slot } | { draw = true },   -- locked once set
--     timer = seconds since the result locked,
--     score = { [slot] = wins, ... one per roster slot } }
-- The result locks the first step at most one ship is alive. After
-- config.round.endDelay + cardDuration seconds (live scene, then the score
-- card) everything is marked dead (the step-7 sweep
-- removes it, docs/memory/round-reset-through-sweep.md) and fresh tank ships
-- spawn in the same step. A lock that gives a winner config.round.winsToWin
-- wins goes straight to "matchOver": no card, no respawn, no further rounds
-- (the sim keeps running, ignoring round rules).
local Bodies = require("src.sim.bodies")
local ShipSystem = require("src.game.systems.ship_system")
local SpawnPoints = require("src.game.spawn_points")

local RoundSystem = {}

-- `slots` is the roster size (defaults to 2); the score has one entry each.
function RoundSystem.new(slots)
	local score = {}
	for slot = 1, slots or 2 do
		score[slot] = 0
	end
	return { phase = "playing", result = nil, timer = 0, score = score }
end

local function aliveShips(ctx)
	local alive = {}
	for _, ship in ipairs(ctx.pools.ships) do
		if not ship.dead then
			alive[#alive + 1] = ship
		end
	end
	return alive
end

local function killAll(ctx, pool)
	for _, record in ipairs(pool) do
		record.dead = true
		Bodies.markDead(ctx.sim.bodies, record.body)
	end
end

-- Marks every record dead and spawns one tank per roster slot at distinct random spawn
-- candidates (fixture levels without a candidate list use spawnPoints).
function RoundSystem.respawn(ctx)
	killAll(ctx, ctx.pools.ships)
	killAll(ctx, ctx.pools.projectiles)
	killAll(ctx, ctx.pools.asteroids)
	killAll(ctx, ctx.pools.particles)

	ctx.asteroidSpawnTimer = 0
	for i = #ctx.events, 1, -1 do
		ctx.events[i] = nil
	end

	local points = ctx.level.spawnCandidates or ctx.level.spawnPoints or {}
	for player, point in ipairs(SpawnPoints.pick(points, #ctx.round.score, ctx.rng)) do
		ShipSystem.spawn(ctx, player, point)
	end
end

-- Seconds from the result locking to the respawn: the live end delay plus the
-- score card.
local function holdSeconds(roundConfig)
	return roundConfig.endDelay + (roundConfig.cardDuration or 0)
end

-- True while the score card should show: after the end delay, before respawn.
-- Shared by the overlay and tests.
function RoundSystem.cardVisible(round, roundConfig)
	return round.phase == "roundOver"
		and round.timer >= roundConfig.endDelay
		and round.timer < holdSeconds(roundConfig)
end

-- The player whose score reached winsToWin, or nil. Pure.
function RoundSystem.matchWinner(score, winsToWin)
	for player = 1, #score do
		if score[player] >= winsToWin then
			return player
		end
	end
	return nil
end

-- True once the match has a winner. Shared by the overlay, input and tests.
function RoundSystem.matchOver(round)
	return round.phase == "matchOver"
end

function RoundSystem.update(ctx)
	local round = ctx.round
	if round.phase == "matchOver" then
		return
	end
	if round.phase == "playing" then
		-- A level that never spawned two ships has no round to decide.
		if #ctx.pools.ships < 2 then
			return
		end
		local alive = aliveShips(ctx)
		if #alive > 1 then
			return
		end
		round.phase = "roundOver"
		round.timer = 0
		if #alive == 1 then
			local winner = alive[1].player
			round.result = { winner = winner }
			round.score[winner] = round.score[winner] + 1
			if RoundSystem.matchWinner(round.score, ctx.config.round.winsToWin) then
				round.phase = "matchOver"
				round.winner = winner
			end
		else
			round.result = { draw = true }
		end
	else
		round.timer = round.timer + ctx.dt
		if round.timer >= holdSeconds(ctx.config.round) then
			RoundSystem.respawn(ctx)
			ctx.round.phase = "playing"
			ctx.round.result = nil
			ctx.round.timer = 0
		end
	end
end

return RoundSystem
