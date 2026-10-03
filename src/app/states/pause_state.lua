-- Pause overlay pushed over the match: Resume or Quit to menu. Being on top,
-- it is the only state that updates, so the match underneath is frozen.
local MenuNav = require("src.app.menu.menu_nav")
local MenuRender = require("src.app.render.menu")

local PauseState = {}
PauseState.__index = PauseState

function PauseState.new(flow)
	local self = setmetatable({ name = "pause", overlay = true, selected = 1, stick = MenuNav.newStick() }, PauseState)
	self.items = {
		{ label = "RESUME", sound = "back", action = function() flow.stack:pop() end },
		{ label = "QUIT TO MENU", sound = "back", action = function() flow:toTitle() end },
	}
	self.onBack = self.items[1].action
	return self
end

function PauseState:keypressed(key)
	MenuNav.apply(self, MenuNav.fromKey(key))
end

function PauseState:gamepadpressed(_, button)
	-- Start toggles pause, so the button that opened it also closes it.
	MenuNav.apply(self, button == "start" and "back" or MenuNav.fromButton(button))
end

function PauseState:gamepadaxis(_, axis, value)
	MenuNav.apply(self, self.stick:axis(axis, value))
end

function PauseState:draw()
	MenuRender.draw({ title = "PAUSED", items = self.items, selected = self.selected, dim = 0.6 })
end

return PauseState
