local Roster = require("src.game.roster")
local Config = require("src.game.config")

test("the default roster is two human slots with distinct colours", function()
	local roster = Roster.default()
	assertEqual(2, Roster.count(roster))
	assertEqual(2, #Roster.humans(roster))
	assertTrue(roster[1].color ~= roster[2].color)
end)

test("humans lists the slot indexes bound to a keyboard or gamepad, not AI", function()
	local roster = {
		{ color = 1, binding = { kind = "keyboard", layout = "wasd" } },
		{ color = 2, binding = { kind = "ai", level = "easy" } },
		{ color = 3, binding = { kind = "gamepad", id = 1 } },
		{ color = 4, binding = { kind = "ai", level = "hard" } },
	}
	local humans = Roster.humans(roster)
	assertEqual(2, #humans)
	assertEqual(1, humans[1])
	assertEqual(3, humans[2])
	assertTrue(Roster.isHuman(roster, 3))
	assertFalse(Roster.isHuman(roster, 4))
end)

test("the player limits and palette live in config", function()
	assertEqual(2, Config.players.min)
	assertEqual(6, Config.players.max)
	assertEqual(4, Config.players.maxHumans)
	assertTrue(#Config.players.palette >= Config.players.max)
end)

local function ai(color)
	return { color = color, binding = { kind = "ai", level = "easy" } }
end

test("add appends a slot with the first free colour and a free binding", function()
	local roster = Roster.default()
	local ok = Roster.add(roster, {})
	assertTrue(ok)
	assertEqual(3, Roster.count(roster))
	assertEqual(3, roster[3].color)
	assertEqual("ijkl", roster[3].binding.layout)
end)

test("add refuses a seventh slot with a visible reason", function()
	local roster = Roster.default()
	for _ = 3, 6 do
		assertTrue(Roster.add(roster, {}))
	end
	local ok, reason = Roster.add(roster, {})
	assertFalse(ok)
	assertEqual(6, Roster.count(roster))
	assertEqual("MAX 6 SLOTS", reason)
end)

test("remove drops a slot but never below two, with a reason", function()
	local roster = Roster.default()
	Roster.add(roster, {})
	assertTrue(Roster.remove(roster, 2))
	assertEqual(2, Roster.count(roster))
	local ok, reason = Roster.remove(roster, 1)
	assertFalse(ok)
	assertEqual(2, Roster.count(roster))
	assertEqual("NEED AT LEAST 2 SLOTS", reason)
end)

test("cycling a colour skips colours other slots hold and wraps the palette", function()
	local roster = Roster.default() -- colours 1 and 2
	Roster.cycleColor(roster, 1, 1)
	assertEqual(3, roster[1].color) -- 2 is taken
	Roster.cycleColor(roster, 1, -1)
	assertEqual(1, roster[1].color)
	roster[1].color = 6
	Roster.cycleColor(roster, 1, 1)
	assertEqual(1, roster[1].color) -- wraps past the end
end)

test("cycling a binding walks layouts, connected gamepads then AI levels, skipping taken humans", function()
	local roster = Roster.default() -- wasd, arrows
	local pads = { 1, 3 }
	Roster.cycleBinding(roster, 1, pads, 1)
	assertEqual("ijkl", roster[1].binding.layout) -- arrows is slot 2's
	Roster.cycleBinding(roster, 1, pads, 1)
	assertEqual("gamepad", roster[1].binding.kind)
	assertEqual(1, roster[1].binding.id)
	Roster.cycleBinding(roster, 1, pads, 1)
	assertEqual(3, roster[1].binding.id)
	Roster.cycleBinding(roster, 1, pads, 1)
	assertEqual("easy", roster[1].binding.level)
	Roster.cycleBinding(roster, 1, pads, 1)
	assertEqual("medium", roster[1].binding.level)
	Roster.cycleBinding(roster, 1, pads, -1)
	assertEqual("easy", roster[1].binding.level)
end)

test("a gamepad already bound to another slot is skipped", function()
	local roster = Roster.default()
	roster[2].binding = { kind = "gamepad", id = 1 }
	roster[1].binding = { kind = "keyboard", layout = "ijkl" }
	Roster.cycleBinding(roster, 1, { 1 }, 1)
	assertEqual("easy", roster[1].binding.level)
end)

test("AI bindings may repeat across slots", function()
	local roster = { ai(1), ai(2) }
	Roster.cycleBinding(roster, 1, {}, 1) -- easy -> medium
	Roster.cycleBinding(roster, 2, {}, 1)
	assertEqual("medium", roster[1].binding.level)
	assertEqual("medium", roster[2].binding.level)
	assertEqual(0, #Roster.validate(roster, {}))
end)

test("cycling an AI slot at four humans skips human bindings and says why", function()
	local roster = {
		{ color = 1, binding = { kind = "keyboard", layout = "wasd" } },
		{ color = 2, binding = { kind = "keyboard", layout = "arrows" } },
		{ color = 3, binding = { kind = "keyboard", layout = "ijkl" } },
		{ color = 4, binding = { kind = "gamepad", id = 1 } },
		{ color = 5, binding = { kind = "ai", level = "hard" } },
	}
	local ok, note = Roster.cycleBinding(roster, 5, { 1, 2 }, 1) -- hard wraps; every human is refused
	assertTrue(ok)
	assertEqual("easy", roster[5].binding.level)
	assertEqual("MAX 4 HUMANS", note)
end)

test("validate demands two slots and flags more than four humans or six slots", function()
	local problems = Roster.validate({ ai(1) }, {})
	assertEqual("NEED AT LEAST 2 SLOTS", problems[1].reason)

	local five = {}
	for color = 1, 5 do
		five[color] = { color = color, binding = { kind = "gamepad", id = color } }
	end
	problems = Roster.validate(five, { 1, 2, 3, 4, 5 })
	assertEqual("MAX 4 HUMANS", problems[1].reason)
end)

test("validate rejects a keyboard layout bound to two slots", function()
	local roster = Roster.default()
	roster[2].binding = { kind = "keyboard", layout = "wasd" }
	local problems = Roster.validate(roster, {})
	assertEqual(1, #problems)
	assertEqual(2, problems[1].slot)
	assertEqual("KEYBOARD WASD ALREADY USED", problems[1].reason)
end)

test("validate flags a gamepad slot whose pad is no longer connected", function()
	local roster = Roster.default()
	roster[2].binding = { kind = "gamepad", id = 2 }
	assertEqual(0, #Roster.validate(roster, { 1, 2 }))
	local problems = Roster.validate(roster, { 1 })
	assertEqual(1, #problems)
	assertEqual(2, problems[1].slot)
	assertEqual("GAMEPAD 2 DISCONNECTED", problems[1].reason)
end)
