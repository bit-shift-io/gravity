local Text = require("tools.trailer.text")

test("Trailer Text keeps the top anchor below the HUD's top row", function()
	local _, y = Text.place(1920, 1080, "top", 800, 60)
	assertTrue(y >= 1080 * 0.1, "y=" .. y)
end)

test("Trailer Text keeps the bottom anchor above the HUD's bottom row", function()
	local _, y = Text.place(1920, 1080, "bottom", 800, 60)
	assertTrue(y + 60 <= 1080 * 0.9, "bottom=" .. (y + 60))
end)

test("Trailer Text centres top, centre and bottom captions horizontally", function()
	local x = Text.place(1920, 1080, "bottom", 800, 60)
	assertNear(560, x, 1e-9)
end)

test("Trailer Text puts a lowerLeft caption at the safe left margin", function()
	local x = Text.place(1920, 1080, "lowerLeft", 800, 60)
	assertNear(1920 * 0.08, x, 1e-9)
end)
