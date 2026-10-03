-- App flow: owns the state stack and wires the states together (Title ->
-- Setup -> Match, Match -> Pause, Pause -> Title). main.lua only routes LÖVE callbacks
-- here; headless tests drive the same object without a window.
-- opts.seed fixes the match seed (`seed=N` launch arg), otherwise each Play
-- picks a fresh one (the setup seed field starts with it). opts.hardcore (`hardcore=1` launch arg) makes rotating
-- burn fuel in every match, rematches included. opts.quit is called when the player quits from the title.
local Config = require("src.game.config")
local Roster = require("src.game.roster")
local StateStack = require("src.app.states.state_stack")
local TitleState = require("src.app.states.title_state")
local MatchState = require("src.app.states.match_state")
local PauseState = require("src.app.states.pause_state")
local SetupState = require("src.app.states.setup_state")

local Flow = {}
Flow.__index = Flow

function Flow.new(opts)
	opts = opts or {}
	local self = setmetatable({}, Flow)
	-- What the setup screen edits and the match reads: the roster, the seed
	-- field text ("" is random) and hardcore. It outlives matches, so setup
	-- reopens as it was left. opts.roster seeds the roster (default otherwise);
	-- opts.onSettingsChanged(settings) fires after every setup edit;
-- opts.onStart(settings) fires when Start launches a match (not on rematch).
	self.settings = {
		roster = opts.roster or Roster.default(),
		seedText = opts.seed and string.format("%d", opts.seed) or "",
		hardcore = opts.hardcore or false,
	}
	self.onSettingsChanged = opts.onSettingsChanged
	self.onStart = opts.onStart
	self.onQuit = opts.quit
	-- Session-only settings (P cycles the post mode).
	self.session = { postMode = Config.post.defaultMode }
	self.stack = StateStack.new()
	self.stack:push(TitleState.new(self))
	return self
end

function Flow:topName()
	local top = self.stack:top()
	return top and top.name
end

-- The match ctx of the top state, if it is a match.
function Flow:topCtx()
	local top = self.stack:top()
	return top and top.ctx
end

-- Title -> Setup.
function Flow:play()
	self.stack:replace(SetupState.new(self))
end

function Flow:settingsChanged()
	if self.onSettingsChanged then
		self.onSettingsChanged(self.settings)
	end
end

-- Setup -> Match with the current settings; a blank seed picks a fresh one.
function Flow:start()
	local settings = self.settings
	if self.onStart then
		self.onStart(settings)
	end
	local seed = tonumber(settings.seedText) or (os.time() + math.floor(os.clock() * 1000))
	print(string.format("seed=%d", seed))
	self.stack:replace(MatchState.new(self, seed, Roster.copy(settings.roster), settings.hardcore))
end

-- Same level and seed, same roster.
function Flow:rematch(match)
	self.stack:replace(MatchState.new(self, match.seed, match.roster, match.hardcore))
end

function Flow:pause()
	self.stack:push(PauseState.new(self))
end

-- Discards the match (and any pause over it).
function Flow:toTitle()
	self.stack:reset(TitleState.new(self))
end

function Flow:quit()
	if self.onQuit then
		self.onQuit()
	end
end

function Flow:update(dt)
	self.stack:update(dt)
end

function Flow:draw()
	self.stack:draw()
end

function Flow:keypressed(key)
	self.stack:keypressed(key)
end

function Flow:gamepadpressed(joystick, button)
	self.stack:gamepadpressed(joystick, button)
end

function Flow:gamepadaxis(joystick, axis, value)
	self.stack:gamepadaxis(joystick, axis, value)
end

function Flow:textinput(text)
	self.stack:textinput(text)
end

function Flow:joystickadded(joystick)
	self.stack:joystickadded(joystick)
end

function Flow:joystickremoved(joystick)
	self.stack:joystickremoved(joystick)
end

return Flow
