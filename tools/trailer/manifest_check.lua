-- Pure trailer manifest validation (no `love.*`). Errors name the offending
-- shot so a bad manifest aborts the build before anything renders.
local Roster = require("src.game.roster")
local Keyframes = require("tools.trailer.keyframes")
local Text = require("tools.trailer.text")
local Timeline = require("tools.trailer.timeline")

local ManifestCheck = {}

local function isAiLevel(level)
	for _, known in ipairs(Roster.AI_LEVELS) do
		if level == known then
			return true
		end
	end
	return false
end

local function label(shot, index)
	if type(shot) == "table" and type(shot.name) == "string" and shot.name ~= "" then
		return shot.name
	end
	return "shot #" .. index
end

local function isInt(value)
	return type(value) == "number" and value == math.floor(value)
end

local function isView(view)
	return type(view) == "table"
		and type(view.x) == "number"
		and type(view.y) == "number"
		and type(view.zoom) == "number"
		and view.zoom > 0
end

-- A camera is one fixed view, or a list of keyframes (see keyframes.lua).
local function cameraProblem(camera, name)
	if type(camera) == "table" and camera[1] ~= nil then
		local previous
		for index, key in ipairs(camera) do
			if not isView(key) then
				return string.format("%s: camera key %d needs numeric x, y and a positive zoom", name, index)
			end
			if type(key.t) ~= "number" or key.t < 0 or key.t > 1 then
				return string.format("%s: camera key %d t must be between 0 and 1", name, index)
			end
			if key.ease ~= nil and not Keyframes.EASES[key.ease] then
				return string.format("%s: camera key %d ease must be linear, in, out or inOut", name, index)
			end
			if previous and key.t <= previous then
				return string.format("%s: camera key %d t must be greater than the previous key's", name, index)
			end
			previous = key.t
		end
		return nil
	end
	if not isView(camera) then
		return name .. ": camera needs numeric x, y and a positive zoom"
	end
	return nil
end

-- Returns the first problem as a string, or nil when the shot is fine.
local function problem(shot, name)
	for _, field in ipairs({ "name", "seed", "roster", "from", "to" }) do
		if shot[field] == nil or shot[field] == false then
			return string.format("%s: missing field '%s'", name, field)
		end
	end
	if type(shot.seed) ~= "number" then
		return name .. ": seed must be a number"
	end
	if type(shot.roster) ~= "table" or #shot.roster < 2 or #shot.roster > 6 then
		return name .. ": roster needs 2-6 slots"
	end
	for slot, entry in ipairs(shot.roster) do
		local binding = type(entry) == "table" and entry.binding
		if type(binding) ~= "table" or binding.kind ~= "ai" or not isAiLevel(binding.level) then
			return string.format("%s: roster slot %d needs an AI binding with level %s", name, slot,
				table.concat(Roster.AI_LEVELS, " or "))
		end
	end
	if not isInt(shot.from) or shot.from < 0 then
		return name .. ": from must be a non-negative integer"
	end
	if not isInt(shot.to) or shot.to <= shot.from then
		return name .. ": to must be greater than from"
	end
	local speed = shot.speed or 1
	if not isInt(speed) or speed < 1 then
		return name .. ": speed must be a positive integer"
	end
	if (shot.to - shot.from) % speed ~= 0 then
		return name .. ": to - from must be a multiple of speed"
	end
	local camera = shot.camera
	if camera ~= nil then
		local err = cameraProblem(camera, name)
		if err then
			return err
		end
	end
	for _, field in ipairs({ "fadeIn", "fadeOut" }) do
		local fade = shot[field]
		if fade ~= nil and (type(fade) ~= "number" or fade < 0) then
			return string.format("%s: %s must be a number of seconds, 0 or more", name, field)
		end
	end
	local fades = (shot.fadeIn or 0) + (shot.fadeOut or 0)
	local seconds = (shot.to - shot.from) / speed / 60
	if fades > seconds then
		return string.format("%s: fadeIn + fadeOut (%gs) is longer than the shot (%gs)", name, fades, seconds)
	end
	for index, caption in ipairs(shot.captions or {}) do
		if type(caption.text) ~= "string" or caption.text == "" then
			return string.format("%s: caption %d needs text", name, index)
		end
		if type(caption.from) ~= "number" or type(caption.to) ~= "number" or caption.to <= caption.from then
			return string.format("%s: caption %d needs numeric from and a later to", name, index)
		end
		if caption.anchor ~= nil and not Text.ANCHORS[caption.anchor] then
			return string.format("%s: caption %d anchor must be top, center, bottom or lowerLeft", name, index)
		end
		if caption.from < 0 or caption.to > seconds then
			return string.format("%s: caption %d must lie within the shot (0 to %gs)", name, index, seconds)
		end
	end
	for _, flag in ipairs({ "hud", "glow", "crt" }) do
		if shot[flag] ~= nil and type(shot[flag]) ~= "boolean" then
			return string.format("%s: %s must be true or false", name, flag)
		end
	end
	return nil
