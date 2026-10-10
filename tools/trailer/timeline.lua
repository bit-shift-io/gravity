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

-- Seconds two neighbouring shots overlap at a cut unless the outgoing shot's
-- `warp` says otherwise (0 is a hard cut).
Timeline.WARP = 0.4

-- Frames each shot plays beyond its range at a cut: half the overlap, so the
-- window is centred on the cut. Whole frames, so the overlap is always even.
local function warpHalf(shot)
	local warp = shot.warp
	if warp == nil then
		warp = Timeline.WARP
	end
	return math.floor(warp * FPS / 2 + 0.5)
end

-- Returns { items = { { kind, shot | card, start, frames, pre, post } }, frames,
-- overlaps } with `start` the item's first frame, counted from 0, and `frames`
-- the total. A shot followed by a shot overlaps it: the outgoing item plays
-- `post` extra frames past its last and the incoming one `pre` extra before its
-- first (half the overlap each, so cut times and `frames` do not change). The
-- overlap is { out, into, start, frames } (item indexes, the first frame of the
-- window counted from 0, its length), also kept on the outgoing item as
-- `overlap`. A card on either side of a cut gets none.
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
		item.pre, item.post = 0, 0
		table.insert(items, item)
		start = start + item.frames
	end
	local overlaps = {}
	for index = 1, #items - 1 do
		local out, into = items[index], items[index + 1]
		local half = out.kind == "shot" and into.kind == "shot" and warpHalf(out.shot) or 0
		if half > 0 then
			local overlap = { out = index, into = index + 1, start = into.start - half, frames = 2 * half }
			out.post, into.pre, out.overlap = half, half, overlap
			table.insert(overlaps, overlap)
		end
	end
	return { items = items, frames = start, overlaps = overlaps }
end

-- Weight of the incoming shot in frame `w` (from 1) of `overlap`: 0 on the
-- first frame, 1 on the last.
function Timeline.blend(overlap, w)
	return (w - 1) / (overlap.frames - 1)
end

-- Total length in seconds.
function Timeline.duration(timeline)
	return timeline.frames / FPS
end

-- How visible frame `k` (from 1) of `item` is: 0 is black, 1 is untouched.
-- `fadeIn` / `fadeOut` (seconds, on the shot) ramp from black on the first
-- frame and to black on the last, over the item's own frames. A side that
-- overlaps its neighbour (`pre` / `post` above 0) has no fade: the warp
-- replaces it.
function Timeline.alpha(item, k)
	local shot = item.shot or item
	local alpha = 1
	if shot.fadeIn and shot.fadeIn > 0 and (item.pre or 0) == 0 then
		alpha = math.min(alpha, (k - 1) / (shot.fadeIn * FPS))
	end
	if shot.fadeOut and shot.fadeOut > 0 and (item.post or 0) == 0 then
		alpha = math.min(alpha, (item.frames - k) / (shot.fadeOut * FPS))
	end
	return alpha
end

-- Seconds a caption takes to fade in, and again to fade out.
Timeline.CAPTION_FADE = 0.4
Timeline.CAPTION_SLIDE = 100
Timeline.CAPTION_REF_WIDTH = 1920

-- Progress 0..1 of a CAPTION_FADE ramp that has run for `elapsed` seconds,
-- smoothstep-eased so it starts and ends at rest.
local function ramp(elapsed)
	local u = math.max(0, math.min(1, elapsed / Timeline.CAPTION_FADE))
	return u * u * (3 - 2 * u)
end

-- How visible `caption` ({ from, to } in seconds into its shot) is at `t`
-- seconds into the shot: 0 outside from..to, easing up over CAPTION_FADE
-- after `from` and down over CAPTION_FADE before `to`.
function Timeline.captionAlpha(caption, t)
	if t <= caption.from or t >= caption.to then
		return 0
	end
	return math.min(ramp(t - caption.from), ramp(caption.to - t))
end

-- How far `caption` sits from its anchor at `t`, in pixels of a
-- CAPTION_REF_WIDTH-wide frame (scale for other widths): positive is right of
-- place (sliding in from the right), negative left (sliding out to the left),
-- 0 in the hold. The in and out slides are summed, so a caption shorter than
-- two ramps still moves continuously.
function Timeline.captionOffset(caption, t)
	return Timeline.CAPTION_SLIDE * ((1 - ramp(t - caption.from)) - (1 - ramp(caption.to - t)))
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
