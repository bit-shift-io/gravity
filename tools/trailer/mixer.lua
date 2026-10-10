-- Mixes a shot's sound cues (tools/trailer/cues.lua) into one stereo track
-- and writes it as WAV bytes (no `love.*`). Sounds arrive already at the mix
-- rate and stereo (tools/trailer/sounds.lua resamples and upmixes), as
-- interleaved L, R float arrays in -1..1.
local Mixer = {}

local unpack = unpack or table.unpack

-- Adds `sound` * gain into `out` from frame `at` (0-based) for `count` frames,
-- looping the sound when `loop` is set.
local function add(out, sound, gain, at, count, totalFrames, loop)
	local soundFrames = #sound / 2
	if soundFrames == 0 then
		return
	end
	if not loop then
		count = math.min(count, soundFrames)
	end
	count = math.min(count, totalFrames - at)
	for i = 0, count - 1 do
		local src = (i % soundFrames) * 2
		local dst = (at + i) * 2
		out[dst + 1] = out[dst + 1] + sound[src + 1] * gain
		out[dst + 2] = out[dst + 2] + sound[src + 2] * gain
	end
end

-- job = { rate, duration (s), cues = {{time, kind}}, thrust = {{start, stop}},
-- sounds = { name -> interleaved stereo }, volume = { name -> gain } }.
-- Returns interleaved stereo floats, clipped to -1..1, duration * rate frames.
function Mixer.mix(job)
	local rate = job.rate
	local totalFrames = math.floor(job.duration * rate + 0.5)
	local out = {}
	for i = 1, totalFrames * 2 do
		out[i] = 0
	end
	local function frameAt(seconds)
		return math.floor(seconds * rate + 0.5)
	end

	for _, cue in ipairs(job.cues) do
		local sound = job.sounds[cue.kind]
		if sound then
			add(out, sound, job.volume[cue.kind] or 1, frameAt(cue.time), math.huge, totalFrames, false)
		end
	end
	local thruster = job.sounds.thruster
	if thruster then
		for _, span in ipairs(job.thrust) do
			local first = frameAt(span.start)
			-- Each span restarts the loop from the top, as the game's source:play() does.
			add(out, thruster, job.volume.thruster or 1, first, frameAt(span.stop) - first, totalFrames, true)
		end
	end

	for i = 1, #out do
		local v = out[i]
		if v > 1 then
			out[i] = 1
		elseif v < -1 then
			out[i] = -1
		end
	end
	return out
end

local function le(value, bytes)
	local chars = {}
	for i = 1, bytes do
		chars[i] = string.char(value % 256)
		value = math.floor(value / 256)
	end
	return table.concat(chars)
end

-- A 16-bit PCM stereo WAV file (44-byte RIFF header) of interleaved samples.
function Mixer.wav(samples, rate)
	local dataSize = #samples * 2
	local parts = {
		"RIFF", le(36 + dataSize, 4), "WAVE",
		"fmt ", le(16, 4), le(1, 2), le(2, 2), le(rate, 4), le(rate * 4, 4), le(4, 2), le(16, 2),
		"data", le(dataSize, 4),
	}
	-- string.char in chunks: one call per sample would be slow for minutes of audio.
	local chunk = {}
	local CHUNK = 4096
	for i = 1, #samples do
		local v = math.floor(samples[i] * 32767 + 0.5)
		if v < 0 then
			v = v + 65536
		end
		chunk[#chunk + 1] = v % 256
		chunk[#chunk + 1] = math.floor(v / 256)
		if #chunk >= CHUNK then
			parts[#parts + 1] = string.char(unpack(chunk))
			chunk = {}
		end
	end
	if #chunk > 0 then
		parts[#parts + 1] = string.char(unpack(chunk))
	end
	return table.concat(parts)
end

return Mixer
