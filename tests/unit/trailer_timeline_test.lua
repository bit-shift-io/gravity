local Timeline = require("tools.trailer.timeline")

local function shot(name, from, to, extra)
	local s = { name = name, seed = 1, from = from, to = to }
	for k, v in pairs(extra or {}) do
		s[k] = v
	end
	return s
end

-- Two shots like the example manifest: 240 frames, then 360 steps at speed 2.
local manifest = {
	shots = {
		shot("duel_opening", 0, 240),
		shot("six_way_brawl", 240, 600, { speed = 2 }),
	},
	sequence = { "six_way_brawl", "duel_opening" },
}

test("Trailer Timeline starts each item where the previous one ends", function()
	local timeline = Timeline.build(manifest)
	assertEqual("six_way_brawl", timeline.items[1].shot.name)
	assertEqual(0, timeline.items[1].start)
	assertEqual("duel_opening", timeline.items[2].shot.name)
	assertEqual(180, timeline.items[2].start)
end)

test("Trailer Timeline total length is the sum of its items", function()
	local timeline = Timeline.build(manifest)
	assertEqual(420, timeline.frames)
	assertNear(7, Timeline.duration(timeline), 1e-9)
end)

-- A 4-second shot (240 frames) fading in and out over half a second each.
local function fadedItem()
	local faded = {
		shots = { shot("duel_opening", 0, 240, { fadeIn = 0.5, fadeOut = 0.5 }) },
		sequence = { "duel_opening" },
	}
	return Timeline.build(faded).items[1]
end

test("Trailer Timeline fade is black on the first frame of a fade-in", function()
	assertEqual(0, Timeline.alpha(fadedItem(), 1))
end)

test("Trailer Timeline fade is black on the last frame of a fade-out", function()
	assertEqual(0, Timeline.alpha(fadedItem(), 240))
end)

test("Trailer Timeline fade leaves mid-shot frames untouched", function()
	assertEqual(1, Timeline.alpha(fadedItem(), 120))
end)

test("Trailer Timeline fade is halfway through black at the fade's midpoint", function()
	assertNear(0.5, Timeline.alpha(fadedItem(), 16), 1e-9)
end)

test("Trailer Timeline never fades a shot without fadeIn or fadeOut", function()
	local item = Timeline.build(manifest).items[2]
	assertEqual(1, Timeline.alpha(item, 1))
	assertEqual(1, Timeline.alpha(item, item.frames))
end)

