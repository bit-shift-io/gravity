local Mixer = require("tools.trailer.mixer")

-- A stereo sound (interleaved L, R) of `frames` frames, every sample `value`.
local function constant(frames, value)
	local data = {}
	for i = 1, frames * 2 do
		data[i] = value
	end
	return data
end

local function mix(overrides)
	local job = {
		rate = 100,
		duration = 1,
		cues = {},
		thrust = {},
		sounds = { fire = constant(10, 0.5), thruster = constant(4, 0.5) },
		volume = { fire = 1, thruster = 1 },
	}
	for k, v in pairs(overrides) do
		job[k] = v
	end
	return Mixer.mix(job)
end

test("Trailer Mixer gives duration * rate stereo frames", function()
	local out = mix({})
	assertEqual(200, #out)
end)

test("Trailer Mixer places a cue at its sample offset", function()
	local out = mix({ cues = { { time = 0.25, kind = "fire" } } })
	-- Frame 25 (0-based) is the first one with sound; both channels.
	assertEqual(0, out[2 * 24 + 1])
	assertNear(0.5, out[2 * 25 + 1])
	assertNear(0.5, out[2 * 25 + 2])
	assertNear(0.5, out[2 * 34 + 1])
	assertEqual(0, out[2 * 35 + 1])
end)

test("Trailer Mixer scales a cue by its volume", function()
	local out = mix({ cues = { { time = 0, kind = "fire" } }, volume = { fire = 0.5 } })
	assertNear(0.25, out[1])
end)

test("Trailer Mixer clips overlapping cues at +-1", function()
	local loud = { fire = constant(10, 0.8) }
	local cues = { { time = 0, kind = "fire" }, { time = 0, kind = "fire" } }
	assertEqual(1, mix({ sounds = loud, cues = cues })[1])
	local quiet = { fire = constant(10, -0.8) }
	assertEqual(-1, mix({ sounds = quiet, cues = cues })[1])
end)

test("Trailer Mixer cuts a cue off at the end of the clip", function()
	local out = mix({ cues = { { time = 0.95, kind = "fire" } } })
	assertEqual(200, #out)
end)

test("Trailer Mixer loops the thruster only over thrust spans", function()
	local out = mix({ thrust = { { start = 0.1, stop = 0.2 } } })
	assertEqual(0, out[2 * 9 + 1])
	for frame = 10, 19 do
		assertNear(0.5, out[2 * frame + 1], 1e-9, "frame " .. frame)
	end
	assertEqual(0, out[2 * 20 + 1])
end)

local function u32(bytes, at)
	local a, b, c, d = bytes:byte(at, at + 3)
	return a + b * 256 + c * 65536 + d * 16777216
end

local function u16(bytes, at)
	local a, b = bytes:byte(at, at + 1)
	return a + b * 256
end

test("Trailer Mixer writes a 44-byte RIFF header for 16-bit stereo", function()
	local bytes = Mixer.wav({ 0, 0, 0, 0 }, 48000)
	assertEqual("RIFF", bytes:sub(1, 4))
	assertEqual(#bytes - 8, u32(bytes, 5))
	assertEqual("WAVEfmt ", bytes:sub(9, 16))
	assertEqual(16, u32(bytes, 17))
	assertEqual(1, u16(bytes, 21)) -- PCM
	assertEqual(2, u16(bytes, 23)) -- channels
	assertEqual(48000, u32(bytes, 25))
	assertEqual(48000 * 4, u32(bytes, 29)) -- byte rate
	assertEqual(4, u16(bytes, 33)) -- block align
	assertEqual(16, u16(bytes, 35))
	assertEqual("data", bytes:sub(37, 40))
	assertEqual(8, u32(bytes, 41))
	assertEqual(52, #bytes)
end)

test("Trailer Mixer writes samples as little-endian signed 16-bit", function()
	local bytes = Mixer.wav({ 1, -1 }, 48000)
	assertEqual(32767, u16(bytes, 45))
	assertEqual(65536 - 32767, u16(bytes, 47))
end)
