local Hud = require("src.app.render.hud")

test("human HUD blocks fill the top corners first, then the bottom corners", function()
	local one = Hud.blockLayout(1)
	local two = Hud.blockLayout(2)
	local three = Hud.blockLayout(3)
	local four = Hud.blockLayout(4)
	assertTrue(one.left and not two.left)
	assertTrue(three.left and not four.left)
	assertEqual(one.top, two.top)
	assertEqual(three.top, four.top)
	assertTrue(three.top > one.top, "third human sits below the first")
	assertTrue(four.top + Hud.BLOCK_HEIGHT <= 720, "bottom blocks stay on screen")
end)

test("the HUD draws only human slots", function()
	local roster = {
		{ color = 1, binding = { kind = "ai", level = "easy" } },
		{ color = 2, binding = { kind = "keyboard", layout = "wasd" } },
		{ color = 3, binding = { kind = "ai", level = "easy" } },
		{ color = 4, binding = { kind = "gamepad", id = 1 } },
	}
	local blocks = Hud.humanBlocks(roster)
	assertEqual(2, #blocks)
	assertEqual(2, blocks[1].slot)
	assertEqual(4, blocks[2].slot)
	assertTrue(blocks[1].layout.left)
	assertFalse(blocks[2].layout.left)
end)

local function extent(layout)
	return layout.x, layout.x + layout.width
end

test("one to four blocks keep the corner layout", function()
	for count = 1, 4 do
		for index = 1, count do
			local layout = Hud.blockLayout(index, count)
			local plain = Hud.blockLayout(index)
			assertEqual(index % 2 == 1, layout.left)
			assertEqual(plain.top, layout.top)
			assertEqual(200, layout.barWidth)
		end
	end
	assertEqual(16, Hud.blockLayout(1, 4).top)
	assertEqual(16, Hud.blockLayout(1, 4).x)
	assertEqual(1280 - 16 - 200, Hud.blockLayout(2, 4).x)
end)

test("five and six blocks sit in one narrower row without overlapping", function()
	for count = 5, 6 do
		local prevRight = 0
		for index = 1, count do
			local layout = Hud.blockLayout(index, count)
			local left, right = extent(layout)
			assertTrue(layout.barWidth <= 200, "bars are no wider than a corner bar")
			assertTrue(left >= 0 and right <= 1280, "block " .. index .. " stays on screen")
			assertTrue(left >= prevRight, "block " .. index .. " clears its neighbour")
			assertEqual(16, layout.top)
			prevRight = right
		end
	end
end)

test("a squished block holds the win pips", function()
	local layout = Hud.blockLayout(1, 6)
	local pips = 7
	assertTrue(layout.barWidth >= (pips - 1) * 18 + 12, "pips fit under the bar")
end)

test("blocks for all slots include AI; the default is humans only", function()
	local roster = {
		{ color = 1, binding = { kind = "ai", level = "easy" } },
		{ color = 2, binding = { kind = "keyboard", layout = "wasd" } },
		{ color = 3, binding = { kind = "ai", level = "easy" } },
	}
	assertEqual(1, #Hud.blocks(roster))
	local all = Hud.blocks(roster, "all")
	assertEqual(3, #all)
	assertEqual(3, all[3].slot)
	assertEqual(3, #Hud.humanBlocks(roster) + 2)
end)

test("six humans get six blocks laid out for six", function()
	local roster = {}
	for i = 1, 6 do
		roster[i] = { color = i, binding = { kind = "gamepad", id = i } }
	end
	local blocks = Hud.humanBlocks(roster)
	assertEqual(6, #blocks)
	assertEqual(Hud.blockLayout(6, 6).x, blocks[6].layout.x)
end)
