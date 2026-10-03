-- Roster: the ordered list of slots for one match (docs/CONTEXT.md "Roster",
-- "Slot", "Binding"). A slot is { color = palette index, binding = ... } with
-- binding { kind = "keyboard", layout } | { kind = "gamepad", id } |
-- { kind = "ai", level }. The slot index is the ship's `player`. Pure -- no
-- `love.*`. Limits and the palette live in config.players.
local Config = require("src.game.config")

local Roster = {}

-- Cycle order of the choosable bindings: keyboard layouts, then connected
-- gamepads (ascending ordinal), AI levels, then none (empty).
Roster.LAYOUTS = { "wasd", "arrows", "ijkl" }
Roster.AI_LEVELS = { "easy", "hard" }

-- The classic two-player match: two keyboard humans, colours 1 and 2.
function Roster.default()
	return {
		{ color = 1, binding = { kind = "keyboard", layout = "wasd" } },
		{ color = 2, binding = { kind = "keyboard", layout = "arrows" } },
	}
end

-- What setup edits: six rows (one per palette colour), wasd and arrows bound,
-- the rest empty ({ kind = "none" }).
function Roster.defaultSetup()
	local roster = {}
	for row = 1, Config.players.max do
		roster[row] = { color = row, binding = { kind = "none" } }
	end
	roster[1].binding = { kind = "keyboard", layout = "wasd" }
	roster[2].binding = { kind = "keyboard", layout = "arrows" }
	return roster
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

-- The match roster for a setup roster: a copy without the empty rows, so the
-- remaining slots' indexes are the player numbers.
function Roster.active(roster)
	local active = {}
	for _, entry in ipairs(Roster.copy(roster)) do
		if entry.binding.kind ~= "none" then
			active[#active + 1] = entry
		end
	end
	return active
end

function Roster.count(roster)
	return #roster
end

function Roster.isHuman(roster, slot)
	local binding = roster[slot] and roster[slot].binding
	return binding ~= nil and binding.kind ~= "ai" and binding.kind ~= "none"
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
	list[#list + 1] = { kind = "none" }
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

local function sameBinding(a, b)
	return a.kind == b.kind and (a.kind == "none" or (a.kind == "ai" and a.level == b.level) or sameDevice(a, b))
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
	if binding.kind == "ai" or binding.kind == "none" then
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

-- Gives `row` the next (dir 1) or previous (dir -1) palette colour; the row
-- that held it takes `row`'s old colour, so the colours stay a permutation.
function Roster.cycleColor(roster, row, dir)
	local size = #Config.players.palette
	local old = roster[row].color
	local color = (old - 1 + dir) % size + 1
	for _, other in ipairs(roster) do
		if other.color == color then
			other.color = old
		end
	end
	roster[row].color = color
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
		if sameBinding(binding, current) then
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
	local players = #Roster.active(roster)
	if players < Config.players.min then
		problems[#problems + 1] = { reason = "NEED AT LEAST " .. Config.players.min .. " PLAYERS" }
	elseif players > Config.players.max then
		problems[#problems + 1] = { reason = "MAX " .. Config.players.max .. " PLAYERS" }
	end
	if #Roster.humans(roster) < Config.players.minHumans then
		problems[#problems + 1] = { reason = "NEED AT LEAST " .. Config.players.minHumans .. " HUMAN" }
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

return Roster
