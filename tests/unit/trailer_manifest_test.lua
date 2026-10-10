local ManifestCheck = require("tools.trailer.manifest_check")
local Manifest = require("tools.trailer.manifest")

test("Trailer ManifestCheck accepts the example manifest", function()
	local ok, err = ManifestCheck.validate(Manifest)
	assertTrue(ok, tostring(err))
end)

local function shot(overrides)
	local s = {
		name = "duel_opening",
		seed = 4242,
		roster = {
			{ color = 1, binding = { kind = "ai", level = "hard" } },
			{ color = 2, binding = { kind = "ai", level = "hard" } },
		},
		from = 0,
		to = 240,
	}
	for k, v in pairs(overrides or {}) do
		s[k] = v
	end
	return s
end

test("Trailer ManifestCheck rejects a duplicate shot name", function()
	local ok, err = ManifestCheck.validate({ shots = { shot(), shot() } })
	assertFalse(ok)
	assertEqual("duel_opening: duplicate name", err)
end)

test("Trailer ManifestCheck rejects a shot whose to is not after from", function()
	local ok, err = ManifestCheck.validate({ shots = { shot({ name = "flat", from = 240, to = 240 }) } })
	assertFalse(ok)
	assertEqual("flat: to must be greater than from", err)
end)

test("Trailer ManifestCheck rejects a roster with fewer than two slots", function()
	local solo = { { color = 1, binding = { kind = "ai", level = "hard" } } }
	local ok, err = ManifestCheck.validate({ shots = { shot({ name = "solo", roster = solo }) } })
	assertFalse(ok)
	assertEqual("solo: roster needs 2-6 slots", err)
end)

test("Trailer ManifestCheck rejects a speed that is not a positive whole number", function()
	local ok, err = ManifestCheck.validate({ shots = { shot({ name = "fast", speed = 1.5 }) } })
	assertFalse(ok)
	assertEqual("fast: speed must be a positive integer", err)
end)

test("Trailer ManifestCheck rejects a speed that does not divide the range", function()
	local ok, err = ManifestCheck.validate({ shots = { shot({ name = "uneven", from = 0, to = 100, speed = 3 }) } })
	assertFalse(ok)
	assertEqual("uneven: to - from must be a multiple of speed", err)
end)

test("Trailer ManifestCheck names the shot that is missing a field", function()
	local ok, err = ManifestCheck.validate({ shots = { shot(), shot({ name = "nameless_seed", seed = false }) } })
	assertFalse(ok)
	assertEqual("nameless_seed: missing field 'seed'", err)
end)

test("Trailer ManifestCheck rejects a camera without a positive zoom", function()
	local ok, err = ManifestCheck.validate({ shots = { shot({ name = "cam", camera = { x = 0, y = 0, zoom = 0 } }) } })
	assertFalse(ok)
	assertEqual("cam: camera needs numeric x, y and a positive zoom", err)
end)

test("Trailer ManifestCheck rejects a non-boolean flag", function()
	local ok, err = ManifestCheck.validate({ shots = { shot({ name = "flag", crt = "yes" }) } })
	assertFalse(ok)
	assertEqual("flag: crt must be true or false", err)
end)

test("Trailer ManifestCheck rejects a roster slot without a known AI level", function()
	local roster = {
		{ color = 1, binding = { kind = "ai", level = "hard" } },
		{ color = 2, binding = { kind = "ai", level = "expert" } },
	}
	local ok, err = ManifestCheck.validate({ shots = { shot({ name = "odd_ai", roster = roster }) } })
	assertFalse(ok)
	assertEqual("odd_ai: roster slot 2 needs an AI binding with level easy or hard", err)
end)

test("Trailer ManifestCheck rejects a sequence naming an unknown shot", function()
	local ok, err = ManifestCheck.validate({ shots = { shot() }, sequence = { "duel_opening", "missing_shot" } })
	assertFalse(ok)
	assertEqual("sequence item 2: no shot named 'missing_shot'", err)
end)

test("Trailer ManifestCheck rejects a negative fade", function()
	local ok, err = ManifestCheck.validate({ shots = { shot({ name = "dim", fadeOut = -1 }) } })
	assertFalse(ok)
	assertEqual("dim: fadeOut must be a number of seconds, 0 or more", err)
end)

test("Trailer ManifestCheck rejects fades longer than the shot", function()
	local ok, err = ManifestCheck.validate({ shots = { shot({ name = "long_fade", fadeIn = 3, fadeOut = 2 }) } })
	assertFalse(ok)
	assertEqual("long_fade: fadeIn + fadeOut (5s) is longer than the shot (4s)", err)
end)

local ShotRunner = require("tools.trailer.shot_runner")

