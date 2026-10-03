-- Input for the app layer -- the only layer allowed to touch `love.*`
-- (docs/ARCHITECTURE.md "Layers"). Two independent jobs live in this file:
-- 1/2 debug-overlay toggles (Input.newDebugState/Input.update, from the
-- previous slice), and gameplay intent mapping (Input.updateIntents, via
-- src/app/bindings.lua) -- device state into ctx.intents[slot], read every
-- frame by whichever caller owns ctx (src/app/states/match_state.lua,
-- tests/support/game_harness.lua).
local Input = {}

local Bindings = require("src.app.bindings")
local Compat = require("src.app.compat")
local Roster = require("src.game.roster")

-- Fills ctx.intents[slot] for every human slot in the roster (defaults to
-- ctx.roster) from the device its binding names. AI slots are skipped.
-- Call once per frame, before Match.step reads them (docs/ARCHITECTURE.md
-- "Systems and frame order", step 1).
function Input.updateIntents(ctx, roster)
	roster = roster or ctx.roster
	local joysticks = Compat.getJoysticks()
	local devices = { isDown = love.keyboard.isDown, joysticks = joysticks }
	for slot = 1, Roster.count(roster) do
		if Roster.isHuman(roster, slot) then
			ctx.intents[slot] = Bindings.readIntent(roster[slot].binding, devices)
		end
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
