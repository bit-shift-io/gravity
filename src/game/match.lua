-- Match: best of 5 rounds, one level layout for the whole match (see
-- docs/CONTEXT.md). Match.step(ctx) is where the whole frame order will
-- eventually live -- see docs/ARCHITECTURE.md "Systems and frame order".
-- Plain tables and function modules only; no classes (docs/ARCHITECTURE.md
-- "Rules").
local Field = require("src.sim.field")
local Bodies = require("src.sim.bodies")
local Sim = require("src.sim.step")
local Pools = require("src.game.pools")
local ShipSystem = require("src.game.systems.ship_system")

local Match = {}

-- Builds the one ctx table passed to every system and component function
-- for this match. `level` is a literal level table (never a generated level
-- in tests, unless the test targets the generator), already validated by
-- the caller (src/game/level.lua Level.validate) so its worlds have final
-- vertices and mass; `config` is the tuning table from src/game/config.lua.
--
-- The static gravity field is baked once here, into ctx.sim.field, rather
-- than lazily on first use -- it never changes for the rest of the match
-- (docs/CONTEXT.md "Static field"), so there's no reason to defer it.
function Match.new(level, config)
	local ctx = {
		dt = 0,
		time = 0,
		pools = Pools.new(),
		sim = {
			field = Field.bake(level, config),
			bodies = Bodies.new(),
		},
		level = level,
		config = config,
		intents = {},
		rng = nil,
		events = {},
	}

	-- Two ships spawn floating at the level's fixture spawn points, one per
	-- player (docs/CONTEXT.md "Ship"; slice 04 "Two ships spawn floating at
	-- fixture spawn points"). A level with no spawnPoints (e.g. the empty
	-- `{ worlds = {} }` fixtures earlier unit tests use) simply starts with
	-- no ships rather than erroring.
	if level.spawnPoints then
		for player, spawnPoint in ipairs(level.spawnPoints) do
			ShipSystem.spawn(ctx, player, spawnPoint)
		end
	end

	return ctx
end

-- The whole frame order (docs/ARCHITECTURE.md "Systems and frame order").
-- Steps 3, 5, and 6 are deliberately empty stubs for this slice -- spawners,
-- contact handling, and round rules arrive in slices 06, 07/09, and 10.
-- Ships pass through worlds this slice (no collision yet, that's slice 05).
function Match.step(ctx)
	-- 1. Player intents already live on ctx.intents -- app fills them in
	-- before calling Match.step (src/app/input.lua, src/app/states/
	-- match_state.lua), so there is nothing to read here.

	-- 2. Ship controls: rotate, thrust, fire.
	ShipSystem.update(ctx)

	-- 3. Spawners (asteroids). Empty stub -- slice 06.

	-- 4. Sim.step: gravity, integrate. (Collision/contacts arrive in
	-- slice 05, so there is no contact list yet.)
	Sim.step(ctx.sim, ctx.dt)

	-- 5. Systems handle contacts: land, bounce, destroy. Empty stub --
	-- slices 05/07/09.

	-- 6. Round rules. Empty stub -- slice 10.

	-- 7. Despawn sweep -- the only place records and bodies are removed.
	-- Pools sweep first so no record is left pointing at a body id that
	-- Bodies.sweep has already freed (this slice's Gotcha).
	Pools.sweep(ctx.pools)
	Bodies.sweep(ctx.sim.bodies)
end

return Match
