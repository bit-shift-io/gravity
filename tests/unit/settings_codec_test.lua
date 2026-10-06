local SettingsCodec = require("src.game.settings_codec")
local Config = require("src.game.config")
local unpack = table.unpack or unpack

local function mixedRoster()
	return {
		{ color = 3, binding = { kind = "keyboard", layout = "ijkl" } },
		{ color = 1, binding = { kind = "gamepad", id = 2 } },
		{ color = 6, binding = { kind = "ai", level = "hard" } },
		{ color = 5, binding = { kind = "none" } },
		{ color = 2, binding = { kind = "none" } },
		{ color = 4, binding = { kind = "none" } },
	}
end

test("a roster round-trips through encode and decode", function()
	local text = SettingsCodec.encode({ roster = mixedRoster() })
	local settings = SettingsCodec.decode(text, { 1, 2 })
	assertEqual(6, #settings.roster)
	assertEqual("ijkl", settings.roster[1].binding.layout)
	assertEqual(3, settings.roster[1].color)
	assertEqual("gamepad", settings.roster[2].binding.kind)
	assertEqual(2, settings.roster[2].binding.id)
	assertEqual("hard", settings.roster[3].binding.level)
	assertEqual(6, settings.roster[3].color)
end)

test("empty rows and the colours they hold survive a round trip", function()
	local settings = SettingsCodec.decode(SettingsCodec.encode({ roster = mixedRoster() }), { 1, 2 })
	assertEqual("none", settings.roster[4].binding.kind)
	assertEqual(5, settings.roster[4].color)
	assertEqual("none", settings.roster[5].binding.kind)
	assertEqual(2, settings.roster[5].color)
	assertEqual(4, settings.roster[6].color)
end)

local Roster = require("src.game.roster")

local function assertDefaults(settings)
	assertEqual(6, #settings.roster)
	assertEqual("wasd", settings.roster[1].binding.layout)
	assertEqual("arrows", settings.roster[2].binding.layout)
	assertEqual("none", settings.roster[3].binding.kind)
end

test("empty, garbage and non-string input load defaults", function()
	assertDefaults(SettingsCodec.decode("", {}))
	assertDefaults(SettingsCodec.decode("\0\255 not settings {{{", {}))
	assertDefaults(SettingsCodec.decode(nil, {}))
	assertDefaults(SettingsCodec.decode(42, {}))
end)

test("an unknown version loads defaults even when the body looks valid", function()
	local text = SettingsCodec.encode({ roster = mixedRoster() }):gsub("gravity%-settings 1", "gravity-settings 2")
	assertDefaults(SettingsCodec.decode(text, { 1, 2 }))
end)

local function encodeSlots(...)
	return "gravity-settings 1\n" .. table.concat({ ... }, "\n") .. "\n"
end

local function assertValid(settings, gamepads)
	local problems = Roster.validate(settings.roster, gamepads)
	assertEqual(0, #problems, problems[1] and problems[1].reason or "")
end

test("a saved gamepad that is no longer connected falls back to the next unused keyboard layout", function()
	local settings = SettingsCodec.decode(encodeSlots("slot 1 keyboard wasd", "slot 2 gamepad 2"), { 1 })
	assertEqual("keyboard", settings.roster[2].binding.kind)
	assertEqual("arrows", settings.roster[2].binding.layout)
	assertValid(settings, { 1 })
end)

test("with every keyboard layout taken, a missing pad becomes AI easy", function()
	local settings = SettingsCodec.decode(
		encodeSlots("slot 1 keyboard wasd", "slot 2 keyboard arrows", "slot 3 keyboard ijkl", "slot 4 gamepad 3"), {})
	assertEqual("ai", settings.roster[4].binding.kind)
	assertEqual("easy", settings.roster[4].binding.level)
	assertValid(settings, {})
end)

test("a saved pad stays bound when it is still connected, by ordinal", function()
	local settings = SettingsCodec.decode(encodeSlots("slot 1 keyboard wasd", "slot 2 gamepad 2"), { 1, 2 })
	assertEqual("gamepad", settings.roster[2].binding.kind)
	assertEqual(2, settings.roster[2].binding.id)
end)

test("a valid header with no usable slots loads the default roster even with a legacy hardcore line", function()
	local settings = SettingsCodec.decode("gravity-settings 1\nhardcore 1\nslot x y z\n", {})
	assertEqual(6, #settings.roster)
	assertEqual("wasd", settings.roster[1].binding.layout)
	assertValid(settings, {})
end)

test("a lone saved slot is below the minimum active rows, so defaults load", function()
	local settings = SettingsCodec.decode(encodeSlots("slot 1 keyboard wasd"), {})
	assertEqual(6, #settings.roster)
	assertEqual("arrows", settings.roster[2].binding.layout)
	assertValid(settings, {})
end)

test("a saved roster with no human loads the default setup", function()
	local settings = SettingsCodec.decode(encodeSlots("slot 1 ai easy", "slot 2 ai hard"), {})
	assertEqual("wasd", settings.roster[1].binding.layout)
	assertEqual("arrows", settings.roster[2].binding.layout)
end)

test("one human and one AI is a valid saved roster and is kept", function()
	local settings = SettingsCodec.decode(encodeSlots("slot 1 keyboard ijkl", "slot 2 ai hard"), {})
	assertEqual("ijkl", settings.roster[1].binding.layout)
	assertEqual("hard", settings.roster[2].binding.level)
	assertValid(settings, {})
end)

test("more than the maximum slots are trimmed", function()
	local lines = {}
	for slot = 1, 8 do
		lines[slot] = "slot " .. slot .. " ai easy"
	end
	local settings = SettingsCodec.decode(encodeSlots(unpack(lines)), {})
	assertEqual(6, #settings.roster)
	assertValid(settings, {})
end)

test("duplicate and out-of-palette colours are reassigned to free palette colours", function()
	local settings = SettingsCodec.decode(encodeSlots("slot 2 keyboard wasd", "slot 2 keyboard arrows", "slot 99 ai easy", "slot 0 ai hard"), {})
	local seen = {}
	for _, slot in ipairs(settings.roster) do
		assertTrue(slot.color >= 1 and slot.color <= #Config.players.palette, "colour in palette")
		assertFalse(seen[slot.color], "unique colour")
		seen[slot.color] = true
	end
	assertEqual(2, settings.roster[1].color)
end)

test("a saved medium AI level is repaired to easy", function()
	local settings = SettingsCodec.decode(encodeSlots("slot 1 keyboard wasd", "slot 2 ai medium"), {})
	assertEqual("ai", settings.roster[2].binding.kind)
	assertEqual("easy", settings.roster[2].binding.level)
	assertValid(settings, {})
end)

test("an unknown layout, AI level or binding kind is replaced so the roster still validates", function()
	local settings = SettingsCodec.decode(encodeSlots("slot 1 keyboard dvorak", "slot 2 ai godlike", "slot 3 touchscreen x"), {})
	assertEqual(6, #settings.roster)
	assertValid(settings, {})
	assertEqual("keyboard", settings.roster[1].binding.kind)
	assertEqual("wasd", settings.roster[1].binding.layout)
	assertEqual("ai", settings.roster[2].binding.kind)
	assertEqual("easy", settings.roster[2].binding.level)
	assertEqual("keyboard", settings.roster[3].binding.kind)
	assertEqual("arrows", settings.roster[3].binding.layout)
end)

test("duplicate keyboard layouts and pads are rebound so each device binds one slot", function()
	local settings = SettingsCodec.decode(encodeSlots("slot 1 keyboard wasd", "slot 2 keyboard wasd", "slot 3 gamepad 1", "slot 4 gamepad 1"), { 1 })
	assertValid(settings, { 1 })
end)

test("a six-human roster round-trips and validates", function()
	local roster = {
		{ color = 1, binding = { kind = "keyboard", layout = "wasd" } },
		{ color = 2, binding = { kind = "keyboard", layout = "arrows" } },
		{ color = 3, binding = { kind = "keyboard", layout = "ijkl" } },
		{ color = 4, binding = { kind = "gamepad", id = 1 } },
		{ color = 5, binding = { kind = "gamepad", id = 2 } },
		{ color = 6, binding = { kind = "gamepad", id = 3 } },
	}
	local settings = SettingsCodec.decode(SettingsCodec.encode({ roster = roster }), { 1, 2, 3 })
	assertEqual(6, #Roster.humans(settings.roster))
	assertEqual(3, settings.roster[6].binding.id)
	assertValid(settings, { 1, 2, 3 })
end)

local function assertPermutation(roster)
	assertEqual(6, #roster)
	local seen = {}
	for _, slot in ipairs(roster) do
		assertTrue(slot.color >= 1 and slot.color <= 6, "colour in palette")
		assertFalse(seen[slot.color], "unique colour")
		seen[slot.color] = true
	end
end

test("an older file with fewer than six slots is padded with empty rows on unused colours", function()
	local settings = SettingsCodec.decode(encodeSlots("slot 4 keyboard wasd", "slot 1 ai hard", "slot 2 keyboard arrows"), {})
	assertPermutation(settings.roster)
	assertEqual(4, settings.roster[1].color)
	for row = 4, 6 do
		assertEqual("none", settings.roster[row].binding.kind)
	end
	assertEqual(3, settings.roster[4].color) -- first unused palette colour
end)

test("a file with fewer than two active rows loads the default setup even with a legacy hardcore line", function()
	local text = "gravity-settings 1\nhardcore 1\nslot 1 keyboard wasd\nslot 2 none\nslot 3 none\nslot 4 none\nslot 5 none\nslot 6 none\n"
	local settings = SettingsCodec.decode(text, {})
	assertEqual("arrows", settings.roster[2].binding.layout)
	assertPermutation(settings.roster)
end)

test("duplicate colours across six saved rows are repaired to a permutation", function()
	local settings = SettingsCodec.decode(encodeSlots("slot 2 keyboard wasd", "slot 2 keyboard arrows", "slot 9 none", "slot 1 none", "slot 1 none", "slot 6 none"), {})
	assertPermutation(settings.roster)
	assertEqual(2, settings.roster[1].color)
end)

test("sound, postMode, and fullscreen round-trip with non-default values", function()
	local text = SettingsCodec.encode({
		roster = mixedRoster(),
		sound = false,
		postMode = "off",
		fullscreen = true
	})
	local settings = SettingsCodec.decode(text, { 1, 2 })
	assertFalse(settings.sound)
	assertEqual("off", settings.postMode)
	assertTrue(settings.fullscreen)
end)

test("old files without new lines decode to defaults (sound on, postMode from config, windowed)", function()
	local text = SettingsCodec.encode({ roster = mixedRoster() })
	local settings = SettingsCodec.decode(text, { 1, 2 })
	assertTrue(settings.sound)
	assertEqual(Config.post.defaultMode, settings.postMode)
	assertFalse(settings.fullscreen)
end)

test("garbage values in sound, postMode, fullscreen fall back to defaults", function()
	local text = "gravity-settings 1\nslot 1 keyboard wasd\nslot 2 keyboard arrows\nsound banana\npostMode xyz\nfullscreen maybe\n"
	local settings = SettingsCodec.decode(text, {})
	assertTrue(settings.sound)
	assertEqual(Config.post.defaultMode, settings.postMode)
	assertFalse(settings.fullscreen)
end)

test("invalid postMode falls back to the config default", function()
	local text = "gravity-settings 1\nslot 1 keyboard wasd\nslot 2 keyboard arrows\npostMode banana\n"
	local settings = SettingsCodec.decode(text, {})
	assertEqual(Config.post.defaultMode, settings.postMode)
end)

test("every PostMode name is accepted by the codec", function()
	local PostMode = require("src.app.post.post_mode")
	-- Build a list of valid postMode names from PostMode constants
	local validModes = { PostMode.OFF, PostMode.GLOW, PostMode.GLOW_CRT }

	for _, mode in ipairs(validModes) do
		local text = "gravity-settings 1\nslot 1 keyboard wasd\nslot 2 keyboard arrows\npostMode " .. mode .. "\n"
		local settings = SettingsCodec.decode(text, {})
		assertEqual(mode, settings.postMode, "postMode " .. mode .. " should be accepted")
	end
end)

test("sound and fullscreen accept 0 and 1 values", function()
	local text = "gravity-settings 1\nslot 1 keyboard wasd\nslot 2 keyboard arrows\nsound 0\nfullscreen 1\n"
	local settings = SettingsCodec.decode(text, {})
	assertFalse(settings.sound)
	assertTrue(settings.fullscreen)
end)
