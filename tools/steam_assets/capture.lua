-- Renders one manifest entry into its own canvas at the entry's pixel size and
-- returns the ImageData. Never calls Pipeline.draw, so canvases never nest
-- (docs/memory/steam-capture-own-canvas.md). Dev-only; uses `love.*`.
local Compat = require("src.app.compat")
local Starfield = require("src.app.render.starfield")
local MatchState = require("src.app.states.match_state")
local Framing = require("tools.steam_assets.framing")
local Scene = require("tools.steam_assets.scene")
local Flags = require("tools.steam_assets.flags")
local Logo = require("tools.steam_assets.logo")
local Monogram = require("tools.steam_assets.monogram")
local Hud = require("src.app.render.hud")
local ScoreCard = require("src.app.render.score_card")
local MatchOver = require("src.app.render.match_over")
local Glow = require("src.app.post.glow")
local SettingsStore = require("src.app.settings_store")
local Config = require("src.game.config")

local Capture = {}

local crtShader

local ICON_CORNER_RADIUS = 0.18 -- of the icon's side

-- Glow of `scene` added back onto it. Glow.render leaves the window as the
-- target, so callers set their own target afterwards.
local function addGlow(scene, width, height, uiScale)
	local cfg = Config.post.glow
	Glow.render(scene, width, height, uiScale, cfg)
	love.graphics.setCanvas(scene)
	Glow.add(width, height, cfg, 0, 0)
	love.graphics.setCanvas()
end

-- Draw `scene` through the CRT shader into `out`. grainTime is a parameter so
-- a still always gives the same image and a video frame can animate the grain.
local function applyCrt(scene, out, width, height, grainTime)
	crtShader = crtShader or Compat.newShader(love.filesystem.read("src/app/post/shaders/crt.glsl"))
	local cfg = Config.post.crt
	love.graphics.setCanvas(out)
	love.graphics.clear(0, 0, 0, 1)
	love.graphics.setShader(crtShader)
	crtShader:send("aspect", width / height)
	crtShader:send("curvature", cfg.curvature)
	crtShader:send("cornerRadius", cfg.cornerRadius)
	crtShader:send("vignette", cfg.vignette)
	crtShader:send("heightPx", height)
	crtShader:send("scanlineIntensity", cfg.scanlineIntensity)
	crtShader:send("scanlinePitch", cfg.scanlinePitch)
	crtShader:send("grain", cfg.grain)
	crtShader:send("grainTime", grainTime)
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.draw(scene, 0, 0)
	love.graphics.setShader()
	love.graphics.setCanvas()
	return out
end

-- Canvases for drawing frames of width x height. Reuse one set across the
-- frames of a video: creating canvases per frame leaks VRAM.
function Capture.newCanvases(width, height)
	return { width = width, height = height, scene = Compat.newCanvas(width, height) }
end

function Capture.releaseCanvases(canvases)
	canvases.scene:release()
	if canvases.crt then
		canvases.crt:release()
	end
end

-- The CRT target, created on first use so stills without CRT never make one.
local function crtCanvas(canvases)
	canvases.crt = canvases.crt or Compat.newCanvas(canvases.width, canvases.height, "linear")
	return canvases.crt
end

-- Slash colours of the title treatment: the entry's first two roster slots.
local function slashColors(entry)
	local palette = Config.players.palette
	return { palette[entry.roster[1].color], palette[entry.roster[2].color] }
end

-- The logo alone on an alpha-0 canvas: no stars, world, HUD, glow or CRT, since
-- glow and CRT both add over black and would fill the background.
local function renderLogoOnly(entry)
	local canvas = Compat.newCanvas(entry.width, entry.height)
	love.graphics.push("all")
	love.graphics.setCanvas(canvas)
	love.graphics.clear(0, 0, 0, 0)
	Logo.draw(entry.width, entry.height, entry.logoAnchor, entry.logoSize, slashColors(entry))
	love.graphics.setCanvas()
	love.graphics.pop()
	local imageData = canvas:newImageData()
	canvas:release()
	return imageData
end

-- Coverage (0..1) of pixel (x, y) by a size x size square with rounded
-- corners of `radius`: the distance to the corner arc, so the edge is
-- anti-aliased.
local function roundedCoverage(x, y, size, radius)
	local px, py = x + 0.5, y + 0.5
	local dx = math.max(radius - px, px - (size - radius), 0)
	local dy = math.max(radius - py, py - (size - radius), 0)
	local distance = math.sqrt(dx * dx + dy * dy) - radius
	return math.min(1, math.max(0, 0.5 - distance))
end

