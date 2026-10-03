-- Roster: the ordered list of slots for one match (docs/CONTEXT.md "Roster",
-- "Slot", "Binding"). A slot is { color = palette index, binding = ... } with
-- binding { kind = "keyboard", layout } | { kind = "gamepad", id } |
-- { kind = "ai", level }. The slot index is the ship's `player`. Pure -- no
-- `love.*`. Limits and the palette live in config.players.
local Config = require("src.game.config")

local Roster = {}

-- Cycle order of the choosable bindings: keyboard layouts, then connected
-- gamepads (ascending ordinal), then AI levels.
Roster.LAYOUTS = { "wasd", "arrows", "ijkl" }
Roster.AI_LEVELS = { "easy", "medium", "hard" }

-- The classic two-player match: two keyboard humans, colours 1 and 2.
function Roster.default()
	return {
		{ color = 1, binding = { kind = "keyboard", layout = "wasd" } },
		{ color = 2, binding = { kind = "keyboard", layout = "arrows" } },
	}
end

-- An independent copy, so a running match never sees later setup edits.
function Roster.copy(roster)
	local copy = {}
	for slot, entry in ipairs(roster) do
		local binding = {}
		for key, value in pairs(entry.binding) do
			binding[key] = value
		end
		copy[slot] = { color = entry.color, binding = binding }
	end
	return copy
end

function Roster.count(roster)
	return #roster
end

function Roster.isHuman(roster, slot)
	local binding = roster[slot] and roster[slot].binding
	return binding ~= nil and binding.kind ~= "ai"
end

-- Slot indexes bound to a keyboard layout or gamepad, in slot order.
function Roster.humans(roster)
	local humans = {}
	for slot = 1, #roster do
		if Roster.isHuman(roster, slot) then
			humans[#humans + 1] = slot
		end
	end
	return humans
end

-- Every binding a slot can take. `gamepads` is a list of connected ordinals.
local function options(gamepads)
	local list = {}
	for _, layout in ipairs(Roster.LAYOUTS) do
		list[#list + 1] = { kind = "keyboard", layout = layout }
	end
	for _, id in ipairs(gamepads or {}) do
		list[#list + 1] = { kind = "gamepad", id = id }
	end
	for _, level in ipairs(Roster.AI_LEVELS) do
		list[#list + 1] = { kind = "ai", level = level }
	end
	return list
end

local function sameDevice(a, b)
	if a.kind ~= b.kind then
		return false
	end
	if a.kind == "keyboard" then
		return a.layout == b.layout
	end
	return a.kind == "gamepad" and a.id == b.id
end

local function humanCountExcluding(roster, slot)
	local count = 0
	for _, other in ipairs(Roster.humans(roster)) do
		if other ~= slot then
			count = count + 1
		end
	end
	return count
end

-- Why `binding` cannot go on `slot` (nil when it can). Keyboard layouts and
-- gamepads bind one slot; AI may repeat; at most maxHumans humans.
local function refusal(roster, slot, binding)
	if binding.kind == "ai" then
		return nil
	end
	if humanCountExcluding(roster, slot) >= Config.players.maxHumans then
		return "MAX " .. Config.players.maxHumans .. " HUMANS"
	end
	for other, entry in ipairs(roster) do
		if other ~= slot and sameDevice(entry.binding, binding) then
			return "ALREADY USED"
		end
	end
	return nil
end

local function firstFreeColor(roster)
	local taken = {}
	for _, slot in ipairs(roster) do
		taken[slot.color] = true
	end
	for color = 1, #Config.players.palette do
		if not taken[color] then
			return color
		end
	end
end

-- Appends a slot: first free colour, first free binding. `gamepads` lists the
-- connected ordinals. Returns true, or false and a reason.
function Roster.add(roster, gamepads)
	if #roster >= Config.players.max then
		return false, "MAX " .. Config.players.max .. " SLOTS"
	end
	local slot = #roster + 1
	for _, binding in ipairs(options(gamepads)) do
		if not refusal(roster, slot, binding) then
			roster[slot] = { color = firstFreeColor(roster), binding = binding }
			return true
		end
	end
end

-- Steps `slot` to the next (dir 1) or previous (dir -1) palette colour no
-- other slot holds.
function Roster.cycleColor(roster, slot, dir)
	local size = #Config.players.palette
	local taken = {}
	for other, entry in ipairs(roster) do
		if other ~= slot then
			taken[entry.color] = true
		end
	end
	local color = roster[slot].color
	for _ = 1, size do
		color = (color - 1 + dir) % size + 1
		if not taken[color] then
			roster[slot].color = color
			return
		end
	end
end

-- Steps `slot` to the next (dir 1) or previous (dir -1) binding it may take.
-- `gamepads` lists the connected ordinals. Returns true plus a reason when a
-- limit made it skip a choice (so the screen can say why), or false when no
-- other binding is available.
function Roster.cycleBinding(roster, slot, gamepads, dir)
	local list = options(gamepads)
	local current = roster[slot].binding
	local index = dir > 0 and 0 or #list + 1
	for i, binding in ipairs(list) do
		if sameDevice(binding, current) or (binding.kind == "ai" and current.kind == "ai" and binding.level == current.level) then
			index = i
		end
	end
	local note = nil
	for _ = 1, #list do
		index = (index - 1 + dir) % #list + 1
		local candidate = list[index]
		local reason = refusal(roster, slot, candidate)
		if not reason then
			roster[slot].binding = candidate
			return true, note
		elseif reason:find("HUMANS", 1, true) then
			note = reason
		end
	end
	return false, note
end

-- Everything that blocks Start: a list of { slot = n|nil, reason }, empty when
-- the roster is playable. `gamepads` lists the connected ordinals.
function Roster.validate(roster, gamepads)
	local problems = {}
	local connected = {}
	for _, id in ipairs(gamepads or {}) do
		connected[id] = true
	end
	if #roster < Config.players.min then
		problems[#problems + 1] = { reason = "NEED AT LEAST " .. Config.players.min .. " SLOTS" }
	elseif #roster > Config.players.max then
		problems[#problems + 1] = { reason = "MAX " .. Config.players.max .. " SLOTS" }
	end
	if #Roster.humans(roster) > Config.players.maxHumans then
		problems[#problems + 1] = { reason = "MAX " .. Config.players.maxHumans .. " HUMANS" }
	end
	for slot, entry in ipairs(roster) do
		local binding = entry.binding
		for earlier = 1, slot - 1 do
			if binding.kind ~= "ai" and sameDevice(roster[earlier].binding, binding) then
				local name = binding.kind == "keyboard" and ("KEYBOARD " .. binding.layout:upper()) or ("GAMEPAD " .. binding.id)
				problems[#problems + 1] = { slot = slot, reason = name .. " ALREADY USED" }
				break
			end
		end
		if binding.kind == "gamepad" and not connected[binding.id] then
			problems[#problems + 1] = { slot = slot, reason = "GAMEPAD " .. binding.id .. " DISCONNECTED" }
		end
	end
	return problems
end

-- Removes `slot`; later slots shift down (their index is the player number).
function Roster.remove(roster, slot)
	if #roster <= Config.players.min then
		return false, "NEED AT LEAST " .. Config.players.min .. " SLOTS"
	end
	table.remove(roster, slot)
	return true
end

return Roster
