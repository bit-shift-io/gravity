-- Title screen: Play and Quit. Play asks the flow to start a match with the
-- default roster; a later setup state slots in between (Title -> Setup -> Match).
local MenuNav = require("src.app.menu.menu_nav")
local MenuRender = require("src.app.render.menu")
local Config = require("src.game.config")

-- Intro: the title sits alone for HOLD seconds, then slides up while the items
-- rise and fade in over SLIDE seconds.
local HOLD = 1
local SLIDE = 0.7

local TitleState = {}
TitleState.__index = TitleState

-- opts.intro plays the intro animation (first launch only); otherwise the menu is settled.
function TitleState.new(flow, opts)
	local self = setmetatable({ name = "title", selected = 1, stick = MenuNav.newStick(), flow = flow }, TitleState)
	self.clock = (opts and opts.intro) and 0 or HOLD + SLIDE
	self.items = {
		{ label = "PLAY", sound = "forward", action = function() flow:play() end },
		{ label = "QUIT", action = function() flow:quit() end },
	}
	return self
end

-- 0 while the title holds alone, 1 once settled.
function TitleState:reveal()
	return math.max(0, math.min(1, (self.clock - HOLD) / SLIDE))
end

function TitleState:update(dt)
	self.clock = math.min(self.clock + dt, HOLD + SLIDE)
end

-- Any key or button during the intro skips it; the menu is only usable once the items are in.
function TitleState:skipIntro()
	if self:reveal() < 1 then
		self.clock = HOLD + SLIDE
		return true
	end
end

function TitleState:keypressed(key)
	if not self:skipIntro() then
		MenuNav.apply(self, MenuNav.fromKey(key))
	end
end

function TitleState:gamepadpressed(_, button)
	if not self:skipIntro() then
		MenuNav.apply(self, MenuNav.fromButton(button))
	end
end

function TitleState:gamepadaxis(_, axis, value)
	MenuNav.apply(self, self.stick:axis(axis, value))
end

function TitleState:draw()
	local roster, palette = self.flow.settings.roster, Config.players.palette
	local colors = { palette[roster[1].color], palette[roster[2].color] }
	MenuRender.draw({ title = "GRAV//TY", items = self.items, selected = self.selected, titleColors = colors, reveal = self:reveal() })
end

return TitleState
