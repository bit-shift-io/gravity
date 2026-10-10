-- Loads the game's match sounds for the trailer mix: the files named by
-- Audio.FILES (src/app/audio.lua), decoded with love.sound.newSoundData and
-- converted to interleaved stereo floats at the mix rate (linear resampling;
-- mono is copied to both channels). Dev-only; uses `love.*`.
local Audio = require("src.app.audio")

local Sounds = {}

Sounds.RATE = 48000
Sounds.NAMES = { "fire", "blast", "asteroidDeath", "thruster" }

local function convert(data, rate)
	local srcRate = data:getSampleRate()
	local channels = data:getChannelCount()
	local srcFrames = data:getSampleCount()
	local frames = math.floor(srcFrames * rate / srcRate)
	local out = {}
	local function at(i, channel)
		if i >= srcFrames then
			i = srcFrames - 1
		end
		return data:getSample(i, channel)
	end
	for f = 0, frames - 1 do
		local pos = f * srcRate / rate
		local i = math.floor(pos)
		local t = pos - i
		local left = at(i, 1) * (1 - t) + at(i + 1, 1) * t
		local right = left
		if channels >= 2 then
			right = at(i, 2) * (1 - t) + at(i + 1, 2) * t
		end
		out[f * 2 + 1] = left
		out[f * 2 + 2] = right
	end
	return out
end

-- name -> interleaved stereo floats at Sounds.RATE, for each of Sounds.NAMES.
function Sounds.load()
	local sounds = {}
	for _, name in ipairs(Sounds.NAMES) do
		sounds[name] = convert(love.sound.newSoundData(Audio.FILES[name]), Sounds.RATE)
	end
	return sounds
end

return Sounds
