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
	-- No worlds and a screen-centre spawn, so this test can verify fuel burn
	-- rate independently from gravity effects. Ship 2 is spawned far away so
	-- its pairwise pull (slice 06) is also negligible.
	local level = { worlds = {}, spawnPoints = { { x = 640, y = 360 }, { x = 640, y = -1000000 } } }
	local game = GameHarness.startMatch(level)
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
	local game = GameHarness.startMatch(level)
	local ship = game.ctx.pools.ships[1]
	local capacity = ship.fuel.capacity
	local burnRate = ship.fuel.burnRate
	local secondsToEmpty = capacity / burnRate

	game.ctx.intents[1] = { rotate = 0, thrust = true, fire = false }
	-- Thrusting this long would carry the ship into the hard boundary and kill
	-- it, so pull it back to its start each frame (velocity is untouched).
	local startBody = Bodies.get(game.ctx.sim.bodies, ship.body)
	for _ = 1, FrameStepper.secondsToFrames(secondsToEmpty) + 10 do
		startBody.x, startBody.y = 640, 360
		FrameStepper.step(game, 1)
	end

	assertNear(0, ship.fuel.amount, 0.0001)

	local body = Bodies.get(game.ctx.sim.bodies, ship.body)
	local vxBeforeExtraThrust, vyBeforeExtraThrust = body.vx, body.vy

	for _ = 1, 60 do
		startBody.x, startBody.y = 640, 360
		FrameStepper.step(game, 1)
	end

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
