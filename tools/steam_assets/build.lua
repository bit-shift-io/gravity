-- steam=scout hands over to scout.lua. steam=build: validate the manifest, render every entry, write
-- steam-assets/<name>.png, exit. Everything renders before the first file is
-- written, so a failing entry leaves no partial output. LÖVE writes only to
-- its save directory, so the PNG bytes go out with plain io.open
-- (same route as tests/support/capture.lua).
local Manifest = require("tools.steam_assets.manifest")
local ManifestCheck = require("tools.steam_assets.manifest_check")
local Capture = require("tools.steam_assets.capture")

local Build = {}

local OUTPUT_DIR = "steam-assets"

local function fail(message)
	io.stderr:write("steam build failed: " .. message .. "\n")
	love.event.quit(1)
end

-- `args` are the launch arguments (scout reads seed=N from them).
function Build.run(mode, args)
	if mode == "scout" then
		return require("tools.steam_assets.scout").start(args)
	end
	if mode ~= "build" then
		return fail("unknown steam mode '" .. mode .. "'")
	end

	local ok, err = ManifestCheck.validate(Manifest)
	if not ok then
		return fail(err)
	end

	local rendered = {}
	for _, entry in ipairs(Manifest) do
		local rok, result = pcall(Capture.render, entry)
		if not rok then
			return fail(entry.name .. ": " .. tostring(result))
		end
		rendered[#rendered + 1] = { entry = entry, bytes = result:encode("png"):getString() }
	end

	os.execute(string.format('mkdir -p "%s"', OUTPUT_DIR))
	for _, item in ipairs(rendered) do
		local path = OUTPUT_DIR .. "/" .. item.entry.name .. ".png"
		local file = assert(io.open(path, "wb"))
		file:write(item.bytes)
		file:close()
		print(string.format("wrote %s (%dx%d)", path, item.entry.width, item.entry.height))
	end
	love.event.quit(0)
end

return Build