-- The monogram (G//) alone on a near-black square: icon only, no game context.
-- Glow and CRT run on the full opaque square like any scene; the rounded
-- corners are cut afterwards (alpha 0 outside them), since CRT fills black.
local function renderMonogramOnly(entry)
	local frame = Framing.transform(entry.width, entry.height, { zoom = 1 })
	local flags = Flags.resolve(entry, SettingsStore.load().postMode)
	local canvases = Capture.newCanvases(entry.width, entry.height)
	local scene = canvases.scene
	love.graphics.push("all")
	love.graphics.setCanvas(scene)
	love.graphics.clear(10/255, 10/255, 10/255, 1)
	Monogram.draw(entry.width, slashColors(entry), entry.glyphScale)
	love.graphics.setCanvas()
	if flags.glow then
		addGlow(scene, entry.width, entry.height, frame.uiScale)
	end
	local result = scene
	if flags.crt then
		result = applyCrt(scene, crtCanvas(canvases), entry.width, entry.height, 0)
	end
	love.graphics.pop()
	local imageData = result:newImageData()
	Capture.releaseCanvases(canvases)
	local radius = entry.width * ICON_CORNER_RADIUS
	imageData:mapPixel(function(x, y, r, g, b)
		return r, g, b, roundedCoverage(x, y, entry.width, radius)
	end)
	return imageData
end

-- Glow then CRT on the finished scene canvas; returns the canvas holding the
-- result. The window is the target afterwards.
local function postProcess(canvases, flags, uiScale, grainTime)
	local scene = canvases.scene
	if flags.glow then
		addGlow(scene, canvases.width, canvases.height, uiScale)
	end
	if flags.crt then
		return applyCrt(scene, crtCanvas(canvases), canvases.width, canvases.height, grainTime)
	end
	return scene
end

-- Draw one frame of `ctx` (stars, world, HUD, logo overlay, glow, CRT) into
-- `canvases` (Capture.newCanvases at the output size) and return the canvas
-- holding the finished frame. `entry` gives the overlay fields; `flags` is
-- Flags.resolve's { hud, glow, crt }. `overlay(width, height)`, when given,
-- draws in output pixels over everything, before glow and CRT. Leaves the
-- window as the target.
function Capture.drawFrame(ctx, entry, flags, canvases, grainTime, overlay)
	local width, height = canvases.width, canvases.height
	local frame = Framing.transform(width, height, ctx.camera)
	local scene = canvases.scene

	love.graphics.push("all")
	love.graphics.setCanvas(scene)
	love.graphics.clear(0, 0, 0, 1)

	-- Stars and overlays live in the 1280x720 screen space.
	-- The starfield covers one 1280x720 screen, so wide or tall outputs tile it,
	-- shifting the camera per tile so the pattern does not repeat.
	love.graphics.push()
	love.graphics.scale(frame.uiScale)
	for _, tile in ipairs(Framing.starTiles(width, height, frame.uiScale)) do
		love.graphics.push()
		love.graphics.translate(tile.x, tile.y)
		Starfield.draw(ctx.camera.x + tile.col * 7919, ctx.camera.y + tile.row * 6007, ctx.time)
		love.graphics.pop()
	end
	love.graphics.pop()

	MatchState.drawWorld(ctx, frame.centreX, frame.centreY, frame.worldScale)

	-- Same order as MatchState.draw; inside the scene so glow and CRT see them.
	if flags.hud then
		love.graphics.push()
		love.graphics.scale(frame.uiScale)
		Hud.draw(ctx, { slots = "all" })
		ScoreCard.draw(ctx)
		MatchOver.draw(ctx)
		love.graphics.pop()
	end
	-- Inside the scene so glow and CRT treat it like the title screen does.
	if entry.overlay == "logo" then
		Logo.draw(width, height, entry.logoAnchor, entry.logoSize, slashColors(entry), entry.logoOffsetX, entry.logoOffsetY)
	end
	if overlay then
		overlay(width, height)
	end
	love.graphics.setCanvas()

	local result = postProcess(canvases, flags, frame.uiScale, grainTime)
	love.graphics.pop()
	return result
end

-- A frame with no world: `draw(width, height)` paints on black (output
-- pixels), then the same glow and CRT as drawFrame. Leaves the window as the
-- target, like drawFrame.
function Capture.drawCard(draw, flags, canvases, grainTime)
	local width, height = canvases.width, canvases.height
	love.graphics.push("all")
	love.graphics.setCanvas(canvases.scene)
	love.graphics.clear(0, 0, 0, 1)
	draw(width, height)
	love.graphics.setCanvas()
	local result = postProcess(canvases, flags, Framing.transform(width, height, { zoom = 1 }).uiScale, grainTime)
	love.graphics.pop()
	return result
end

function Capture.render(entry)
	if entry.transparent then
		return renderLogoOnly(entry)
	end
	if entry.icon then
		return renderMonogramOnly(entry)
	end
	local ctx = Scene.build(entry)
	local flags = Flags.resolve(entry, SettingsStore.load().postMode)
	local canvases = Capture.newCanvases(entry.width, entry.height)
	local imageData = Capture.drawFrame(ctx, entry, flags, canvases, 0):newImageData()
	Capture.releaseCanvases(canvases)
	return imageData
end

return Capture
