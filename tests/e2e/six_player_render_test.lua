-- A six-human match squishes the HUD into one row of six blocks, and the
-- "all slots" option draws a block for AI slots too.
local GameHarness = require("tests.support.game_harness")
local FrameStepper = require("tests.support.frame_stepper")
local Capture = require("tests.support.capture")
local Hud = require("src.app.render.hud")

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

local roster = {}
for i = 1, 6 do
	roster[i] = { color = i, binding = { kind = "gamepad", id = i } }
end

test("six humans render six ships and six non-overlapping HUD blocks", function()
	local game = GameHarness.startMatch(floorLevel(), { real = true, roster = roster, seed = 6 })
	assertEqual(6, #game.ctx.pools.ships)
	local blocks = Hud.blocks(game.ctx.roster)
	assertEqual(6, #blocks)
	for i = 2, 6 do
		local prev, cur = blocks[i - 1].layout, blocks[i].layout
		assertTrue(cur.x >= prev.x + prev.width, "block " .. i .. " clears block " .. (i - 1))
	end
	assertTrue(blocks[6].layout.x + blocks[6].layout.width <= 1280)
	FrameStepper.step(game, 5)
	Capture.capture("six_humans_hud")
end)
