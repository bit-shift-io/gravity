-- Generates the Steam build scripts for build/<platform>/ and uploads them with steamcmd.
--   luajit tools/release/steam_upload.lua [--dry-run]
-- Env: STEAMCMD (path to steamcmd; default: on PATH, else downloaded to build/cache), STEAM_USER (build account login).
-- steamcmd asks for the password and Steam Guard code itself; they never pass through here.
local Util = require("tools.release.util")
local config = require("tools.release.config")

local q, run = Util.quote, Util.run
local steam = config.steam

local dry_run = false
for _, a in ipairs(arg) do
	if a == "--dry-run" then dry_run = true else Util.fail("unknown argument '" .. a .. "'") end
end

local ROOT = Util.root()
local BUILD = ROOT .. "/build"
local SCRIPTS = BUILD .. "/steam"
local PLATFORMS = { "windows", "macos", "linux" }

local function check_id(label, value)
	if not tostring(value):match("^%d+$") then
		Util.fail(label .. " is still a placeholder (" .. tostring(value) .. "); set it in tools/release/config.lua")
	end
end

local function write(path, text)
	local f = assert(io.open(path, "w"))
	f:write(text)
	f:close()
end

-- One depot holds every platform folder side by side. Mapping the folders by name keeps build/cache,
-- build/steam and the loose gravity.love off players' disks; the .love inside each platform folder stays.
local function depot_script(depot_id)
	local lines = {
		'"DepotBuildConfig"',
		"{",
		'	"DepotID" "' .. depot_id .. '"',
		'	"ContentRoot" "' .. BUILD .. '"',
	}
	for _, platform in ipairs(PLATFORMS) do
		lines[#lines + 1] = '	"FileMapping"'
		lines[#lines + 1] = "	{"
		lines[#lines + 1] = '		"LocalPath" "' .. platform .. '/*"'
		lines[#lines + 1] = '		"DepotPath" "' .. platform .. '"'
		lines[#lines + 1] = '		"Recursive" "1"'
		lines[#lines + 1] = "	}"
	end
	lines[#lines + 1] = "}"
	lines[#lines + 1] = ""
	return table.concat(lines, "\n")
end

local function app_script()
	return table.concat({
		'"AppBuild"',
		"{",
		'	"AppID" "' .. steam.app_id .. '"',
		'	"Desc" "' .. Util.capture("git rev-parse --short HEAD") .. '"',
		'	"BuildOutput" "' .. SCRIPTS .. '/output"',
		'	"ContentRoot" "' .. BUILD .. '"',
		'	"SetLive" "' .. steam.branch .. '"',
		'	"Depots"',
		"	{",
		'		"' .. steam.depot .. '" "' .. SCRIPTS .. "/depot_" .. steam.depot .. '.vdf"',
		"	}",
		"}",
		"",
	}, "\n")
end

-- A dry run is for checking the generated scripts, so it tolerates placeholders.
if not dry_run then
	check_id("steam.app_id", steam.app_id)
	check_id("steam.depot", steam.depot)
end

for _, platform in ipairs(PLATFORMS) do
	if not Util.exists(BUILD .. "/" .. platform) then
		Util.fail("build/" .. platform .. " is missing; run tools/release/release.sh build first")
	end
end

run("mkdir -p " .. q(SCRIPTS .. "/output"))
-- Scripts from an earlier layout or app id would otherwise sit beside the new ones.
run("rm -f " .. q(SCRIPTS) .. "/depot_*.vdf " .. q(SCRIPTS) .. "/app_build_*.vdf")
write(SCRIPTS .. "/depot_" .. steam.depot .. ".vdf", depot_script(steam.depot))
local app_path = SCRIPTS .. "/app_build_" .. steam.app_id .. ".vdf"
write(app_path, app_script())
print("wrote Steam scripts to " .. SCRIPTS)

if dry_run then
	print("dry run: not uploading")
	return
end

-- Valve's own installer archives; steamcmd.sh updates itself on first run.
local STEAMCMD_ARCHIVES = {
	Darwin = "steamcmd_osx.tar.gz",
	Linux = "steamcmd_linux.tar.gz",
}

local function download_steamcmd()
	local archive = STEAMCMD_ARCHIVES[Util.capture("uname -s")]
	if not archive then Util.fail("no steamcmd download for this OS; install it or set STEAMCMD") end
	local dir = BUILD .. "/cache/steamcmd"
	local script = dir .. "/steamcmd.sh"
	if not Util.exists(script) then
		run("mkdir -p " .. q(dir))
		run("curl -fL --retry 3 -o " .. q(dir .. "/" .. archive) .. " https://steamcdn-a.akamaihd.net/client/installer/" .. archive)
		run("tar -xzf " .. q(dir .. "/" .. archive) .. " -C " .. q(dir))
	end
	return script
end

-- STEAMCMD, then PATH, then a copy downloaded into build/cache.
local steamcmd = os.getenv("STEAMCMD")
if not steamcmd or steamcmd == "" then steamcmd = Util.capture("command -v steamcmd") end
if steamcmd == "" then steamcmd = download_steamcmd() end
local user = os.getenv("STEAM_USER")
if not user or user == "" then Util.fail("set STEAM_USER to the Steam build account login") end

run(q(steamcmd) .. " +login " .. q(user) .. " +run_app_build " .. q(app_path) .. " +quit")
