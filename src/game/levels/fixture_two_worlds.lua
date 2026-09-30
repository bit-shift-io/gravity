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
					{ x = -380, y = 140 },
					{ x = -300, y = 80 },
					{ x = -180, y = 80 },
					{ x = -100, y = 140 },
					{ x = -100, y = 240 },
					{ x = -180, y = 300 },
					{ x = -300, y = 300 },
					{ x = -380, y = 240 },
				},
			},
			{
				-- Concave: an L-shape near the top-right of the arena, with
				-- a reflex vertex at (240, -100).
				vertices = {
					{ x = 140, y = -200 },
					{ x = 380, y = -200 },
					{ x = 380, y = -100 },
					{ x = 240, y = -100 },
					{ x = 240, y = 0 },
					{ x = 140, y = 0 },
				},
			},
		},
		spawnPoints = {
			{ x = -440, y = -160 },
			{ x = 440, y = 160 },
		},
		asteroids = {
			maxAlive = 2,
		},
	}
end

return FixtureLevel
