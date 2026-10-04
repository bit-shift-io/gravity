-- Pure manifest validation (no `love.*`). Errors name the offending entry so a
-- bad manifest aborts the build before any file is written.
local Logo = require("tools.steam_assets.logo")

local ManifestCheck = {}

local function isInt(value)
	return type(value) == "number" and value == math.floor(value)
end

local function label(entry, index)
	if type(entry) == "table" and type(entry.name) == "string" and entry.name ~= "" then
		return entry.name
	end
	return "entry #" .. index
end

-- Returns the first problem as a string, or nil when the entry is fine.
local function problem(entry, name)
	for _, field in ipairs({ "name", "width", "height", "seed", "step", "roster" }) do
		if not entry[field] then
			return string.format("%s: missing field '%s'", name, field)
		end
	end
	if not isInt(entry.width) or entry.width <= 0 then
		return name .. ": width must be a positive integer"
	end
	if not isInt(entry.height) or entry.height <= 0 then
		return name .. ": height must be a positive integer"
	end
	if type(entry.seed) ~= "number" then
		return name .. ": seed must be a number"
	end
	if not isInt(entry.step) or entry.step < 0 then
		return name .. ": step must be a non-negative integer"
	end
	if type(entry.roster) ~= "table" or #entry.roster < 2 then
		return name .. ": roster needs at least 2 slots"
	end
	local camera = entry.camera
	if camera ~= nil then
		if
			type(camera) ~= "table"
			or type(camera.x) ~= "number"
			or type(camera.y) ~= "number"
			or type(camera.zoom) ~= "number"
			or camera.zoom <= 0
		then
			return name .. ": camera needs numeric x, y and a positive zoom"
		end
	end
	for _, flag in ipairs({ "hud", "glow", "crt" }) do
		if entry[flag] ~= nil and type(entry[flag]) ~= "boolean" then
			return string.format("%s: %s must be true or false", name, flag)
		end
	end
	if entry.overlay ~= nil then
		if entry.overlay ~= "logo" then
			return name .. ': overlay must be "logo"'
		end
		if not Logo.anchors[entry.logoAnchor] then
			return string.format("%s: logoAnchor '%s' is not a known anchor", name, tostring(entry.logoAnchor))
		end
		if type(entry.logoSize) ~= "number" or entry.logoSize <= 0 or entry.logoSize > 1 then
			return name .. ": logoSize must be above 0 and at most 1"
		end
	end
	if entry.transparent ~= nil then
		if entry.transparent ~= true and entry.transparent ~= false then
			return name .. ": transparent must be true or false"
		end
		if entry.transparent and entry.overlay ~= "logo" then
			return name .. ': transparent needs overlay = "logo"'
		end
		if entry.transparent and (entry.width > 1280 or entry.height > 720) then
			return name .. ": transparent logo must fit 1280x720"
		end
	end
	if entry.icon ~= nil then
		if entry.icon ~= true and entry.icon ~= false then
			return name .. ": icon must be true or false"
		end
		if entry.icon and entry.width ~= entry.height then
			return name .. ": icon must be a square"
		end
		if entry.icon and entry.overlay ~= nil then
			return name .. ": icon cannot have an overlay"
		end
	end
	if entry.glyphScale ~= nil then
		if type(entry.glyphScale) ~= "number" or entry.glyphScale <= 0 or entry.glyphScale > 1 then
			return name .. ": glyphScale must be a number above 0 and at most 1"
		end
		if not entry.icon then
			return name .. ": glyphScale only applies to icons"
		end
	end
	return nil
end

-- ok, err. `entries` is the manifest list.
function ManifestCheck.validate(entries)
	local seen = {}
	for index, entry in ipairs(entries) do
		local name = label(entry, index)
		local err = problem(entry, name)
		if err then
			return false, err
		end
		if seen[entry.name] then
			return false, name .. ": duplicate name"
		end
		seen[entry.name] = true
	end
	return true
end

return ManifestCheck