test("ShotRunner yields one frame per speed steps from just after from up to to", function()
	local steps = {}
	ShotRunner.run(shot({ from = 6, to = 12, speed = 2 }), function(_, step)
		steps[#steps + 1] = step
	end)
	assertEqual("8,10,12", table.concat(steps, ","))
end)

test("ShotRunner replays the match from step 0, one Match.step per step up to to", function()
	local Match = require("src.game.match")
	local realStep = Match.step
	local calls = 0
	Match.step = function(ctx)
		calls = calls + 1
		return realStep(ctx)
	end
	local ok, err = pcall(ShotRunner.run, shot({ from = 30, to = 90, speed = 3 }), function() end)
	Match.step = realStep
	assertTrue(ok, tostring(err))
	assertEqual(90, calls)
end)

test("ShotRunner frames every frame with the shot's fixed camera", function()
	local fixed = { x = 120, y = -40, zoom = 0.6 }
	local seen
	ShotRunner.run(shot({ from = 0, to = 2, camera = fixed }), function(view)
		seen = { zoom = view.camera.zoom, x = view.camera.x }
	end)
	assertEqual(0.6, seen.zoom)
	assertEqual(120, seen.x)
end)

test("Trailer ManifestCheck rejects a caption that ends after the shot", function()
	local captions = { { text = "FLY", from = 1, to = 4.5 } }
	local ok, err = ManifestCheck.validate({ shots = { shot({ captions = captions }) } })
	assertFalse(ok)
	assertEqual("duel_opening: caption 1 must lie within the shot (0 to 4s)", err)
end)

test("Trailer ManifestCheck rejects a caption with an unknown anchor", function()
	local captions = { { text = "FLY", from = 1, to = 2, anchor = "middle" } }
	local ok, err = ManifestCheck.validate({ shots = { shot({ captions = captions }) } })
	assertFalse(ok)
	assertEqual("duel_opening: caption 1 anchor must be top, center, bottom or lowerLeft", err)
end)

test("Trailer ManifestCheck rejects a caption with empty text", function()
	local captions = { { text = "", from = 1, to = 2 } }
	local ok, err = ManifestCheck.validate({ shots = { shot({ captions = captions }) } })
	assertFalse(ok)
	assertEqual("duel_opening: caption 1 needs text", err)
end)

test("Trailer ManifestCheck rejects a card with empty text", function()
	local ok, err = ManifestCheck.validate({ shots = { shot() }, sequence = { { card = "", seconds = 2 } } })
	assertFalse(ok)
	assertEqual("sequence item 1: card needs text", err)
end)

test("Trailer ManifestCheck rejects a card with no length", function()
	local ok, err = ManifestCheck.validate({ shots = { shot() }, sequence = { { card = "logo" } } })
	assertFalse(ok)
	assertEqual("sequence item 1: card seconds must be greater than 0", err)
end)

test("Trailer ManifestCheck accepts cards and captioned shots", function()
	local captions = { { text = "FLY", from = 1, to = 2, anchor = "top" } }
	local ok, err = ManifestCheck.validate({
		shots = { shot({ captions = captions }) },
		sequence = { { card = "ONE MATCH", seconds = 2 }, "duel_opening", { card = "logo", seconds = 4, sub = "WISHLIST ON STEAM" } },
	})
	assertTrue(ok, tostring(err))
end)

-- One 4 s shot as the whole sequence, with a music bed of `music` over it.
local function withMusic(music, length)
	return { shots = { shot() }, sequence = { "duel_opening" }, length = length or 4, music = music }
end

test("Trailer ManifestCheck accepts a manifest with no music", function()
	local ok, err = ManifestCheck.validate(withMusic(nil))
	assertTrue(ok, tostring(err))
end)

test("Trailer ManifestCheck rejects a music volume of 0 or less", function()
	local path = "res/msc/synthwave_the_mountain.mp3"
	local ok, err = ManifestCheck.validate(withMusic({ path = path, volume = 0 }))
	assertFalse(ok)
	assertEqual("music volume must be greater than 0", err)
	ok, err = ManifestCheck.validate(withMusic({ path = path, volume = -0.5 }))
	assertFalse(ok)
	assertEqual("music volume must be greater than 0", err)
end)

test("Trailer ManifestCheck rejects a negative music fadeOut", function()
	local path = "res/msc/synthwave_the_mountain.mp3"
	local ok, err = ManifestCheck.validate(withMusic({ path = path, fadeOut = -1 }))
	assertFalse(ok)
	assertEqual("music fadeOut must be a number of seconds, 0 or more", err)
end)

test("Trailer ManifestCheck rejects a music fadeOut longer than length", function()
	local path = "res/msc/synthwave_the_mountain.mp3"
	local ok, err = ManifestCheck.validate(withMusic({ path = path, fadeOut = 5 }, 4))
	assertFalse(ok)
	assertEqual("music fadeOut (5s) is longer than length (4s)", err)
end)

test("Trailer ManifestCheck rejects a length that differs from the sequence by more than a frame", function()
	local ok, err = ManifestCheck.validate(withMusic(nil, 13))
	assertFalse(ok)
	assertEqual("length is 13s but the sequence runs 4s", err)
end)

test("Trailer ManifestCheck accepts a length within one frame of the sequence", function()
	local ok, err = ManifestCheck.validate(withMusic(nil, 4 + 1 / 120))
	assertTrue(ok, tostring(err))
end)

test("Trailer ManifestCheck requires length when there is music", function()
	local ok, err = ManifestCheck.validate({ shots = { shot() }, sequence = { "duel_opening" },
		music = { path = "res/msc/synthwave_the_mountain.mp3" } })
	assertFalse(ok)
	assertEqual("music needs length (the trailer's length in seconds)", err)
end)

test("Trailer music fades out over 1 s by default, so the cut at length does not click", function()
	assertEqual(1, ManifestCheck.MUSIC_DEFAULTS.fadeOut)
end)
