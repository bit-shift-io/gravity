-- Reads and writes the persisted settings (roster, hardcore, sound, postMode,
-- fullscreen) in the LÖVE save directory. Encoding and repair live in
-- src/game/settings_codec.lua; this is only the `love.filesystem` edge.
-- Neither call ever errors: a missing, unreadable or corrupt file loads
-- defaults, a failed write is logged.
local Compat = require("src.app.compat")
local SettingsCodec = require("src.game.settings_codec")

local SettingsStore = {}

SettingsStore.PATH = "settings.txt"

local function connectedPads()
	local ids = {}
	for ordinal in pairs(Compat.getJoysticks()) do
		ids[#ids + 1] = ordinal
	end
	table.sort(ids)
	return ids
end

-- { roster, hardcore, sound, postMode, fullscreen }, repaired against the
-- pads connected right now.
function SettingsStore.load()
	local text = nil
	if love.filesystem.getInfo(SettingsStore.PATH) then
		text = love.filesystem.read(SettingsStore.PATH)
	end
	return SettingsCodec.decode(text, connectedPads())
end

-- Saves settings.roster, settings.hardcore, settings.sound, settings.postMode,
-- and settings.fullscreen (never the seed).
function SettingsStore.save(settings)
	local ok, err = love.filesystem.write(SettingsStore.PATH, SettingsCodec.encode(settings))
	if not ok then
		print("could not save settings: " .. tostring(err))
	end
end

return SettingsStore
