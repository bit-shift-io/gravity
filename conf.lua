function love.conf(t)
	-- macOS lists one wired Xbox pad twice: the HID device and a duplicate from Apple's
	-- GameController (MFI) backend, which would put one pad in two roster slots. SDL
	-- reads this hint at init, so it has to be set here, before love.joystick loads.
	local ok, ffi = pcall(require, "ffi")
	if ok and ffi.os == "OSX" then
		ffi.cdef("int setenv(const char *name, const char *value, int overwrite);")
		ffi.C.setenv("SDL_JOYSTICK_MFI", "0", 1)
	end

	t.graphics = t.graphics or {} -- LÖVE 12 graphics startup options; keeps 11.5 working (docs/memory/love-11-and-12-compat.md)

	t.identity = "gravty"
	t.window.title = "GRAV//TY"
	t.window.width = 1280
	t.window.height = 720
	t.window.resizable = true
	t.window.minwidth = 1
	t.window.minheight = 1
	t.window.vsync = 1
end
