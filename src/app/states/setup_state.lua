-- Roster setup: Title -> Setup -> Match. Edits flow.settings (roster, seed
-- field text) in place; Start validates and launches the match.
--   six slot rows (a binding of EMPTY switches a row off)
--               left/right cycle the binding, confirm cycles the colour
--   SEED (keyboard digits via textinput, backspace
--   deletes), RANDOMISE SEED, START, BACK.
-- Works by keyboard or any gamepad (a gamepad cannot type digits, but can
-- randomise). Limits and validation live in src/game/roster.lua; this state
-- only shows their reasons.
-- Footer text precedence: problem (alert) > notice > seed hint (SEED row
-- selected) > first roster warning. Confirm on SEED randomises it.
local Config = require("src.game.config")
local Roster = require("src.game.roster")
local Compat = require("src.app.compat")
local MenuNav = require("src.app.menu.menu_nav")
local MenuRender = require("src.app.render.menu")

local SetupState = {}
SetupState.__index = SetupState

local LAYOUT_NAMES = { wasd = "WASD+Q", arrows = "ARROWS+SHIFT", ijkl = "IJKL+O" }

local function bindingLabel(binding)
	if binding.kind == "keyboard" then
		return LAYOUT_NAMES[binding.layout] or binding.layout:upper()
	elseif binding.kind == "gamepad" then
		return "PAD " .. binding.id
	elseif binding.kind == "none" then
		return "EMPTY"
	end
	return "AI " .. binding.level:upper()
end

function SetupState.new(flow)
	local self = setmetatable({ name = "setup", flow = flow, settings = flow.settings, stick = MenuNav.newStick() }, SetupState)
	self.onBack = function() flow:toTitle() end
	local swapped = self:adoptPadDefault()
	self:refresh()
	self.selected = #self.items - 1 -- START (second to last)
	if swapped then
		flow:settingsChanged()
	end
	return self
end

local function randomSeedText()
	return string.format("%d", math.random(0, 10 ^ Config.setup.seedMaxDigits - 1))
end

-- Rebuilds the rows from the settings and re-validates the roster against the
-- pads connected right now (also called on joystick added/removed).
function SetupState:refresh()
	local settings = self.settings
	local previous = self.items and self.items[self.selected]
	self.problems = Roster.validate(settings.roster, Compat.connectedPadIds())
	self.warnings = Roster.warnings(settings.roster, Compat.connectedPadIds())
	local flagged = {}
	for _, problem in ipairs(self.problems) do
		if problem.slot then
			flagged[problem.slot] = true
		end
	end

	local items = {}
	for slot, entry in ipairs(settings.roster) do
		items[#items + 1] = {
			label = "SLOT " .. slot .. "  " .. bindingLabel(entry.binding),
			color = Config.players.palette[entry.color],
			flag = flagged[slot],
			dim = entry.binding.kind == "none",
			action = function() self:edit(function() Roster.cycleColor(settings.roster, slot, 1) end) end,
			adjust = function(dir) self:cycleBinding(slot, dir == "right" and 1 or -1) end,
		}
	end
	items[#items + 1] = { id = "seed", label = "SEED  " .. (settings.seedText == "" and "RANDOM" or settings.seedText), action = function()
		self:edit(function() settings.seedText = randomSeedText() end)
	end }
	items[#items + 1] = { id = "randomise", label = "RANDOMISE SEED", action = function()
		self:edit(function() settings.seedText = randomSeedText() end)
	end }
	items[#items + 1] = { id = "start", label = "START", sound = "forward", action = function() self:start() end }
	items[#items + 1] = { id = "back", label = "BACK", sound = "back", action = self.onBack }
	self.items = items
		self.selected = math.min(self.selected or #items, #items)
	if previous and previous.id then
		for i, item in ipairs(items) do
			if item.id == previous.id then
				self.selected = i
			end
		end
	end
end

-- Runs one settings edit (which may refuse with a reason), then rebuilds the
-- rows and tells the flow.
function SetupState:edit(change)
	local ok, reason = change()
	if ok == false then
		self.notice = reason
	end
	self:refresh()
	self.flow:settingsChanged()
end

function SetupState:cycleBinding(slot, dir)
	self:edit(function()
		local ok, note = Roster.cycleBinding(self.settings.roster, slot, Compat.connectedPadIds(), dir)
		if ok then
			self.notice = note
			return true
		end
		return false, note or "NO OTHER BINDING"
	end)
end

function SetupState:start()
	if #self.problems > 0 then
		self.notice = self:problemText(self.problems[1])
		return
	end
	self.flow:start()
end

function SetupState:problemText(problem)
	return (problem.slot and ("SLOT " .. problem.slot .. ": ") or "") .. problem.reason
end

local function apply(self, action)
	self.notice = nil
	MenuNav.apply(self, action)
end

local function onSeedRow(self)
	return self.items[self.selected].id == "seed"
end

function SetupState:keypressed(key)
	if key == "backspace" and onSeedRow(self) then
		self.notice = nil
		self:edit(function() self.settings.seedText = self.settings.seedText:sub(1, -2) end)
		return
	end
	apply(self, MenuNav.fromKey(key))
end

function SetupState:textinput(text)
	local settings = self.settings
	if not onSeedRow(self) or not text:match("^%d$") then
		return
	end
	if #settings.seedText >= Config.setup.seedMaxDigits then
		self.notice = "SEED MAX " .. Config.setup.seedMaxDigits .. " DIGITS"
		return
	end
	self.notice = nil
	self:edit(function() settings.seedText = settings.seedText .. text end)
end

function SetupState:gamepadpressed(_, button)
	apply(self, MenuNav.fromButton(button))
end

function SetupState:gamepadaxis(_, axis, value)
	apply(self, self.stick:axis(axis, value))
end

-- An untouched keyboard default roster becomes the pad default once a pad is
-- connected; any edited or saved roster stays as it is.
function SetupState:adoptPadDefault()
	local pads = Compat.connectedPadIds()
	if #pads > 0 and Roster.isKeyboardDefault(self.settings.roster) then
		self.settings.roster = Roster.defaultSetup(pads)
		return true
	end
	return false
end

function SetupState:joystickadded()
	local swapped = self:adoptPadDefault()
	self:refresh()
	if swapped then
		self.flow:settingsChanged()
	end
end

function SetupState:joystickremoved()
	self:refresh()
end

function SetupState:shownNotice()
	local problem = self.problems[1]
	if problem then
		return self:problemText(problem), true
	end
	if self.notice then
		return self.notice, false
	end
	if onSeedRow(self) then
		return "TYPE DIGITS // [A] RANDOMISES", false
	end
	if self.warnings[1] then
		return self.warnings[1].reason, false
	end
	return nil, false
end

function SetupState:draw()
	local notice, alert = self:shownNotice()
	MenuRender.draw({ title = "SETUP", items = self.items, selected = self.selected, compact = true, notice = notice, alert = alert })
end

return SetupState
