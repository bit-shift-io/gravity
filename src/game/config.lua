-- All tuning numbers live here (docs/ARCHITECTURE.md "Rules"). Sections are
-- empty until the slice that needs them fills them in -- nothing here is
-- speculative, the sections themselves just name where each future number
-- goes so systems can `require` this module now and start reading fields
-- as they land.
local Config = {
	-- Ship tuning (src/game/systems/ship_system.lua, src/game/components/
	-- thruster.lua). rotationSpeed is in radians/sec; thrustAccel in
	-- px/s^2, applied along the ship's nose while thrust intent is held and
	-- fuel remains. fuel.capacity/burnRate are in the same "tank" units --
	-- a full tank empties after capacity / burnRate seconds of continuous
	-- thrust.
	ship = {
		rotationSpeed = 3.5,
		thrustAccel = 220,
		mass = 1,
		fuel = {
			capacity = 10,
			burnRate = 1,
		},
	},
	projectile = {},
	asteroid = {},
	gravityField = {},
	world = {
		-- Default mass-per-area for a world that doesn't set its own
		-- density or an explicit mass (src/game/level.lua Level.validate).
		density = 1,
	},
	match = {},
	-- Softened inverse-square law shared by the baked static field
	-- (src/sim/field.lua) and later pairwise dynamic gravity (src/sim/gravity.lua,
	-- docs/adr/0002-hybrid-gravity-field.md).
	gravity = {
		G = 100,
		softening = 20,
	},
	-- The static gravity field grid (src/sim/field.lua).
	field = {
		cellSize = 16,
	},
	-- The soft-boundary margin added around the 1280x720 play area when
	-- baking the field grid (src/sim/field.lua Field.bake).
	boundary = {
		margin = 128,
	},
}

return Config
