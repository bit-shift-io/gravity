-- UI font: Kernel Panic NBP (res/fnt, CC BY-SA, credited in README.md).
-- Fonts are created once per size and cached; `love.*` is only touched on
-- first use of a size.
local Fonts = {}

local PATH = "res/fnt/KernelPanicNbp-LyG3.ttf"

local cache = {}

-- Font at a pixel size. Falls back to LÖVE's default font of that size if the
-- file is missing, so a bad install never crashes a draw call.
function Fonts.get(size)
	local font = cache[size]
	if not font then
		local ok, loaded = pcall(love.graphics.newFont, PATH, size)
		font = ok and loaded or love.graphics.newFont(size)
		cache[size] = font
	end
	return font
end

return Fonts
