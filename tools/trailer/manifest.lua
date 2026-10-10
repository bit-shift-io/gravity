-- Trailer manifest (docs/CONTEXT.md "Trailer manifest"): the shots that make up
-- the Steam trailer, and the `sequence` they play in. Dev-only; the game never
-- reads it. Validated by manifest_check.lua before anything renders. glow/crt
-- are set on every shot so output does not depend on the saved in-game look.
--
-- First draft, 66 s, six beats (see docs/TRAILER.md "The draft trailer"):
--   0-4   cold open    4-17  gravity    17-35 arsenal
--   35-50 chaos        50-57 couch      57-66 end card
-- Every shot comes from a seeded all-AI match, so any change to the sim, AI
-- or level generation reshuffles them: re-scout after such a change.
--
-- The game font has no "·" or "–" glyphs, so captions use "/" and "-".

-- All-AI roster of `players` hard bots in palette order (as the highlight
-- finder plays them, so its seeds and steps replay here).
local function bots(players)
	local roster = {}
	for slot = 1, players do
		roster[slot] = { color = slot, binding = { kind = "ai", level = "hard" } }
	end
	return roster
end

return {
	shots = {
		-- 1. Cold open: four ships around a tank go up in one blast at step 2032
		-- (frame 197); the camera pushes in on it.
		{
			name = "cold_open",
			seed = 74,
			roster = bots(6),
			from = 1835,
			to = 2075,
			camera = {
				{ t = 0, x = -20, y = 0, zoom = 1.9 },
				{ t = 0.75, x = -140, y = -70, zoom = 2.6 },
				{ t = 1, x = -145, y = -72, zoom = 2.75 },
			},
			hud = false,
			fadeIn = 0.4,
			glow = true,
			crt = true,
		},
		-- 2. Gravity: six ships lift off a blob at the round start, then two
		-- ships fall around a world.
		{
			name = "gravity_launch",
			seed = 61,
			roster = bots(6),
			from = 0,
			to = 360,
			camera = {
				{ t = 0, x = 360, y = -20, zoom = 1.6 },
				{ t = 1, x = 360, y = -20, zoom = 1.35 },
			},
			hud = false,
			glow = true,
			crt = true,
		},
		{
			name = "gravity_orbit",
			seed = 74,
			roster = bots(3),
			from = 1450,
			to = 1870,
			camera = {
				{ t = 0, x = -30, y = -45, zoom = 1.4 },
				{ t = 1, x = -30, y = -45, zoom = 1.6 },
			},
			hud = false,
			captions = {
				{ text = "GRAVITY IS THE WEAPON", from = 0.8, to = 6.4, anchor = "bottom" },
			},
			glow = true,
			crt = true,
		},
		-- 3. Arsenal: an asteroid split, ships landing as tanks, tank airbursts.
		{
			name = "arsenal_asteroids",
			seed = 178,
			roster = bots(6),
			from = 611,
			to = 881,
			camera = { x = 225, y = 0, zoom = 2.4 },
			hud = false,
			glow = true,
			crt = true,
		},
		{
			name = "arsenal_tanks",
			seed = 74,
			roster = bots(3),
			from = 2676,
			to = 3036,
			camera = {
				{ t = 0, x = -24, y = -56, zoom = 2.0 },
				{ t = 1, x = -24, y = -56, zoom = 2.2 },
			},
			hud = false,
			glow = true,
			crt = true,
		},
		{
			name = "arsenal_airburst",
			seed = 58,
			roster = bots(2),
			from = 2371,
			to = 2641,
			camera = {
				{ t = 0, x = 165, y = 0, zoom = 3.4 },
				{ t = 1, x = 160, y = -20, zoom = 2.9 },
			},
			hud = false,
			glow = true,
			crt = true,
		},
		{
			name = "arsenal_detonate",
			seed = 43,
			roster = bots(3),
			from = 420,
			to = 600,
			camera = { x = -320, y = -160, zoom = 3.0 },
			hud = false,
			glow = true,
			crt = true,
		},
		-- 4. Chaos: six-player brawls, HUD on so all six score blocks show.
		{
			name = "chaos_blob",
			seed = 83,
			roster = bots(6),
			from = 2950,
			to = 3250,
			camera = {
				{ t = 0, x = 36, y = 215, zoom = 1.52, ease = "linear" },
				{ t = 0.25, x = 32, y = 219, zoom = 1.57, ease = "linear" },
				{ t = 0.5, x = 31, y = 231, zoom = 1.7, ease = "linear" },
				{ t = 0.75, x = 35, y = 245, zoom = 1.76, ease = "linear" },
				{ t = 1, x = 35, y = 247, zoom = 1.75 },
			},
			hud = true,
			captions = {
				{ text = "UP TO 6 PLAYERS / ONE SCREEN", from = 0.6, to = 4.7, anchor = "bottom" },
			},
			glow = true,
			crt = true,
		},
		{
			name = "chaos_snake",
			seed = 13,
			roster = bots(6),
			from = 600,
			to = 900,
			camera = {
				{ t = 0, x = 96, y = -103, zoom = 1.42, ease = "linear" },
				{ t = 0.25, x = 75, y = -96, zoom = 1.46, ease = "linear" },
				{ t = 0.5, x = -6, y = -76, zoom = 1.59, ease = "linear" },
				{ t = 0.75, x = -58, y = -35, zoom = 1.71, ease = "linear" },
				{ t = 1, x = -60, y = 2, zoom = 1.7 },
			},
			hud = true,
			glow = true,
			crt = true,
		},
		{
			name = "chaos_blob_2",
			seed = 126,
			roster = bots(6),
			from = 400,
			to = 700,
			camera = {
				{ t = 0, x = 176, y = -122, zoom = 1.29, ease = "linear" },
				{ t = 0.25, x = 175, y = -94, zoom = 1.18, ease = "linear" },
				{ t = 0.5, x = 161, y = -66, zoom = 1.1, ease = "linear" },
				{ t = 0.75, x = 109, y = -84, zoom = 1.16, ease = "linear" },
				{ t = 1, x = 60, y = -115, zoom = 1.26 },
			},
			hud = true,
			glow = true,
			crt = true,
		},
		-- 5. Couch pitch: the round-winning kill (lock at step 480), then the
		-- score card with every AI's label (card from step 660).
		{
			name = "couch_kill",
			seed = 140,
			roster = bots(6),
			from = 340,
			to = 520,
			camera = { x = 55, y = 90, zoom = 2.0 },
			hud = true,
			glow = true,
			crt = true,
		},
		{
			name = "couch_card",
			seed = 140,
			roster = bots(6),
			from = 650,
			to = 890,
			camera = { x = 55, y = 90, zoom = 2.0 },
			hud = true,
			fadeOut = 0.5,
			captions = {
				{ text = "HUMANS OR AI / 1-6 LOCAL", from = 0.9, to = 4, anchor = "bottom" },
			},
			glow = true,
			crt = true,
		},
	},
	-- The trailer's length in seconds: must match the sequence (within a frame).
	-- The music bed is read in place from `path`; `volume` (0 < v, under the
	-- effects) and `fadeOut` (seconds, 0 or more, ends it at length) are optional.
	length = 66,
	music = { path = "res/msc/synthwave_the_mountain.mp3", volume = 0.3, fadeOut = 1 },
	-- Play order: shot names, or cards (`card` text or "logo", `seconds`, and
	-- for the logo an optional `sub` line). Cuts are hard unless a shot or card
	-- sets fadeIn/fadeOut; cards fade 0.5 s by default.
	sequence = {
		"cold_open", -- 0-4
		"gravity_launch", -- 4-10
		"gravity_orbit", -- 10-17
		"arsenal_asteroids", -- 17-21.5
		"arsenal_tanks", -- 21.5-27.5
		"arsenal_airburst", -- 27.5-32
		"arsenal_detonate", -- 32-35
		"chaos_blob", -- 35-40
		"chaos_snake", -- 40-45
		"chaos_blob_2", -- 45-50
		"couch_kill", -- 50-53
		"couch_card", -- 53-57
		{ card = "logo", seconds = 9, sub = "WISHLIST ON STEAM", fadeIn = 0.5, fadeOut = 1 }, -- 57-66
	},
}
