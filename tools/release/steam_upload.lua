-- Generates the Steam build scripts for build/<platform>/ and uploads them with steamcmd.
--   luajit tools/release/steam_upload.lua [--dry-run]
-- Env: STEAMCMD (path to steamcmd; default: on PATH, else downloaded to build/cache), STEAM_USER (build account login; asked for if unset).
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

-- Each platform folder goes to its own depot, keeping its folder name so the launch options keep working.
-- Mapping the folder by name keeps build/cache, build/steam and the loose gravity.love off players' disks.
local function depot_script(depot_id, platform)
	return table.concat({
		'"DepotBuildConfig"',
		"{",
		'	"DepotID" "' .. depot_id .. '"',
		'	"ContentRoot" "' .. BUILD .. '"',
		'	"FileMapping"',
		"	{",
		'		"LocalPath" "' .. platform .. '/*"',
		'		"DepotPath" "' .. platform .. '"',
		'		"Recursive" "1"',
		"	}",
		-- Finder litter and Claude Code's write tracking (left behind when a session's working directory sits
		-- in a build folder); harmless, but no reason to ship either.
		'	"FileExclusion" "*.DS_Store"',
		'	"FileExclusion" "*.claude*"',
		"}",
		"",
	}, "\n")
end

local function app_script()
	local lines = {
		'"AppBuild"',
		"{",
		'	"AppID" "' .. steam.app_id .. '"',
		'	"Desc" "' .. Util.capture("git rev-parse --short HEAD") .. '"',
		'	"BuildOutput" "' .. SCRIPTS .. '/output"',
		'	"ContentRoot" "' .. BUILD .. '"',
		'	"SetLive" "' .. steam.branch .. '"',
		'	"Depots"',
		"	{",
	}
	for _, platform in ipairs(PLATFORMS) do
		local id = steam.depots[platform]
		lines[#lines + 1] = '		"' .. id .. '" "' .. SCRIPTS .. "/depot_" .. id .. '.vdf"'
	end
	lines[#lines + 1] = "	}"
	lines[#lines + 1] = "}"
	lines[#lines + 1] = ""
	return table.concat(lines, "\n")
end

-- A dry run is for checking the generated scripts, so it tolerates placeholders.
if not dry_run then
	check_id("steam.app_id", steam.app_id)
	for _, platform in ipairs(PLATFORMS) do
		check_id("steam.depots." .. platform, steam.depots[platform])
	end
end

for _, platform in ipairs(PLATFORMS) do
	if not Util.exists(BUILD .. "/" .. platform) then
		Util.fail("build/" .. platform .. " is missing; run tools/release/release.sh build first")
	end
end

run("mkdir -p " .. q(SCRIPTS .. "/output"))
-- Scripts from an earlier layout or app id would otherwise sit beside the new ones.
run("rm -f " .. q(SCRIPTS) .. "/depot_*.vdf " .. q(SCRIPTS) .. "/app_build_*.vdf")
for _, platform in ipairs(PLATFORMS) do
	local id = steam.depots[platform]
	write(SCRIPTS .. "/depot_" .. id .. ".vdf", depot_script(id, platform))
end
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
if not user or user == "" then
	io.write("Steam build account login: ")
	io.flush()
	user = (io.read("*l") or ""):gsub("^%s+", ""):gsub("%s+$", "")
end
if user == "" then Util.fail("no Steam user given; type one at the prompt or set STEAM_USER") end

run(q(steamcmd) .. " +login " .. q(user) .. " +run_app_build " .. q(app_path) .. " +quit")
