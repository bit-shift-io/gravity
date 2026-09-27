local Level = require("src.game.level")
local Config = require("src.game.config")

local function square(x, y, size)
	return {
		{ x = x, y = y },
		{ x = x + size, y = y },
		{ x = x + size, y = y + size },
		{ x = x, y = y + size },
	}
end

test("Level.validate derives mass from density x area when mass isn't set", function()
	local level = {
		worlds = {
			{ vertices = square(0, 0, 10), density = 2 },
		},
	}

	local ok = Level.validate(level)

	assertTrue(ok)
	assertNear(200, level.worlds[1].mass)
end)

test("Level.validate keeps an explicit mass instead of deriving one", function()
	local level = {
		worlds = {
			{ vertices = square(0, 0, 10), density = 2, mass = 999 },
		},
	}

	Level.validate(level)

	assertNear(999, level.worlds[1].mass)
end)

test("Level.validate falls back to the config default density when none is set", function()
	local level = {
		worlds = {
			{ vertices = square(0, 0, 10) },
		},
	}

	Level.validate(level)

	assertNear(Config.world.density * 100, level.worlds[1].mass)
end)

test("Level.validate rejects a self-intersecting world polygon", function()
	local level = {
		worlds = {
			{
				vertices = {
					{ x = 0, y = 0 },
					{ x = 1, y = 1 },
					{ x = 1, y = 0 },
					{ x = 0, y = 1 },
				},
			},
		},
	}

	local ok, err = Level.validate(level)

	assertFalse(ok)
	assertTrue(err ~= nil)
end)

test("Level.validate accepts an empty worlds list", function()
	local ok = Level.validate({ worlds = {} })
	assertTrue(ok)
end)
