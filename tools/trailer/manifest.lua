-- Trailer manifest (docs/CONTEXT.md "Trailer manifest"): the shots that make up
-- the Steam trailer, and the `sequence` they play in. Dev-only; the game never
-- reads it. Validated by manifest_check.lua before anything renders. glow/crt
-- are set on every shot so output does not depend on the saved in-game look.
--
-- First draft, 61 s, six beats (see docs/TRAILER.md "The draft trailer"):
--   0-4   cold open    4-17  gravity    17-32 arsenal
--   32-47 chaos        47-54 couch      54-61 end card
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
		-- 1. Cold open: a multi-kill at step 395 (frame 193, about 3.2 s), with
		-- 0.8 s of aftermath. Scouted with `trailer=scout seed=174`, so it uses
		-- the scout's default roster (two hard, two easy).
		{
			name = "cold_open",
			seed = 174,
			roster = {
				{ color = 1, binding = { kind = "ai", level = "hard" } },
				{ color = 2, binding = { kind = "ai", level = "hard" } },
				{ color = 3, binding = { kind = "ai", level = "easy" } },
				{ color = 4, binding = { kind = "ai", level = "easy" } },
			},
			from = 202,
			to = 442,
			camera = {
				{ t = 0, x = -20, y = -130, zoom = 1.3 },
				{ t = 1, x = -60, y = -150, zoom = 1.7 },
			},
			hud = true,
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
			hud = true,
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
			hud = true,
			captions = {
				{ text = "GRAVITY IS THE WEAPON", from = 0.8, to = 6.4, anchor = "bottom" },
			},
			glow = true,
			crt = true,
		},
		-- The gravity beat in one take: the purple ship (slot 6) slings round
		-- the first planet from about step 288 and lands on another at step 926.
		-- Scouted with `trailer=scout shot=gravity_launch seed=5674`; the camera
		-- follows the ship. gravity_launch and gravity_orbit are spares.
		{
			name = "gravity_flight",
			seed = 5674,
			roster = bots(6),
			from = 206,
			to = 986,
			camera = {
				{ t = 0, x = 480, y = 20, zoom = 1.8, ease = "in" },
				{ t = 0.12, x = 360, y = 10, zoom = 1.8, ease = "linear" },
				{ t = 0.31, x = 180, y = 60, zoom = 1.8, ease = "linear" },
				{ t = 0.5, x = 180, y = -10, zoom = 1.8, ease = "linear" },
				{ t = 0.66, x = 150, y = 150, zoom = 1.8, ease = "linear" },
				{ t = 0.81, x = 10, y = 195, zoom = 1.9 },
				{ t = 1, x = -30, y = 185, zoom = 2.1 },
			},
			hud = true,
			captions = {
				{ text = "GRAVITY IS THE WEAPON", from = 1.5, to = 6, anchor = "bottom" },
			},
			glow = true,
			crt = true,
		},
		-- 3. Arsenal: an asteroid split, ships landing as tanks, tank airbursts.
		{
			name = "arsenal_asteroids",
			-- Scouted with `trailer=scout shot=arsenal_asteroids seed=3333`: an
			-- asteroid comes in (step 782), breaks on the first planet (920) and
			-- its fragments hit the second planet near the players (about 1108).
			seed = 3333,
			roster = bots(6),
			from = 760,
			to = 1150,
			camera = {
				{ t = 0, x = 450, y = 30, zoom = 1.2, ease = "out" },
				{ t = 0.41, x = 200, y = 70, zoom = 1.2, ease = "linear" },
				{ t = 0.67, x = -60, y = 100, zoom = 1.2 },
				{ t = 1, x = -260, y = 180, zoom = 1.35 },
			},
			hud = true,
			glow = true,
			crt = true,
		},
		{
			name = "arsenal_tanks",
			-- Scouted with `trailer=scout shot=arsenal_asteroids seed=7812`: the
			-- round starts at step 2830; the pink tank kills purple (about 2880),
			-- then two more ships die by 3017.
			seed = 7812,
			roster = bots(6),
			from = 2830,
			to = 3070,
			camera = {
				{ t = 0, x = -380, y = -140, zoom = 1.5 },
				{ t = 1, x = -380, y = -140, zoom = 1.7 },
			},
			hud = true,
			glow = true,
			crt = true,
		},
		{
			name = "arsenal_airburst",
			-- Scouted with `trailer=scout shot=arsenal_tanks seed=2345`: orange
			-- kills blue with an airburst (on screen about step 3535).
			seed = 2345,
			roster = bots(3),
			from = 3325,
			to = 3595,
			camera = {
				{ t = 0, x = -40, y = -80, zoom = 1.4 },
				{ t = 1, x = 40, y = -50, zoom = 1.6 },
			},
			hud = true,
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
			hud = true,
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
	-- effects), `fadeOut` (seconds, 0 or more, ends it at length) and `start`
	-- (seconds of the track to skip) are optional. The track's first 5 s are a
	-- near-silent intro, so it starts 5 s in and still ends on the 1:06 phrase.
	length = 61,
	music = { path = "res/msc/synthwave_the_mountain.mp3", volume = 0.8, fadeOut = 1, start = 5 },
	-- Play order: shot names, or cards (`card` text or "logo", `seconds`, and
	-- for the logo an optional `sub` line). Cuts are hard unless a shot or card
	-- sets fadeIn/fadeOut; cards fade 0.5 s by default.
	sequence = {
		"cold_open", -- 0-4
		"gravity_flight", -- 4-17
		"arsenal_asteroids", -- 17-23.5
		"arsenal_tanks", -- 23.5-27.5
		"arsenal_airburst", -- 27.5-32
		"chaos_blob", -- 32-37
		"chaos_snake", -- 37-42
		"chaos_blob_2", -- 42-47
		"couch_kill", -- 47-50
		"couch_card", -- 50-54
		{ card = "logo", seconds = 7, sub = "WISHLIST ON STEAM", fadeIn = 0.5, fadeOut = 1 }, -- 54-61
	},
}