test("Trailer Timeline offsets each item's sound cues by its start time", function()
	local timeline = Timeline.build(manifest)
	local sound = Timeline.sound(timeline, {
		{ cues = { { time = 0.5, kind = "fire" } }, thrust = { { start = 1, stop = 2 } }, duration = 3 },
		{ cues = { { time = 0, kind = "blast" } }, thrust = { { start = 0, stop = 4 } }, duration = 4 },
	})
	assertEqual(2, #sound.cues)
	assertNear(0.5, sound.cues[1].time, 1e-9)
	assertEqual("blast", sound.cues[2].kind)
	assertNear(3, sound.cues[2].time, 1e-9)
	assertNear(3, sound.thrust[2].start, 1e-9)
	assertNear(7, sound.thrust[2].stop, 1e-9)
	assertNear(7, sound.duration, 1e-9)
end)

local caption = { text = "FLY", from = 1, to = 3, anchor = "bottom" }

test("Trailer Timeline caption ramps in over the fade time", function()
	assertEqual(0, Timeline.captionAlpha(caption, 1))
	assertNear(0.5, Timeline.captionAlpha(caption, 1 + Timeline.CAPTION_FADE / 2), 1e-9)
	assertEqual(1, Timeline.captionAlpha(caption, 2))
end)

test("Trailer Timeline caption ramps out before its end", function()
	assertNear(0.5, Timeline.captionAlpha(caption, 3 - Timeline.CAPTION_FADE / 2), 1e-9)
	assertEqual(0, Timeline.captionAlpha(caption, 3))
end)

test("Trailer Timeline caption is invisible outside from..to", function()
	assertEqual(0, Timeline.captionAlpha(caption, 0.5))
	assertEqual(0, Timeline.captionAlpha(caption, 4))
end)

test("Trailer Timeline caption starts right of place, rests at 0, leaves to the left", function()
	local ramp = Timeline.CAPTION_FADE
	assert(Timeline.captionOffset(caption, 1) > 0)
	assertNear(Timeline.CAPTION_SLIDE, Timeline.captionOffset(caption, 1), 1e-9)
	assertEqual(0, Timeline.captionOffset(caption, 1 + ramp))
	assertEqual(0, Timeline.captionOffset(caption, 2))
	assertEqual(0, Timeline.captionOffset(caption, 3 - ramp))
	assert(Timeline.captionOffset(caption, 3) < 0)
	assertNear(-Timeline.CAPTION_SLIDE, Timeline.captionOffset(caption, 3), 1e-9)
end)

test("Trailer Timeline caption offset eases into and out of its hold", function()
	local ramp, dt = Timeline.CAPTION_FADE, 1e-4
	local inSpeed = math.abs(Timeline.captionOffset(caption, 1 + ramp - dt) - Timeline.captionOffset(caption, 1 + ramp)) / dt
	local outSpeed = math.abs(Timeline.captionOffset(caption, 3 - ramp + dt) - Timeline.captionOffset(caption, 3 - ramp)) / dt
	assert(inSpeed < 0.01 * Timeline.CAPTION_SLIDE / ramp)
	assert(outSpeed < 0.01 * Timeline.CAPTION_SLIDE / ramp)
end)

test("Trailer Timeline caption shorter than two ramps moves without a jump", function()
	local short = { text = "HI", from = 1, to = 1.5 }
	local previous = Timeline.captionOffset(short, 1)
	for step = 1, 500 do
		local offset = Timeline.captionOffset(short, 1 + step * 0.001)
		assert(math.abs(offset - previous) < 0.1 * Timeline.CAPTION_SLIDE)
		previous = offset
	end
end)

local cardManifest = {
	shots = { shot("duel_opening", 0, 240) },
	sequence = { { card = "ONE MATCH", seconds = 2 }, "duel_opening", { card = "logo", seconds = 4, sub = "WISHLIST ON STEAM" } },
}

test("Trailer Timeline lays a card into the sequence for its seconds", function()
	local timeline = Timeline.build(cardManifest)
	local card = timeline.items[1]
	assertEqual("card", card.kind)
	assertEqual("ONE MATCH", card.card)
	assertEqual(120, card.frames)
	assertEqual(120, timeline.items[2].start)
	assertEqual("WISHLIST ON STEAM", timeline.items[3].sub)
	assertEqual(360, timeline.items[3].start)
	assertEqual(600, timeline.frames)
end)

test("Trailer Timeline cards fade in and out by default and honour their own fades", function()
	local timeline = Timeline.build(cardManifest)
	local card = timeline.items[1]
	assertEqual(0, Timeline.alpha(card, 1))
	assertEqual(0, Timeline.alpha(card, card.frames))
	assertEqual(1, Timeline.alpha(card, 60))
	local hard = Timeline.build({ shots = cardManifest.shots, sequence = { { card = "X", seconds = 1, fadeIn = 0, fadeOut = 0 } } })
	assertEqual(1, Timeline.alpha(hard.items[1], 1))
end)

test("Trailer Timeline leaves cards out of the sound track", function()
	local timeline = Timeline.build(cardManifest)
	local sound = Timeline.sound(timeline, { nil, { cues = { { time = 0, kind = "fire" } }, thrust = {}, duration = 4 } })
	assertEqual(1, #sound.cues)
	assertNear(2, sound.cues[1].time, 1e-9)
	assertNear(10, sound.duration, 1e-9)
end)

-- Three 4 s shots back to back: two cuts.
local function threeShots(extra)
	return {
		shots = {
			shot("a", 100, 340, extra and extra.a),
			shot("b", 100, 340, extra and extra.b),
			shot("c", 100, 340),
		},
		sequence = { "a", "b", "c" },
	}
end

test("Trailer Timeline overlaps two shots for the default 0.4 s centred on their cut", function()
	local timeline = Timeline.build(threeShots())
	local overlap = timeline.items[1].overlap
	assertEqual(24, overlap.frames)
	assertEqual(240 - 12, overlap.start)
	assertEqual(12, timeline.items[1].post)
	assertEqual(12, timeline.items[2].pre)
	assertEqual(12, timeline.items[2].post)
	assertEqual(0, timeline.items[1].pre)
	assertEqual(0, timeline.items[3].post)
	assertEqual(2, #timeline.overlaps)
end)

test("Trailer Timeline overlaps leave the cut times and the total length alone", function()
	local timeline = Timeline.build(threeShots())
	assertEqual(240, timeline.items[2].start)
	assertEqual(480, timeline.items[3].start)
	assertEqual(720, timeline.frames)
end)

test("Trailer Timeline gives no overlap to a cut to or from a card", function()
	local timeline = Timeline.build(cardManifest)
	for _, item in ipairs(timeline.items) do
		assertEqual(0, item.pre)
		assertEqual(0, item.post)
	end
	assertEqual(0, #timeline.overlaps)
end)

test("Trailer Timeline warp = 0 is a hard cut and the warp sets the overlap length", function()
	local hard = Timeline.build(threeShots({ a = { warp = 0 } }))
	assertEqual(0, hard.items[1].post)
	assertEqual(0, hard.items[2].pre)
	assertEqual(1, #hard.overlaps)
	local long = Timeline.build(threeShots({ a = { warp = 1 } }))
	assertEqual(60, long.items[1].overlap.frames)
	assertEqual(30, long.items[2].pre)
end)

test("Trailer Timeline blend weight runs from 0 at the overlap start to 1 at its end", function()
	local overlap = Timeline.build(threeShots()).items[1].overlap
	assertEqual(0, Timeline.blend(overlap, 1))
	assertEqual(1, Timeline.blend(overlap, overlap.frames))
	assertNear(0.5, Timeline.blend(overlap, 1 + (overlap.frames - 1) / 2), 1e-9)
end)

test("Trailer Timeline lets a warp replace a fade on its side only", function()
	local timeline = Timeline.build(threeShots({ b = { fadeIn = 0.5, fadeOut = 0.5 } }))
	local item = timeline.items[2]
	assertEqual(1, Timeline.alpha(item, 1))
	assertEqual(1, Timeline.alpha(item, item.frames))
	local hard = Timeline.build(threeShots({ a = { warp = 0 }, b = { warp = 0, fadeIn = 0.5, fadeOut = 0.5 } }))
	assertEqual(0, Timeline.alpha(hard.items[2], 1))
	assertEqual(0, Timeline.alpha(hard.items[2], hard.items[2].frames))
end)
