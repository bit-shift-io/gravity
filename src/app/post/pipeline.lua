-- Post pipeline: the match is drawn into a canvas sized to the game
-- rectangle, then the canvas is drawn to the window at the rectangle's
-- offset. Effects are passthrough for now. Order is fixed scene -> glow -> CRT.
-- Letterbox bars are never processed (plain black).
local Compat = require("src.app.compat")
local Screen = require("src.app.screen")
local PostMode = require("src.app.post.post_mode")
local Glow = require("src.app.post.glow")
local Config = require("src.game.config")

local Pipeline = {}

Pipeline.canvas = nil
Pipeline.width = 0
Pipeline.height = 0
Pipeline.composite = nil -- scene + glow, only built in CRT mode
local crtShader

-- Pixel size of the game rectangle in `fit` (Screen.fit): rounded, at least
-- 1x1 so a minimised window never asks for a 0-sized canvas.
function Pipeline.canvasSize(fit)
	local w = math.max(1, math.floor(Screen.VIRTUAL_WIDTH * fit.scale + 0.5))
	local h = math.max(1, math.floor(Screen.VIRTUAL_HEIGHT * fit.scale + 0.5))
	return w, h
end

-- Rebuild only when the pixel size changed, never per frame.
local function ensureCanvas(width, height)
	if Pipeline.canvas and Pipeline.width == width and Pipeline.height == height then
		return
	end
	if Pipeline.canvas then
		Pipeline.canvas:release()
	end
	if Pipeline.composite then
		Pipeline.composite:release()
		Pipeline.composite = nil
	end
	Pipeline.canvas = Compat.newCanvas(width, height)
	Pipeline.width = width
	Pipeline.height = height
end

-- CRT: composite scene + glow into a game-rectangle canvas, then draw that
-- through the CRT shader onto the window. The window stays untouched outside
-- the game rectangle, so bars stay black.
local function drawCrt(fit, width, height, x, y)
	crtShader = crtShader or Compat.newShader(love.filesystem.read("src/app/post/shaders/crt.glsl"))
	if not Pipeline.composite then
		Pipeline.composite = Compat.newCanvas(width, height, "linear")
	end
	local glowCfg, cfg = Config.post.glow, Config.post.crt

	-- Glow.render ends with the window as the target; do it before ours.
	Glow.render(Pipeline.canvas, width, height, fit.scale, glowCfg)
	love.graphics.setCanvas(Pipeline.composite)
	love.graphics.clear(0, 0, 0, 1)
	love.graphics.draw(Pipeline.canvas, 0, 0)
	Glow.add(width, height, glowCfg, 0, 0)
	love.graphics.setCanvas()

	love.graphics.setShader(crtShader)
	crtShader:send("aspect", width / height)
	crtShader:send("curvature", cfg.curvature)
	crtShader:send("cornerRadius", cfg.cornerRadius)
	crtShader:send("vignette", cfg.vignette)
	crtShader:send("heightPx", height)
	crtShader:send("scanlineIntensity", cfg.scanlineIntensity)
	crtShader:send("scanlinePitch", cfg.scanlinePitch)
	crtShader:send("grain", cfg.grain)
	crtShader:send("grainTime", love.timer.getTime())
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.draw(Pipeline.composite, x, y)
	love.graphics.setShader()
end

-- Draw the scene into the canvas via `drawScene` (called with the fit scale
-- already applied), then blit it to the window. `mode` is a PostMode value;
-- effects are passthrough so every mode currently looks the same.
function Pipeline.draw(fit, mode, drawScene)
	local width, height = Pipeline.canvasSize(fit)
	ensureCanvas(width, height)

	love.graphics.setCanvas(Pipeline.canvas)
	love.graphics.clear(0, 0, 0, 1)
	love.graphics.push()
	love.graphics.scale(fit.scale, fit.scale)
	drawScene()
	love.graphics.pop()
	love.graphics.setCanvas()

	-- Scale 1 at integer offsets keeps the picture sharp.
	love.graphics.setColor(1, 1, 1, 1)
	local x, y = math.floor(fit.offsetX + 0.5), math.floor(fit.offsetY + 0.5)

	if PostMode.has(mode, "crt") then
		drawCrt(fit, width, height, x, y)
		return
	end

	love.graphics.draw(Pipeline.canvas, x, y)
	if PostMode.has(mode, "glow") then
		Glow.draw(Pipeline.canvas, width, height, fit.scale, Config.post.glow, x, y)
	end
end

return Pipeline
