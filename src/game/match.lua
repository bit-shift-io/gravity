-- Match: best of 5 rounds, one level layout for the whole match (see
-- docs/CONTEXT.md). Match.step(ctx) is where the whole frame order will
-- eventually live -- see docs/ARCHITECTURE.md "Systems and frame order".
-- Plain tables and function modules only; no classes (docs/ARCHITECTURE.md
-- "Rules").
local Match = {}

-- Builds the one ctx table passed to every system and component function
-- for this match. `level` is a literal level table (never a generated level
-- in tests, unless the test targets the generator); `config` is the tuning
-- table from src/game/config.lua.
function Match.new(level, config)
	return {
		dt = 0,
		time = 0,
		pools = {
			ships = {},
			projectiles = {},
			asteroids = {},
		},
		sim = {},
		level = level,
		config = config,
		intents = {},
		rng = nil,
		events = {},
	}
end

-- The whole frame order will live here (see docs/ARCHITECTURE.md). Empty for
-- this slice -- app's fixed-timestep accumulator calls it every step.
function Match.step(ctx) end

return Match
