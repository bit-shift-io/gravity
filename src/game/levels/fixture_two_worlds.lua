-- Built-in fixture level: one convex world and one concave world, used as
-- the default until procedural level generation lands (slice 11). Vertices
-- are in virtual pixels (1280x720, y down) -- see docs/ARCHITECTURE.md
-- "Rules". `.new()` returns a fresh table on every call so callers (e.g.
-- Level.validate, which normalises worlds in place) never share mutable
-- state across separate matches.
local FixtureLevel = {}

function FixtureLevel.new()
	return {
		worlds = {
			{
				-- Convex: an octagon near the bottom-left of the arena.
				vertices = {
					{ x = 260, y = 500 },
					{ x = 340, y = 440 },
					{ x = 460, y = 440 },
					{ x = 540, y = 500 },
					{ x = 540, y = 600 },
					{ x = 460, y = 660 },
					{ x = 340, y = 660 },
					{ x = 260, y = 600 },
				},
			},
			{
				-- Concave: an L-shape near the top-right of the arena, with
				-- a reflex vertex at (880, 260).
				vertices = {
					{ x = 780, y = 160 },
					{ x = 1020, y = 160 },
					{ x = 1020, y = 260 },
					{ x = 880, y = 260 },
					{ x = 880, y = 360 },
					{ x = 780, y = 360 },
				},
			},
		},
		spawnPoints = {
			{ x = 200, y = 200 },
			{ x = 1080, y = 520 },
		},
		asteroids = {
			maxAlive = 2,
		},
	}
end

return FixtureLevel
