local Encoder = require("tools.trailer.encoder")

test("Trailer Encoder mixes music under the effects with a fade-out over the last seconds", function()
	local filter = Encoder.mixFilter(12, 0.3, 1)
	assertEqual("[1:a]aresample=48000[fx];[2:a]aresample=48000,atrim=0:12,afade=t=out:st=11:d=1,volume=0.3[mu];"
		.. "[fx][mu]amix=inputs=2:duration=first:normalize=0[aout]", filter)
end)

test("Trailer Encoder leaves the music unfaded when fadeOut is 0", function()
	local filter = Encoder.mixFilter(66, 0.3, 0)
	assertEqual("[1:a]aresample=48000[fx];[2:a]aresample=48000,atrim=0:66,volume=0.3[mu];"
		.. "[fx][mu]amix=inputs=2:duration=first:normalize=0[aout]", filter)
end)

test("Trailer Encoder reads the music from its path as a third input, and mixes it only when given", function()
	local music = { path = "res/msc/synthwave_the_mountain.mp3", volume = 0.3, fadeOut = 1, length = 12 }
	local command = Encoder.muxCommand("v.mp4", "a.wav", "out.mp4.part", music)
	assertTrue(command:find('-i "v.mp4" -i "a.wav" -i "res/msc/synthwave_the_mountain.mp3"', 1, true) ~= nil, command)
	assertTrue(command:find('-filter_complex "' .. Encoder.mixFilter(12, 0.3, 1) .. '" -map "[aout]"', 1, true) ~= nil,
		command)
	local plain = Encoder.muxCommand("v.mp4", "a.wav", "out.mp4.part")
	assertTrue(plain:find("-map 1:a:0", 1, true) ~= nil, plain)
	assertFalse(plain:find("filter_complex", 1, true) ~= nil)
end)
