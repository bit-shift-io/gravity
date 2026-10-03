local PlayerColors = require("src.app.render.player_colors")
local Roster = require("src.game.roster")
local Config = require("src.game.config")

test("a slot's colour is the palette entry its roster colour index names", function()
	local roster = Roster.default()
	roster[1].color = 5
	local ctx = { roster = roster, config = Config }
	assertEqual(Config.players.palette[5], PlayerColors.get(ctx, 1))
	assertEqual(Config.players.palette[2], PlayerColors.get(ctx, 2))
end)

test("an unknown slot draws white", function()
	local ctx = { roster = Roster.default(), config = Config }
	assertEqual(1, PlayerColors.get(ctx, 9)[1])
end)
