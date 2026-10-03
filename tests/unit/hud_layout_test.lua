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
