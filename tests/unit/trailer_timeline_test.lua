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
