-- The trailer timeline (no `love.*`): the manifest's `sequence` laid end to
-- end in video frames at 60 fps. Each sequence entry is a shot name, resolved
-- against `shots`. Every item is { kind, start, frames } plus its own data
-- (`shot` for kind "shot"), so other kinds of item can join the sequence.
local Timeline = {}

local FPS = 60
Timeline.FPS = FPS

local function shotFrames(shot)
	return (shot.to - shot.from) / (shot.speed or 1)
end

-- A card entry { card, seconds, sub?, fadeIn?, fadeOut? } as an item. Cards
-- fade in and out over CARD_FADE (at most half the card) unless they say so.
local CARD_FADE = 0.5

local function cardItem(entry, start)
	local default = math.min(CARD_FADE, entry.seconds / 2)
	local fadeIn, fadeOut = entry.fadeIn, entry.fadeOut
	if fadeIn == nil then
		fadeIn = default
	end
	if fadeOut == nil then
		fadeOut = default
	end
	return {
		kind = "card",
		card = entry.card,
		sub = entry.sub,
		fadeIn = fadeIn,
		fadeOut = fadeOut,
		start = start,
		frames = math.floor(entry.seconds * FPS + 0.5),
	}
end

-- Returns { items = { { kind, shot | card, start, frames } }, frames } with `start`
-- the item's first frame, counted from 0, and `frames` the total.
function Timeline.build(manifest)
	local byName = {}
	for _, shot in ipairs(manifest.shots) do
		byName[shot.name] = shot
	end
	local items, start = {}, 0
	for _, entry in ipairs(manifest.sequence) do
		local item
		if type(entry) == "table" then
			item = cardItem(entry, start)
		else
			item = { kind = "shot", shot = byName[entry], start = start, frames = shotFrames(byName[entry]) }
		end
		table.insert(items, item)
		start = start + item.frames
	end
	return { items = items, frames = start }
end

-- Total length in seconds.
function Timeline.duration(timeline)
	return timeline.frames / FPS
end

-- How visible frame `k` (from 1) of `item` is: 0 is black, 1 is untouched.
-- `fadeIn` / `fadeOut` (seconds, on the shot) ramp from black on the first
-- frame and to black on the last, over the item's own frames.
function Timeline.alpha(item, k)
	local shot = item.shot or item
	local alpha = 1
	if shot.fadeIn and shot.fadeIn > 0 then
		alpha = math.min(alpha, (k - 1) / (shot.fadeIn * FPS))
	end
	if shot.fadeOut and shot.fadeOut > 0 then
		alpha = math.min(alpha, (item.frames - k) / (shot.fadeOut * FPS))
	end
	return alpha
end

-- Seconds a caption takes to fade in, and again to fade out.
Timeline.CAPTION_FADE = 0.3

-- How visible `caption` ({ from, to } in seconds into its shot) is at `t`
-- seconds into the shot: 0 outside from..to, ramping up over CAPTION_FADE
-- after `from` and down over CAPTION_FADE before `to`.
function Timeline.captionAlpha(caption, t)
	if t <= caption.from or t >= caption.to then
		return 0
	end
	return math.min(1, (t - caption.from) / Timeline.CAPTION_FADE, (caption.to - t) / Timeline.CAPTION_FADE)
end

-- One sound-effects track for the whole timeline. `results[i]` is item i's
-- Cues:result() (times from that item's first frame); an item with no result
-- stays silent. Returns { cues, thrust, duration } in trailer seconds.
function Timeline.sound(timeline, results)
	local cues, thrust = {}, {}
	for index, item in ipairs(timeline.items) do
		local result = results[index]
		local offset = item.start / FPS
		for _, cue in ipairs(result and result.cues or {}) do
			table.insert(cues, { time = cue.time + offset, kind = cue.kind })
		end
		for _, span in ipairs(result and result.thrust or {}) do
			table.insert(thrust, { start = span.start + offset, stop = span.stop + offset })
		end
	end
	return { cues = cues, thrust = thrust, duration = Timeline.duration(timeline) }
end

return Timeline
