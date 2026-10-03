-- Settings codec: the roster and hardcore setting as a small line-based text
-- (pure -- no `love.*`, no file access; src/app/settings_store.lua does the I/O).
--   gravity-settings 1
--   hardcore 1
--   slot <color> keyboard <layout> | gamepad <ordinal> | ai <level>
-- The seed is never encoded. decode never errors: garbage gives defaults.
local Config = require("src.game.config")
local Roster = require("src.game.roster")

local SettingsCodec = {}

local HEADER = "gravity-settings"
local VERSION = 1

local function bindingText(binding)
	if binding.kind == "keyboard" then
		return "keyboard " .. binding.layout
	elseif binding.kind == "gamepad" then
		return string.format("gamepad %d", binding.id)
	end
	return "ai " .. binding.level
end

function SettingsCodec.encode(settings)
	local lines = { HEADER .. " " .. VERSION, "hardcore " .. (settings.hardcore and "1" or "0") }
	for _, slot in ipairs(settings.roster) do
		lines[#lines + 1] = string.format("slot %d %s", slot.color, bindingText(slot.binding))
	end
	return table.concat(lines, "\n") .. "\n"
end

-- Makes a decoded roster valid: slot count and colours clamped or reassigned,
-- unknown or unavailable bindings rebound (see below).
function SettingsCodec.repair(roster, gamepads)
	if #roster < Config.players.min then
		return Roster.default()
	end
	for slot = #roster, Config.players.max + 1, -1 do
		roster[slot] = nil
	end
	local taken = {}
	for _, slot in ipairs(roster) do
		local color = slot.color
		if color < 1 or color > #Config.players.palette or taken[color] then
			slot.color = nil
		else
			taken[color] = true
		end
	end
	for _, slot in ipairs(roster) do
		if not slot.color then
			for color = 1, #Config.players.palette do
				if not taken[color] then
					taken[color] = true
					slot.color = color
					break
				end
			end
		end
	end
	local connected = {}
	for _, id in ipairs(gamepads or {}) do
		connected[id] = true
	end
	local validLayout, validLevel = {}, {}
	for _, layout in ipairs(Roster.LAYOUTS) do
		validLayout[layout] = true
	end
	for _, level in ipairs(Roster.AI_LEVELS) do
		validLevel[level] = true
	end

	-- A human binding is kept only when it is a known, connected, unclaimed
	-- device and the human limit allows it. The rest fall back to the next
	-- unused keyboard layout, else AI easy.
	local usedLayouts, usedPads, humans = {}, {}, 0
	local function keeps(binding)
		if binding.kind == "keyboard" then
			return validLayout[binding.layout] and not usedLayouts[binding.layout]
		end
		return binding.kind == "gamepad" and connected[binding.id] and not usedPads[binding.id]
	end
	local function claim(binding)
		if binding.kind == "keyboard" then
			usedLayouts[binding.layout] = true
		else
			usedPads[binding.id] = true
		end
		humans = humans + 1
	end
	local function fallback()
		if humans < Config.players.maxHumans then
			for _, layout in ipairs(Roster.LAYOUTS) do
				if not usedLayouts[layout] then
					local binding = { kind = "keyboard", layout = layout }
					claim(binding)
					return binding
				end
			end
		end
		return { kind = "ai", level = "easy" }
	end
	-- AI slots stay (an unknown level becomes easy); humans are resolved in slot order.
	for _, slot in ipairs(roster) do
		local binding = slot.binding
		if binding.kind == "ai" then
			if not validLevel[binding.level] then
				slot.binding = { kind = "ai", level = "easy" }
			end
		elseif binding.kind ~= "keyboard" and binding.kind ~= "gamepad" then
			slot.binding = nil
		elseif humans < Config.players.maxHumans and keeps(binding) then
			claim(binding)
		else
			slot.binding = nil
		end
	end
	for _, slot in ipairs(roster) do
		if not slot.binding then
			slot.binding = fallback()
		end
	end
	return roster
end

-- `gamepads` is the list of connected ordinals the roster is repaired against.
function SettingsCodec.decode(text, gamepads)
	if type(text) ~= "string" or text:match("^[^\n]*") ~= HEADER .. " " .. VERSION then
		return { roster = Roster.default(), hardcore = false }
	end
	local roster = {}
	local hardcore = false
	for line in text:gmatch("[^\n]+") do
		local color, kind, arg = line:match("^slot (%d+) (%a+) (%w+)$")
		if color then
			local binding
			if kind == "gamepad" then
				binding = { kind = kind, id = tonumber(arg) }
			elseif kind == "keyboard" then
				binding = { kind = kind, layout = arg }
			else
				binding = { kind = kind, level = arg }
			end
			roster[#roster + 1] = { color = tonumber(color), binding = binding }
		elseif line == "hardcore 1" then
			hardcore = true
		end
	end
	return { roster = SettingsCodec.repair(roster, gamepads), hardcore = hardcore }
end

return SettingsCodec
