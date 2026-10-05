-- Builds distributable bundles into build/<platform>/ for Steam.
--   luajit tools/release/build.lua [windows|macos|linux|all ...]
-- Run from the repo root (release.sh does). Needs curl, zip, unzip; macOS bundle edits use
-- PlistBuddy/codesign and are skipped with a warning when absent (i.e. building on Linux).
local Util = require("tools.release.util")
local config = require("tools.release.config")

local q, run = Util.quote, Util.run

local ROOT = Util.root()
local BUILD = ROOT .. "/build"
local CACHE = BUILD .. "/cache"
local LOVE_FILE = BUILD .. "/" .. config.exe_name .. ".love"

local function download(platform)
	local runtime = config.runtimes[platform]
	local url = runtime.url:format(config.love_version, config.love_version)
	local path = CACHE .. "/" .. url:match("[^/]+$")
	if not Util.exists(path) then
		run("mkdir -p " .. q(CACHE))
		run("curl -fL --retry 3 -o " .. q(path .. ".part") .. " " .. q(url))
		run("mv " .. q(path .. ".part") .. " " .. q(path))
	end
	-- Checked on every use, so a bad cached file fails too; delete build/cache to refetch it.
	local actual = Util.sha256(path)
	if actual ~= runtime.sha256 then
		Util.fail(("%s runtime does not match its pinned SHA-256\n  expected %s\n  actual   %s\n  delete %s to refetch, or update tools/release/config.lua if love_version changed"):format(platform, runtime.sha256, actual, path))
	end
	return path
end

local function fresh_dir(path)
	run("rm -rf " .. q(path))
	run("mkdir -p " .. q(path))
end

local function make_love()
	local stage = BUILD .. "/stage"
	fresh_dir(stage)
	for _, entry in ipairs(config.game_files) do
		if not Util.exists(ROOT .. "/" .. entry) then
			Util.fail("game file missing: " .. entry)
		end
		run("cp -R " .. q(ROOT .. "/" .. entry) .. " " .. q(stage .. "/"))
	end
	run("rm -f " .. q(LOVE_FILE))
	run("cd " .. q(stage) .. " && zip -q -r -X " .. q(LOVE_FILE) .. " . -x '*.DS_Store'")
	run("rm -rf " .. q(stage))
end

local builders = {}

-- love.exe with the .love appended is a self-contained exe; the DLLs sit beside it.
function builders.windows(out)
	local zip = download("windows")
	local tmp = BUILD .. "/tmp-windows"
	fresh_dir(tmp)
	run("unzip -q " .. q(zip) .. " -d " .. q(tmp))
	local src = tmp .. "/love-" .. config.love_version .. "-win64"
	fresh_dir(out)
	run("cat " .. q(src .. "/love.exe") .. " " .. q(LOVE_FILE) .. " > " .. q(out .. "/" .. config.exe_name .. ".exe"))
	run("cp " .. q(src) .. "/*.dll " .. q(src .. "/license.txt") .. " " .. q(out .. "/"))
	run("rm -rf " .. q(tmp))
end

-- love.app with the .love dropped into Resources/ runs as a fused game.
function builders.macos(out)
	local zip = download("macos")
	local tmp = BUILD .. "/tmp-macos"
	fresh_dir(tmp)
	run("unzip -q " .. q(zip) .. " -d " .. q(tmp))
	fresh_dir(out)
	local app = out .. "/" .. config.bundle_name .. ".app"
	run("mv " .. q(tmp .. "/love.app") .. " " .. q(app))
	run("rm -rf " .. q(tmp))
	run("cp " .. q(LOVE_FILE) .. " " .. q(app .. "/Contents/Resources/" .. config.exe_name .. ".love"))

	local plist = app .. "/Contents/Info.plist"
	local buddy = "/usr/libexec/PlistBuddy"
	if Util.exists(buddy) then
		local function set(key, value)
			run(buddy .. " -c " .. q("Set :" .. key .. " " .. value) .. " " .. q(plist))
		end
		set("CFBundleIdentifier", config.bundle_id)
		set("CFBundleName", config.bundle_name)
		-- LÖVE's file-type claims would make the game the handler for every .love file.
		Util.try(buddy .. " -c 'Delete :UTExportedTypeDeclarations' " .. q(plist))
		Util.try(buddy .. " -c 'Delete :CFBundleDocumentTypes' " .. q(plist))
	else
		print("warning: PlistBuddy not found; leaving love.app's Info.plist untouched")
	end

	-- Editing the bundle breaks LÖVE's signature, and Apple Silicon refuses to launch a bundle with
	-- a broken one. Ad-hoc signing ("-") repairs that locally; it is not Developer ID signing and
	-- does not satisfy Gatekeeper for downloads.
	if Util.try("command -v codesign >/dev/null 2>&1") then
		run("codesign --force --deep -s - " .. q(app))
	else
		print("warning: codesign not found; the macOS bundle will not launch on Apple Silicon")
	end

	-- The macOS runtime is the only one that can run on the build machine, so it gets a smoke test:
	-- the edited, re-signed bundle must start and report the pinned LÖVE version.
	if Util.capture("uname -s") == "Darwin" then
		local reported = Util.capture(q(app .. "/Contents/MacOS/love") .. " --version 2>&1")
		if not reported:find("LOVE " .. config.love_version, 1, true) then
			Util.fail("macOS bundle did not report LOVE " .. config.love_version .. " (got: " .. reported .. ")")
		end
		print("macOS bundle runs: " .. reported)
	else
		print("skipping the macOS bundle smoke test: needs a Mac")
	end
end

-- The AppImage can't be fused (it runs from a read-only mount), so ship it beside the .love with a launcher.
function builders.linux(out)
	local appimage = download("linux")
	fresh_dir(out)
	run("cp " .. q(appimage) .. " " .. q(out .. "/love.AppImage"))
	run("cp " .. q(LOVE_FILE) .. " " .. q(out .. "/" .. config.exe_name .. ".love"))
	local launcher = out .. "/" .. config.exe_name .. ".sh"
	local f = assert(io.open(launcher, "w"))
	f:write([[
#!/bin/sh
# FUSE is often missing on player machines, so unpack-and-run instead of mounting.
here="$(cd "$(dirname "$0")" && pwd)"
export APPIMAGE_EXTRACT_AND_RUN=1
exec "$here/love.AppImage" "$here/]] .. config.exe_name .. [[.love" "$@"
]])
	f:close()
	run("chmod +x " .. q(launcher) .. " " .. q(out .. "/love.AppImage"))
end

local ORDER = { "windows", "macos", "linux" }

local requested = {}
for _, name in ipairs(arg) do
	if name == "all" then
		requested = ORDER
		break
	end
	if not builders[name] then
		Util.fail("unknown platform '" .. name .. "' (windows, macos, linux, all)")
	end
	requested[#requested + 1] = name
end
if #requested == 0 then requested = ORDER end

run("mkdir -p " .. q(BUILD))
make_love()
for _, platform in ipairs(requested) do
	print("== " .. platform)
	builders[platform](BUILD .. "/" .. platform)
end
print("built: " .. table.concat(requested, ", ") .. " -> " .. BUILD)
