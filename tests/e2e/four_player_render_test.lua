-- A 4-slot match renders four distinctly coloured ships, a HUD block for each
-- human slot only, and a score card that lists every slot.
local GameHarness = require("tests.support.game_harness")
local FrameStepper = require("tests.support.frame_stepper")
local Capture = require("tests.support.capture")
local Bodies = require("src.sim.bodies")
local Config = require("src.game.config")
local RoundSystem = require("src.game.systems.round_system")

local function floorLevel()
	local world = {
		vertices = { { x = -400, y = 100 }, { x = 400, y = 100 }, { x = 400, y = 160 }, { x = -400, y = 160 } },
	}
	local candidates = {}
	for i = 1, 6 do
		candidates[i] = { x = -350 + i * 100, y = 100, normal = { x = 0, y = -1 }, world = world }
	end
	return { worlds = { world }, spawnPoints = { candidates[1], candidates[6] }, spawnCandidates = candidates }
end

local roster = {
	{ color = 1, binding = { kind = "keyboard", layout = "wasd" } },
	{ color = 2, binding = { kind = "ai", level = "easy" } },
	{ color = 3, binding = { kind = "gamepad", id = 1 } },
	{ color = 4, binding = { kind = "ai", level = "medium" } },
}

test("four ships, a human-only HUD and a four-slot score card render", function()
	local game = GameHarness.startMatch(floorLevel(), { real = true, roster = roster, seed = 4 })
	local ctx = game.ctx
	assertEqual(4, #ctx.pools.ships)

	local colors = {}
	for slot = 1, 4 do
		colors[Config.players.palette[roster[slot].color]] = true
	end
	local distinct = 0
	for _ in pairs(colors) do
		distinct = distinct + 1
	end
	assertEqual(4, distinct)

	FrameStepper.step(game, 5)
	Capture.capture("four_ships_hud")

	for i = 2, 4 do
		local ship = ctx.pools.ships[i]
		ship.dead = true
		Bodies.markDead(ctx.sim.bodies, ship.body)
	end
	FrameStepper.step(game, FrameStepper.secondsToFrames(Config.round.endDelay + Config.round.cardDuration / 2))
	assertTrue(RoundSystem.cardVisible(ctx.round, Config.round))
	Capture.capture("four_slot_score_card")
end)
