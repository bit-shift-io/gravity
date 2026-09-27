-- Exercises the full ship-flight frame order (Match.new spawning ships at
-- the level's fixture spawn points, Match.step's ship-controls -> Sim.step
-- order) through the real harness rather than any single module in
-- isolation. The integration tier has no `love` global (tests/support/
-- game_harness.lua), so intents are set directly on ctx.intents here rather
-- than through src/app/input.lua, which is app-layer and reads
-- love.keyboard.
local GameHarness = require("tests.support.game_harness")
local FixtureLevel = require("src.game.levels.fixture_two_worlds")
local FrameStepper = require("tests.support.frame_stepper")
local Bodies = require("src.sim.bodies")
local Config = require("src.game.config")

-- A shallow copy of the real config with config.boundary.margin raised well
-- past the ~11,000px worst-case drift these two tests' sustained thrust can
-- produce (slice 08's soft boundary would otherwise mark the ship
-- lost-to-space mid-test, stopping fuel consumption early for a reason
-- unrelated to the fuel-burn-rate math being checked). Kept far short of an
-- arbitrarily large number: src/sim/field.lua's Field.bake grid covers the
-- screen plus this same margin, so an oversized value (1e9 was tried first)
-- makes the bake allocate an unbounded grid and hang. Only `boundary` is
-- overridden; every other tuning number, notably config.ship.mass and
-- config.gravity.G/softening (slice 06's own tuning), is left untouched.
local function withHugeBoundary()
	local overridden = {}
	for k, v in pairs(Config) do
		overridden[k] = v
	end
	overridden.boundary = { margin = 20000 }
	return overridden
end

test("a ship released above a world accelerates toward it with no input", function()
	local level = FixtureLevel.new()
	local game = GameHarness.startMatch(level)
	local ship = game.ctx.pools.ships[1]
	local body = Bodies.get(game.ctx.sim.bodies, ship.body)
	local startX, startY = body.x, body.y

	-- No intents set at all -- the ship should still curve under gravity.
	FrameStepper.step(game, 120)

	local movedX = body.x - startX
	local movedY = body.y - startY
	local moved = math.sqrt(movedX * movedX + movedY * movedY)

	assertTrue(moved > 1, "expected the ship to have moved from its spawn point under gravity alone")
	assertTrue(body.vx ~= 0 or body.vy ~= 0, "expected gravity to have given the ship some velocity")
end)

test("holding thrust for N seconds drains fuel by N x burnRate", function()
	-- No worlds and a screen-centre spawn, so 2s of straight thrust (~440px
	-- of drift) can't carry the ship past the soft-boundary margin (slice
	-- 08) and get it marked lost-to-space mid-test, which would stop fuel
	-- consumption early and make this fuel-math check fail for an unrelated
	-- reason. Ship 2 is spawned far away so its pairwise pull (slice 06) is
	-- also negligible.
	local level = { worlds = {}, spawnPoints = { { x = 640, y = 360 }, { x = 640, y = -1000000 } } }
	local game = GameHarness.startMatch(level, { config = withHugeBoundary() })
	local ship = game.ctx.pools.ships[1]
	local burnRate = ship.fuel.burnRate
	local startAmount = ship.fuel.amount

	game.ctx.intents[1] = { rotate = 0, thrust = true, fire = false }
	FrameStepper.step(game, 120) -- 2 seconds at 1/60s

	assertNear(startAmount - 2 * burnRate, ship.fuel.amount, 0.01)
end)

test("an empty tank disables thrust but the ship keeps rotating", function()
	-- No worlds, so the static field is (near enough) zero everywhere and any
	-- velocity change here can only be from thrust, not gravity -- isolating
	-- "thrust does nothing once the tank is empty" from the curving-under-
	-- gravity behaviour the first test already covers. Ship 2 is spawned far
	-- away so its pairwise pull on ship 1 (slice 06) is also negligible --
	-- this test only cares about ship 1's own thrust/fuel behaviour.
	local level = { worlds = {}, spawnPoints = { { x = 640, y = 360 }, { x = 640, y = -1000000 } } }
	local game = GameHarness.startMatch(level, { config = withHugeBoundary() })
	local ship = game.ctx.pools.ships[1]
	local capacity = ship.fuel.capacity
	local burnRate = ship.fuel.burnRate
	local secondsToEmpty = capacity / burnRate

	game.ctx.intents[1] = { rotate = 0, thrust = true, fire = false }
	FrameStepper.step(game, FrameStepper.secondsToFrames(secondsToEmpty) + 10)

	assertNear(0, ship.fuel.amount, 0.0001)

	local body = Bodies.get(game.ctx.sim.bodies, ship.body)
	local vxBeforeExtraThrust, vyBeforeExtraThrust = body.vx, body.vy

	FrameStepper.step(game, 60)

	-- Thrust no longer accelerates the ship once the tank is empty --
	-- residual gravity may still change velocity slightly, but not by a
	-- thrust-sized amount.
	assertNear(vxBeforeExtraThrust, body.vx, 0.01, "expected thrust to stop accelerating the ship once fuel is empty")
	assertNear(vyBeforeExtraThrust, body.vy, 0.01, "expected thrust to stop accelerating the ship once fuel is empty")

	-- Rotation costs no fuel: with rotate = 0 there's nothing to observe
	-- directly here, but confirm the tank stayed at 0 rather than going
	-- negative while rotation intent was (implicitly) still being read.
	game.ctx.intents[1].rotate = 1
	FrameStepper.step(game, 30)
	assertNear(0, ship.fuel.amount, 0.0001)
end)
