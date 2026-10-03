-- Title screen: Play and Quit. Play asks the flow to start a match with the
-- default roster; a later setup state slots in between (Title -> Setup -> Match).
local MenuNav = require("src.app.menu.menu_nav")
local MenuRender = require("src.app.render.menu")

local TitleState = {}
TitleState.__index = TitleState

function TitleState.new(flow)
	local self = setmetatable({ name = "title", selected = 1, stick = MenuNav.newStick() }, TitleState)
	self.items = {
		{ label = "PLAY", action = function() flow:play() end },
		{ label = "QUIT", action = function() flow:quit() end },
	}
	return self
end

function TitleState:keypressed(key)
	MenuNav.apply(self, MenuNav.fromKey(key))
end

function TitleState:gamepadpressed(_, button)
	MenuNav.apply(self, MenuNav.fromButton(button))
end

function TitleState:gamepadaxis(_, axis, value)
	MenuNav.apply(self, self.stick:axis(axis, value))
end

function TitleState:draw()
	MenuRender.draw({ title = "GRAV//TY", items = self.items, selected = self.selected })
end

return TitleState
