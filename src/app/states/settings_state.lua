-- Settings screen: value rows (SOUND, MUSIC, POST FX, FULLSCREEN, LINES) and BACK, pushed over the title. A row's
-- confirm and left/right all flip it, applying and saving at once through
-- flow:settingsChanged(). Add a row by appending to the list in `rows`.
local MenuNav = require("src.app.menu.menu_nav")
local MenuRender = require("src.app.render.menu")
local Audio = require("src.app.audio")
local PostMode = require("src.app.post.post_mode")
local LineWidth = require("src.game.line_width")

local SettingsState = {}
SettingsState.__index = SettingsState

local POST_LABELS = { [PostMode.OFF] = "OFF", [PostMode.GLOW] = "GLOW", [PostMode.GLOW_CRT] = "GLOW+CRT" }

local function onOff(value)
	return value and "ON" or "OFF"
end

function SettingsState.new(flow)
	local self = setmetatable({ name = "settings", selected = 1, stick = MenuNav.newStick(), flow = flow }, SettingsState)
	local back = function() flow.stack:pop() end
	if flow.isFullscreen then
		flow.settings.fullscreen = flow.isFullscreen()
	end
	self.onBack = back
	self:refresh()
	return self
end

function SettingsState:toggleSound()
	local settings = self.flow.settings
	settings.sound = not settings.sound
	Audio.setEnabled(settings.sound)
	self:refresh()
	self.flow:settingsChanged()
end

function SettingsState:toggleMusic()
	local settings = self.flow.settings
	settings.music = not settings.music
	Audio.setMusicEnabled(settings.music)
	self:refresh()
	self.flow:settingsChanged()
end

function SettingsState:cyclePostMode()
	local settings = self.flow.settings
	settings.postMode = PostMode.next(settings.postMode)
	self:refresh()
	self.flow:settingsChanged()
end

function SettingsState:toggleFullscreen()
	local settings = self.flow.settings
	settings.fullscreen = not settings.fullscreen
	if self.flow.setFullscreen then
		self.flow.setFullscreen(settings.fullscreen)
	end
	self:refresh()
	self.flow:settingsChanged()
end

function SettingsState:cycleLineThickness()
	local settings = self.flow.settings
	settings.lineThickness = LineWidth.next(settings.lineThickness)
	self:refresh()
	self.flow:settingsChanged()
end

-- Rebuilds the row labels from the current settings.
function SettingsState:refresh()
	local toggle = function() self:toggleSound() end
	local toggleMusic = function() self:toggleMusic() end
	local cyclePost = function() self:cyclePostMode() end
	local toggleFullscreen = function() self:toggleFullscreen() end
	local cycleLines = function() self:cycleLineThickness() end
	self.items = {
		{ label = "SOUND  " .. onOff(self.flow.settings.sound), action = toggle, adjust = toggle },
		{ label = "MUSIC  " .. onOff(self.flow.settings.music), action = toggleMusic, adjust = toggleMusic },
		{ label = "POST FX  " .. POST_LABELS[self.flow.settings.postMode], action = cyclePost, adjust = cyclePost },
		{ label = "FULLSCREEN  " .. onOff(self.flow.settings.fullscreen), action = toggleFullscreen, adjust = toggleFullscreen },
		{ label = "LINES  " .. string.format("%gX", self.flow.settings.lineThickness), action = cycleLines, adjust = cycleLines },
		{ label = "BACK", sound = "back", action = self.onBack },
	}
end

function SettingsState:keypressed(key)
	MenuNav.apply(self, MenuNav.fromKey(key))
end

function SettingsState:gamepadpressed(_, button)
	MenuNav.apply(self, MenuNav.fromButton(button))
end

function SettingsState:gamepadaxis(_, axis, value)
	MenuNav.apply(self, self.stick:axis(axis, value))
end

function SettingsState:draw()
	MenuRender.draw({ title = "SETTINGS", items = self.items, selected = self.selected })
end

return SettingsState
