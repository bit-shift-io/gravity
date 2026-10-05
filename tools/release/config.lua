-- Release settings. Edit the Steam ids here once the app exists in Steamworks.
return {
	exe_name = "gravity", -- file name stem for the windows exe, .love and linux launcher
	bundle_name = "gravity", -- macOS .app name and CFBundleName
	bundle_id = "bitshift.gravity",
	love_version = "11.5",

	-- Paths in the .love archive, relative to the repo root. Everything else (tests, docs, tools) stays out.
	game_files = { "main.lua", "conf.lua", "src", "res" },

	-- Official LÖVE runtimes, downloaded once into build/cache and checked against these SHA-256s.
	-- LÖVE publishes no checksums, so these were taken from the first official download of 11.5;
	-- recompute them when bumping love_version.
	runtimes = {
		windows = {
			url = "https://github.com/love2d/love/releases/download/%s/love-%s-win64.zip",
			sha256 = "ba6e56be2685e53c817749c4a5007f51137136fe5a3ab64920508babc2e74369",
		},
		macos = {
			url = "https://github.com/love2d/love/releases/download/%s/love-%s-macos.zip",
			sha256 = "6795bb3a1656af6a2fdfe741e150787b481886d3a280327a261a3fdded586913",
		},
		linux = {
			url = "https://github.com/love2d/love/releases/download/%s/love-%s-x86_64.AppImage",
			sha256 = "65a673406431eff7167a15a032bf7a2e4ba50108e091eb7b176465831f9b5e00",
		},
	},

	steam = {
		app_id = "5389400",
		-- One depot for every platform: build/ ships whole, so players get windows/, macos/ and linux/ side by side.
		-- Set the depot's OS to "All" in Steamworks and the launch options to windows/gravity.exe, macos/gravity.app, linux/gravity.sh.
		depot = "5389401",
		branch = "", -- steam branch to set live after upload; empty leaves the build unassigned
	},
}
