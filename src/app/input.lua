-- Input for the app layer -- the only layer allowed to touch `love.*`
-- (docs/ARCHITECTURE.md "Layers"). Two independent jobs live in this file:
-- 1/2 debug-overlay toggles (Input.newDebugState/Input.update, from the
-- previous slice), and gameplay intent mapping (Input.updateIntents, this
-- slice) -- keyboard state straight into ctx.intents[player], read every
-- frame by whichever caller owns ctx (src/app/states/match_state.lua,
-- tests/support/game_harness.lua).
local Input = {}

-- P1 (WASD) and P2 (arrows) share one keyboard (slice 04 "Two ships spawn
-- ... P1 (WASD) and P2 (arrows) rotate and thrust"). `rotate` is -1/0/1
-- (left/none/right); `thrust` and `fire` are booleans. There's no weapon
-- component yet (this slice's Gotcha: "Leave a place ... for weapon; nil
-- for now"), so `fire` is read and handed to ctx.intents now so the
-- mapping already exists when a later slice gives it something to act on.
local KEY_MAP = {
	[1] = { left = "a", right = "d", thrust = "w", fire = "space" },
	[2] = { left = "left", right = "right", thrust = "up", fire = "rctrl" },
}

local function readIntent(keys)
	local rotate = 0
	if love.keyboard.isDown(keys.left) then
		rotate = rotate - 1
	end
	if love.keyboard.isDown(keys.right) then
		rotate = rotate + 1
	end

	return {
		rotate = rotate,
		thrust = love.keyboard.isDown(keys.thrust),
		fire = love.keyboard.isDown(keys.fire),
	}
end

-- Fills ctx.intents[1] and ctx.intents[2] from the current keyboard state.
-- Call once per frame, before Match.step reads them (docs/ARCHITECTURE.md
-- "Systems and frame order", step 1).
function Input.updateIntents(ctx)
	for player, keys in pairs(KEY_MAP) do
		ctx.intents[player] = readIntent(keys)
	end
end

-- One toggle-state table per match; kept off ctx.debug rather than as a
-- module-level singleton so two matches (e.g. a test harness and the real
-- app) never share toggle state.
function Input.newDebugState()
	return {
		showField = false,
		showGrid = false,
		_key1Down = false,
		_key2Down = false,
	}
end

-- Call once per frame. Flips a toggle on the frame a key transitions from up
-- to down, not while it's held, so one press is one toggle.
function Input.update(state)
	local key1Down = love.keyboard.isDown("1")
	if key1Down and not state._key1Down then
		state.showField = not state.showField
	end
	state._key1Down = key1Down

	local key2Down = love.keyboard.isDown("2")
	if key2Down and not state._key2Down then
		state.showGrid = not state.showGrid
	end
	state._key2Down = key2Down
end

return Input
