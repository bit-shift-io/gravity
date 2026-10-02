local SnakeShape = require("src.game.snake_shape")
local Config = require("src.game.config")
local Rng = require("src.core.rng")
local Poly = require("src.core.poly")

local SEEDS = 200

test("SnakeShape.generate returns a simple polygon with arm width in the configured range", function()
	local cfg = Config.levelGen
	-- Jitter moves each end-cap vertex by up to vertexJitter on both axes.
	local slack = 2 * cfg.vertexJitter * math.sqrt(2)
	local made = 0
	for seed = 1, SEEDS do
		local vertices = SnakeShape.generate(Rng.new(seed), Config)
		if vertices then
			made = made + 1
			assertTrue(Poly.isSimple(vertices), "seed " .. seed .. " not simple")
			-- The last two vertices of the left run and the first of the right run
			-- bound the far end cap, whose length is the arm width.
			local n = #vertices
			local cap = math.sqrt((vertices[n / 2].x - vertices[n / 2 + 1].x) ^ 2 + (vertices[n / 2].y - vertices[n / 2 + 1].y) ^ 2)
			assertTrue(cap >= cfg.armWidth.min - slack and cap <= cfg.armWidth.max + slack, "seed " .. seed .. " width " .. cap)
		end
	end
	assertTrue(made > SEEDS / 2, "most seeds should yield a snake, got " .. made)
end)

test("SnakeShape.generate gives the same polygon for the same rng seed", function()
	for seed = 1, 20 do
		local a = SnakeShape.generate(Rng.new(seed), Config)
		local b = SnakeShape.generate(Rng.new(seed), Config)
		assertEqual(#a, #b, "seed " .. seed)
		for i, v in ipairs(a) do
			assertTrue(v.x == b[i].x and v.y == b[i].y, "seed " .. seed .. " vertex " .. i)
		end
	end
end)

-- Config copy whose levelGen section has `overrides` applied.
local function configWith(overrides)
	local config = {}
	for k, v in pairs(Config) do
		config[k] = v
	end
	config.levelGen = {}
	for k, v in pairs(Config.levelGen) do
		config.levelGen[k] = v
	end
	for k, v in pairs(overrides) do
		config.levelGen[k] = v
	end
	return config
end

test("SnakeShape.generate rejects self-touching U shapes instead of returning them", function()
	-- 90 degree turns with a middle segment (20) far shorter than the arm width
	-- (60) fold the two arms of a U onto each other.
	local config = configWith({
		snakeSegments = { min = 3, max = 3 },
		segmentLength = { min = 20, max = 20 },
		armWidth = { min = 60, max = 60 },
		turn90Chance = 1,
		vertexJitter = 0,
		snakeRetries = 1,
	})
	local rejected = 0
	for seed = 1, 50 do
		local vertices = SnakeShape.generate(Rng.new(seed), config)
		if vertices == nil then
			rejected = rejected + 1
		else
			assertTrue(Poly.isSimple(vertices), "seed " .. seed .. " returned a non-simple snake")
		end
	end
	assertTrue(rejected > 0, "no seed was rejected")
end)
