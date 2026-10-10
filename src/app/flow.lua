-- App flow: owns the state stack and wires the states together (Title ->
-- Setup -> Match, Match -> Pause, Pause -> Title). main.lua only routes LÖVE callbacks
-- here; headless tests drive the same object without a window.
-- opts.seed fixes the match seed (`seed=N` launch arg), otherwise each Play
-- picks a fresh one (the setup seed field starts with it). opts.intro plays the title intro animation on launch. opts.quit is called when the player quits from the title.
local Config = require("src.game.config")
local Roster = require("src.game.roster")
local LineWidth = require("src.game.line_width")
local StateStack = require("src.app.states.state_stack")
local TitleState = require("src.app.states.title_state")
local MatchState = require("src.app.states.match_state")
local PauseState = require("src.app.states.pause_state")
local SetupState = require("src.app.states.setup_state")
local SettingsState = require("src.app.states.settings_state")
local Audio = require("src.app.audio")

local Flow = {}
Flow.__index = Flow

function Flow.new(opts)
	opts = opts or {}
	local self = setmetatable({}, Flow)
	-- What the setup screen edits and the match reads: the roster, the seed
	-- field text ("" is random). It outlives matches, so setup
	-- reopens as it was left. opts.roster seeds the six setup rows (default otherwise);
	-- opts.onSettingsChanged(settings) fires after every setup edit;
-- opts.sound / opts.music / opts.postMode / opts.fullscreen / opts.lineThickness seed the saved display and audio
-- fields (sound and music default on); the settings screen edits them.
-- opts.onStart(settings) fires when Start launches a match (not on rematch).
	self.settings = {
		roster = opts.roster or Roster.defaultSetup(),
		seedText = opts.seed and string.format("%d", opts.seed) or "",
		sound = opts.sound ~= false,
		music = opts.music ~= false,
		postMode = opts.postMode or Config.post.defaultMode,
		fullscreen = opts.fullscreen or false,
		lineThickness = opts.lineThickness or LineWidth.DEFAULT,
	}
	-- opts.setFullscreen(on) switches the real window; opts.isFullscreen() reports it.
	-- Both are absent headless, so tests and e2e never touch a window.
	self.setFullscreen = opts.setFullscreen
	self.isFullscreen = opts.isFullscreen
	self.onSettingsChanged = opts.onSettingsChanged
	self.onStart = opts.onStart
	self.onQuit = opts.quit
	-- opts.onScreenshot() fires when a state asks for a screenshot (match, pause).
	self.onScreenshot = opts.onScreenshot
	self.stack = StateStack.new()
	self.stack:push(TitleState.new(self, { intro = opts.intro }))
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

-- Title -> Settings (pushed, so Back pops to the title).
function Flow:openSettings()
	self.stack:push(SettingsState.new(self))
end

function Flow:settingsChanged()
	if self.onSettingsChanged then
		self.onSettingsChanged(self.settings)
	end
end

local function freshSeed()
	return os.time() + math.floor(os.clock() * 1000)
end

-- Setup -> Match with the current settings (empty rows dropped); a blank seed picks a fresh one.
function Flow:start()
	local settings = self.settings
	if self.onStart then
		self.onStart(settings)
	end
	local seed = tonumber(settings.seedText) or freshSeed()
	print(string.format("seed=%d", seed))
	Audio.stopAll()
	self.stack:replace(MatchState.new(self, seed, Roster.active(settings.roster)))
end

-- Same roster. Keeps the level and seed (the R dev key replays it); newLayout
-- picks a fresh seed (the match-over rematch).
function Flow:rematch(match, newLayout)
	local seed = match.seed
	if newLayout then
		seed = freshSeed()
		print(string.format("seed=%d", seed))
	end
	self.stack:replace(MatchState.new(self, seed, match.roster))
end

function Flow:pause()
	Audio.stopAll()
	self.stack:push(PauseState.new(self))
end

-- Discards the match (and any pause over it).
function Flow:toTitle()
	Audio.stopAll()
	Audio.stopMusic()
	self.stack:reset(TitleState.new(self))
end

function Flow:quit()
	if self.onQuit then
		self.onQuit()
	end
end

function Flow:screenshot()
	if self.onScreenshot then
		self.onScreenshot()
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
