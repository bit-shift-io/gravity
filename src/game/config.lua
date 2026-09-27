-- All tuning numbers live here (docs/ARCHITECTURE.md "Rules"). Sections are
-- empty until the slice that needs them fills them in -- nothing here is
-- speculative, the sections themselves just name where each future number
-- goes so systems can `require` this module now and start reading fields
-- as they land.
local Config = {
	ship = {},
	projectile = {},
	asteroid = {},
	gravityField = {},
	world = {
		-- Default mass-per-area for a world that doesn't set its own
		-- density or an explicit mass (src/game/level.lua Level.validate).
		density = 1,
	},
	match = {},
}

return Config
