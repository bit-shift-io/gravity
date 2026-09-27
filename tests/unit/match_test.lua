local Match = require("src.game.match")
local Config = require("src.game.config")

test("Match.new builds a ctx with the shape systems expect", function()
	local level = { worlds = {} }
	local ctx = Match.new(level, Config)

	assertEqual(0, ctx.time)
	assertEqual(level, ctx.level)
	assertEqual(Config, ctx.config)
	assertTrue(ctx.pools ~= nil)
	assertTrue(ctx.sim ~= nil)
	assertTrue(ctx.intents ~= nil)
	assertTrue(ctx.events ~= nil)
end)

test("Match.step exists and does not error on an empty ctx", function()
	local ctx = Match.new({ worlds = {} }, Config)
	ctx.dt = 1 / 60
	Match.step(ctx)
end)
