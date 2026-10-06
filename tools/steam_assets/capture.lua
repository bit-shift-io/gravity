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

-- Glow of `scene` added back onto it. Glow.render leaves the window as the
-- target, so callers set their own target afterwards.
local function addGlow(scene, width, height, uiScale)
	local cfg = Config.post.glow
	Glow.render(scene, width, height, uiScale, cfg)
	love.graphics.setCanvas(scene)
	Glow.add(width, height, cfg, 0, 0)
	love.graphics.setCanvas()
end

-- Draw `scene` through the CRT shader into a new canvas. grainTime is fixed so
-- the same entry always gives the same image.
local function applyCrt(scene, width, height)
	crtShader = crtShader or Compat.newShader(love.filesystem.read("src/app/post/shaders/crt.glsl"))
	local cfg = Config.post.crt
	local out = Compat.newCanvas(width, height, "linear")
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
	crtShader:send("grainTime", 0)
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.draw(scene, 0, 0)
	love.graphics.setShader()
	love.graphics.setCanvas()
	return out
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

-- The monogram (G//) alone on a near-black canvas: icon only, no game context.
local function renderMonogramOnly(entry)
	local canvas = Compat.newCanvas(entry.width, entry.height)
	love.graphics.push("all")
	love.graphics.setCanvas(canvas)
	love.graphics.clear(10/255, 10/255, 10/255, 1)
	Monogram.draw(entry.width, slashColors(entry), entry.glyphScale)
	love.graphics.setCanvas()
	love.graphics.pop()
	local imageData = canvas:newImageData()
	canvas:release()
	return imageData
end

function Capture.render(entry)
	if entry.transparent then
		return renderLogoOnly(entry)
	end
	if entry.icon then
		return renderMonogramOnly(entry)
	end
	local ctx = Scene.build(entry)
	local frame = Framing.transform(entry.width, entry.height, ctx.camera)
	local flags = Flags.resolve(entry, SettingsStore.load().postMode)
	local scene = Compat.newCanvas(entry.width, entry.height)

	love.graphics.push("all")
	love.graphics.setCanvas(scene)
	love.graphics.clear(0, 0, 0, 1)

	-- Stars and overlays live in the 1280x720 screen space.
	-- The starfield covers one 1280x720 screen, so wide or tall outputs tile it,
	-- shifting the camera per tile so the pattern does not repeat.
	love.graphics.push()
	love.graphics.scale(frame.uiScale)
	for _, tile in ipairs(Framing.starTiles(entry.width, entry.height, frame.uiScale)) do
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
		Logo.draw(entry.width, entry.height, entry.logoAnchor, entry.logoSize, slashColors(entry))
	end
	love.graphics.setCanvas()

	if flags.glow then
		addGlow(scene, entry.width, entry.height, frame.uiScale)
	end
	local result = scene
	if flags.crt then
		result = applyCrt(scene, entry.width, entry.height)
	end
	love.graphics.pop()

	local imageData = result:newImageData()
	if result ~= scene then
		result:release()
	end
	scene:release()
	return imageData
end

return Capture
