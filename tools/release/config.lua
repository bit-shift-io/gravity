-- Release settings. Edit the Steam ids here once the app exists in Steamworks.
return {
	exe_name = "gravity", -- file name stem for the windows exe, .love and linux launcher
	bundle_name = "gravity", -- macOS .app name and CFBundleName
	bundle_id = "au.com.jpmedia.gravity",
	love_version = "11.5",

	-- Paths in the .love archive, relative to the repo root. Everything else (tests, docs, tools) stays out.
	game_files = { "main.lua", "conf.lua", "src", "res" },

	-- Official LÖVE runtimes, downloaded once into build/cache.
	runtimes = {
		windows = { url = "https://github.com/love2d/love/releases/download/%s/love-%s-win64.zip" },
		macos = { url = "https://github.com/love2d/love/releases/download/%s/love-%s-macos.zip" },
		linux = { url = "https://github.com/love2d/love/releases/download/%s/love-%s-x86_64.AppImage" },
	},

	steam = {
		app_id = "REPLACE_APP_ID",
		-- One depot per platform. Each depot ships build/<platform>/.
		depots = {
			windows = "REPLACE_WINDOWS_DEPOT_ID",
			macos = "REPLACE_MACOS_DEPOT_ID",
			linux = "REPLACE_LINUX_DEPOT_ID",
		},
		branch = "", -- steam branch to set live after upload; empty leaves the build unassigned
	},
}
