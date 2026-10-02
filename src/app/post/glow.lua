-- Glow: bright pass at half resolution, separable blur ping-ponged between two
-- canvases, then added over the window. Owns its canvases and shaders.
local Compat = require("src.app.compat")
local GlowMath = require("src.app.post.glow_math")

local Glow = {}

local SHADER_DIR = "src/app/post/shaders/"

local brightShader, blurShader
local canvasA, canvasB
local halfW, halfH = 0, 0

local function loadShader(name)
	return Compat.newShader(love.filesystem.read(SHADER_DIR .. name))
end

-- Rebuild only on size change; release the old canvases first (no leak).
local function ensureCanvases(width, height)
	local w, h = GlowMath.halfSize(width, height)
	if canvasA and w == halfW and h == halfH then
		return
	end
	if canvasA then
		canvasA:release()
		canvasB:release()
	end
	canvasA = Compat.newCanvas(w, h, "linear")
	canvasB = Compat.newCanvas(w, h, "linear")
	halfW, halfH = w, h
end

local function blurPass(from, to, dx, dy, spacing, weights)
	love.graphics.setCanvas(to)
	love.graphics.clear(0, 0, 0, 1)
	love.graphics.setShader(blurShader)
	blurShader:send("weights", unpack(weights))
	blurShader:send("tapStep", { dx * spacing / halfW, dy * spacing / halfH })
	love.graphics.draw(from)
	love.graphics.setShader()
end

-- Build the blurred bright layer from `source` (the scene canvas, `width` x
-- `height`). `fitScale` is Screen.fit's scale; `cfg` is Config.post.glow.
local function render(source, width, height, fitScale, cfg)
	brightShader = brightShader or loadShader("bright_pass.glsl")
	blurShader = blurShader or loadShader("blur.glsl")
	ensureCanvases(width, height)

	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.setCanvas(canvasA)
	love.graphics.clear(0, 0, 0, 1)
	love.graphics.setShader(brightShader)
	brightShader:send("threshold", cfg.threshold)
	brightShader:send("texel", { 1 / width, 1 / height })
	love.graphics.draw(source, 0, 0, 0, halfW / width, halfH / height)
	love.graphics.setShader()

	local spacing = GlowMath.tapSpacing(cfg.radius, fitScale)
	local weights = GlowMath.weights()
	for _ = 1, cfg.passes do
		blurPass(canvasA, canvasB, 1, 0, spacing, weights)
		blurPass(canvasB, canvasA, 0, 1, spacing, weights)
	end
	love.graphics.setCanvas()
end

-- Build the glow layer. Leaves the window as the current canvas.
Glow.render = render

-- Add the already-rendered glow layer over the current canvas at (x, y).
function Glow.add(width, height, cfg, x, y)
	love.graphics.setColor(cfg.strength, cfg.strength, cfg.strength, 1)
	love.graphics.setBlendMode("add", "premultiplied")
	love.graphics.draw(canvasA, x, y, 0, width / halfW, height / halfH)
	love.graphics.setBlendMode("alpha")
	love.graphics.setColor(1, 1, 1, 1)
end

-- Render and add the glow of `source` over the window at (x, y). Call with the
-- window as the current canvas, after the scene has been blitted.
function Glow.draw(source, width, height, fitScale, cfg, x, y)
	render(source, width, height, fitScale, cfg)
	Glow.add(width, height, cfg, x, y)
end

return Glow
