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
	assertEqual(1, Config.players.minHumans)
	assertEqual(6, Config.players.max)
	assertEqual(6, Config.players.maxHumans)
	assertTrue(#Config.players.palette >= Config.players.max)
end)

local function ai(color)
	return { color = color, binding = { kind = "ai", level = "easy" } }
end

test("cycling a colour takes the next palette colour and swaps with the row holding it", function()
	local roster = Roster.defaultSetup()
	Roster.cycleColor(roster, 1, 1)
	assertEqual(2, roster[1].color)
	assertEqual(1, roster[2].color) -- the other row got this row's old colour
	Roster.cycleColor(roster, 1, -1)
	assertEqual(1, roster[1].color)
	assertEqual(2, roster[2].color)
end)

test("cycling a colour wraps the palette and keeps the six colours a permutation", function()
	local roster = Roster.defaultSetup()
	Roster.cycleColor(roster, 6, 1)
	assertEqual(1, roster[6].color)
	assertEqual(6, roster[1].color)
	Roster.cycleColor(roster, 1, 1)
	local seen = {}
	for _, row in ipairs(roster) do
		seen[row.color] = true
	end
	for color = 1, 6 do
		assertTrue(seen[color], "colour " .. color)
	end
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
	assertEqual("hard", roster[1].binding.level)
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
	local roster = { { color = 1, binding = { kind = "keyboard", layout = "wasd" } }, ai(2), ai(3) }
	Roster.cycleBinding(roster, 2, {}, 1) -- easy -> hard
	Roster.cycleBinding(roster, 3, {}, 1)
	assertEqual("hard", roster[2].binding.level)
	assertEqual("hard", roster[3].binding.level)
	assertEqual(0, #Roster.validate(roster, {}))
end)

test("cycling an AI slot at six humans skips human bindings and says why", function()
	local roster = {
		{ color = 1, binding = { kind = "keyboard", layout = "wasd" } },
		{ color = 2, binding = { kind = "keyboard", layout = "arrows" } },
		{ color = 3, binding = { kind = "keyboard", layout = "ijkl" } },
		{ color = 4, binding = { kind = "gamepad", id = 1 } },
		{ color = 5, binding = { kind = "gamepad", id = 2 } },
		{ color = 6, binding = { kind = "gamepad", id = 3 } },
		{ color = 7, binding = { kind = "none" } },
	}
	local ok, note = Roster.cycleBinding(roster, 7, { 1, 2, 3, 4 }, 1) -- every free human binding is refused
	assertTrue(ok)
	assertEqual("easy", roster[7].binding.level)
	assertEqual("MAX 6 HUMANS", note)
end)

test("validate accepts six humans on three keyboard layouts and three gamepads", function()
	local six = {
		{ color = 1, binding = { kind = "keyboard", layout = "wasd" } },
		{ color = 2, binding = { kind = "keyboard", layout = "arrows" } },
		{ color = 3, binding = { kind = "keyboard", layout = "ijkl" } },
		{ color = 4, binding = { kind = "gamepad", id = 1 } },
		{ color = 5, binding = { kind = "gamepad", id = 2 } },
		{ color = 6, binding = { kind = "gamepad", id = 3 } },
	}
	assertEqual(0, #Roster.validate(six, { 1, 2, 3 }))
end)

test("validate demands two players and flags more than six players", function()
	local problems = Roster.validate({ ai(1) }, {})
	assertEqual("NEED AT LEAST 2 PLAYERS", problems[1].reason)

	local seven, pads = {}, {}
	for color = 1, 7 do
		seven[color] = { color = color, binding = { kind = "gamepad", id = color } }
		pads[color] = color
	end
	problems = Roster.validate(seven, pads)
	assertEqual("MAX 6 PLAYERS", problems[1].reason)
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

test("the setup default is six rows, colours 1 to 6, wasd and arrows then empty", function()
	local roster = Roster.defaultSetup()
	assertEqual(6, #roster)
	for row = 1, 6 do
		assertEqual(row, roster[row].color)
	end
	assertEqual("wasd", roster[1].binding.layout)
	assertEqual("arrows", roster[2].binding.layout)
	for row = 3, 6 do
		assertEqual("none", roster[row].binding.kind)
	end
end)

test("active is a copy without the empty rows, keeping colour and binding in row order", function()
	local roster = Roster.defaultSetup()
	roster[4].binding = { kind = "ai", level = "hard" }
	local active = Roster.active(roster)
	assertEqual(3, #active)
	assertEqual(4, active[3].color)
	assertEqual("hard", active[3].binding.level)
	active[1].binding.layout = "ijkl"
	assertEqual("wasd", roster[1].binding.layout)
end)

test("an empty row is not a human", function()
	local roster = Roster.defaultSetup()
	assertEqual(2, #Roster.humans(roster))
	assertFalse(Roster.isHuman(roster, 3))
end)

test("cycling a binding ends with empty after the AI levels, then wraps to the first layout", function()
	local roster = Roster.defaultSetup()
	roster[3].binding = { kind = "ai", level = "hard" }
	Roster.cycleBinding(roster, 3, {}, 1)
	assertEqual("none", roster[3].binding.kind)
	Roster.cycleBinding(roster, 3, {}, 1)
	assertEqual("ijkl", roster[3].binding.layout) -- wasd and arrows are taken
	Roster.cycleBinding(roster, 3, {}, -1)
	assertEqual("none", roster[3].binding.kind)
end)

test("empty is never refused, even at four humans bound", function()
	local roster = Roster.defaultSetup()
	roster[3].binding = { kind = "keyboard", layout = "ijkl" }
	roster[4].binding = { kind = "gamepad", id = 1 }
	roster[5].binding = { kind = "ai", level = "hard" }
	Roster.cycleBinding(roster, 5, { 1 }, 1)
	assertEqual("none", roster[5].binding.kind)
end)

test("validate counts only non-empty rows toward the two-player minimum", function()
	local roster = Roster.defaultSetup()
	assertEqual(0, #Roster.validate(roster, {}))
	roster[2].binding = { kind = "none" }
	local problems = Roster.validate(roster, {})
	assertEqual(1, #problems)
	assertEqual("NEED AT LEAST 2 PLAYERS", problems[1].reason)
end)

test("validate needs a human, but the second player may be AI", function()
	local roster = Roster.defaultSetup()
	roster[2].binding = { kind = "ai", level = "easy" }
	assertEqual(0, #Roster.validate(roster, {}), "one human plus one AI is playable")
	roster[1].binding = { kind = "ai", level = "hard" }
	local problems = Roster.validate(roster, {})
	assertEqual(1, #problems)
	assertEqual("NEED AT LEAST 1 HUMAN", problems[1].reason)
end)

test("validate ignores empty rows for the human limit, duplicates and pads", function()
	local roster = Roster.defaultSetup()
	roster[3].binding = { kind = "ai", level = "easy" }
	assertEqual(0, #Roster.validate(roster, {}))
end)