end

-- A sequence card { card, seconds, sub?, fadeIn?, fadeOut? }: the first
-- problem as a string, or nil.
local function cardProblem(card)
	if type(card.card) ~= "string" or card.card == "" then
		return "card needs text"
	end
	if type(card.seconds) ~= "number" or card.seconds <= 0 then
		return "card seconds must be greater than 0"
	end
	if card.sub ~= nil and (type(card.sub) ~= "string" or card.sub == "") then
		return "card sub must be non-empty text"
	end
	for _, field in ipairs({ "fadeIn", "fadeOut" }) do
		local fade = card[field]
		if fade ~= nil and (type(fade) ~= "number" or fade < 0) then
			return field .. " must be a number of seconds, 0 or more"
		end
	end
	if (card.fadeIn or 0) + (card.fadeOut or 0) > card.seconds then
		return "fadeIn + fadeOut is longer than the card"
	end
	return nil
end

-- Defaults for a music bed's optional fields (see docs/TRAILER.md).
ManifestCheck.MUSIC_DEFAULTS = { volume = 0.3, fadeOut = 1 }

-- `length` (seconds) is the trailer's length; it must match the sequence to
-- within one frame. Returns the first problem as a string, or nil.
local function lengthProblem(manifest)
	local length = manifest.length
	if length == nil then
		if manifest.music ~= nil then
			return "music needs length (the trailer's length in seconds)"
		end
		return nil
	end
	if type(length) ~= "number" or length <= 0 then
		return "length must be greater than 0 seconds"
	end
	local total = Timeline.duration(Timeline.build({ shots = manifest.shots, sequence = manifest.sequence or {} }))
	if math.abs(total - length) * Timeline.FPS > 1 then
		return string.format("length is %gs but the sequence runs %gs", length, total)
	end
	return nil
end

-- The music bed's first problem as a string, or nil.
local function musicProblem(music, length)
	if type(music) ~= "table" then
		return "music must be a table with a path"
	end
	if type(music.path) ~= "string" or music.path == "" then
		return "music needs a path"
	end
	if music.volume ~= nil and (type(music.volume) ~= "number" or music.volume <= 0) then
		return "music volume must be greater than 0"
	end
	if music.fadeOut ~= nil and (type(music.fadeOut) ~= "number" or music.fadeOut < 0) then
		return "music fadeOut must be a number of seconds, 0 or more"
	end
	if music.start ~= nil and (type(music.start) ~= "number" or music.start < 0) then
		return "music start must be a number of seconds, 0 or more"
	end
	if music.fadeOut ~= nil and length ~= nil and music.fadeOut > length then
		return string.format("music fadeOut (%gs) is longer than length (%gs)", music.fadeOut, length)
	end
	return nil
end

-- ok, err. `manifest` is the trailer manifest table.
function ManifestCheck.validate(manifest)
	local seen = {}
	for index, shot in ipairs(manifest.shots) do
		local name = label(shot, index)
		local err = problem(shot, name)
		if err then
			return false, err
		end
		if seen[shot.name] then
			return false, name .. ": duplicate name"
		end
		seen[shot.name] = true
	end
	for index, item in ipairs(manifest.sequence or {}) do
		if type(item) == "table" then
			local err = cardProblem(item)
			if err then
				return false, string.format("sequence item %d: %s", index, err)
			end
		elseif not seen[item] then
			return false, string.format("sequence item %d: no shot named '%s'", index, tostring(item))
		end
	end
	local lengthErr = lengthProblem(manifest)
	if lengthErr then
		return false, lengthErr
	end
	if manifest.music ~= nil then
		local err = musicProblem(manifest.music, manifest.length)
		if err then
			return false, err
		end
	end
	return true
end

return ManifestCheck
