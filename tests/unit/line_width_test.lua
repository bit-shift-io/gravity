local LineWidth = require("src.game.line_width")
local SettingsCodec = require("src.game.settings_codec")
local Roster = require("src.game.roster")

test("line width grows as the camera zooms out", function()
	assert(LineWidth.world(0.25) > LineWidth.world(1), "zoomed-out lines should be wider in world units")
	assertEqual(1, LineWidth.world(1))
end)

test("line width never shrinks the on-screen line below the base when zoomed out", function()
	-- On-screen width = world width * zoom; sqrt compensation keeps it from vanishing.
	assert(LineWidth.world(0.28) * 0.28 > 0.28, "on-screen width should beat uncompensated width")
end)

test("line width scales linearly with the thickness multiplier", function()
	assertEqual(2 * LineWidth.world(0.5), LineWidth.world(0.5, 2))
end)

test("LineWidth.next cycles the steps and wraps", function()
	assertEqual(1.5, LineWidth.next(1))
	assertEqual(3, LineWidth.next(2))
	assertEqual(1, LineWidth.next(3))
	assertEqual(1, LineWidth.next(7)) -- unknown value restarts the cycle
end)

test("line thickness round-trips through the settings codec", function()
	local text = SettingsCodec.encode({ roster = Roster.defaultSetup(), lineThickness = 2 })
	assertEqual(2, SettingsCodec.decode(text, {}).lineThickness)
end)

test("a missing or invalid line thickness loads the default", function()
	local text = SettingsCodec.encode({ roster = Roster.defaultSetup() }):gsub("lineThickness [%d%.]+\n", "")
	assertEqual(LineWidth.DEFAULT, SettingsCodec.decode(text, {}).lineThickness)
	local bad = SettingsCodec.encode({ roster = Roster.defaultSetup() }) .. "lineThickness 9\n"
	assertEqual(LineWidth.DEFAULT, SettingsCodec.decode(bad, {}).lineThickness)
	assertEqual(LineWidth.DEFAULT, SettingsCodec.decode("garbage", {}).lineThickness)
end)
