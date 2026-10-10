-- trailer=clips: validate the trailer manifest, then render each shot to
-- trailer/clips/<name>.mp4 (video plus sound effects) and exit. shot=NAME
-- renders just that shot. trailer=build renders the manifest's sequence into
-- one trailer/trailer.mp4, with the music bed under the sound effects if the
-- manifest has one. Frames are drawn by the Steam tool's Capture.drawFrame into one reused
-- canvas set at 1920x1080 and piped to ffmpeg. Dev-only; uses `love.*`.
local Manifest = require("tools.trailer.manifest")
local ManifestCheck = require("tools.trailer.manifest_check")
local ShotRunner = require("tools.trailer.shot_runner")
local Encoder = require("tools.trailer.encoder")
local Cues = require("tools.trailer.cues")
local Mixer = require("tools.trailer.mixer")
local Timeline = require("tools.trailer.timeline")
local Sounds = require("tools.trailer.sounds")
local Audio = require("src.app.audio")
local Text = require("tools.trailer.text")
local Capture = require("tools.steam_assets.capture")
local Logo = require("tools.steam_assets.logo")
local Config = require("src.game.config")
local Flags = require("tools.steam_assets.flags")
local SettingsStore = require("src.app.settings_store")

local Build = {}

local TRAILER_DIR = "trailer"
local CLIPS_DIR = TRAILER_DIR .. "/clips"

local function fail(message)
	io.stderr:write("trailer build failed: " .. message .. "\n")
	love.event.quit(1)
end

local function findArg(args, pattern)
	for _, a in ipairs(args or {}) do
		local value = a:match(pattern)
		if value then
			return value
		end
	end
	return nil
end

-- Every shot, or only the one named by shot=NAME. Returns shots, err.
local function selectShots(only)
	if not only then
		return Manifest.shots
	end
	for _, shot in ipairs(Manifest.shots) do
		if shot.name == only then
			return { shot }
		end
	end
	return nil, "no shot named '" .. only .. "'"
end

-- Fades `frame` towards black (alpha 1 leaves it alone), after CRT, so the
-- vignette stays put through a fade, then hands it to the encoder.
local function writeFrame(frame, encoder, alpha)
	if alpha < 1 then
		love.graphics.push("all")
		love.graphics.setCanvas(frame)
		love.graphics.setColor(0, 0, 0, 1 - alpha)
		love.graphics.rectangle("fill", 0, 0, Encoder.WIDTH, Encoder.HEIGHT)
		love.graphics.pop()
	end
	local imageData = frame:newImageData()
	encoder:write(imageData)
	imageData:release()
end

-- The shot's captions at frame k (from 1), as an overlay for Capture.drawFrame
-- (output pixels, so the camera never moves them), or nil when there are none.
local function captionOverlay(shot, k)
	if not shot.captions then
		return nil
	end
	local t = (k - 1) / Encoder.FPS
	return function(width, height)
		for _, caption in ipairs(shot.captions) do
			local alpha = Timeline.captionAlpha(caption, t)
			if alpha > 0 then
				Text.drawCaption(caption, alpha, width, height)
			end
		end
	end
end

-- Renders `shot` frame by frame into `encoder`. `alphaAt(k)`, when given, is
-- how visible frame k (from 1) is: below 1 a black overlay goes over the final
-- frame, after CRT, so the vignette stays put through a fade.
-- Returns ok, err, the shot's Cues:result().
local function renderFrames(shot, canvases, postMode, encoder, alphaAt)
	local flags = Flags.resolve(shot, postMode)
	local cues = Cues.new(shot)
	local k = 0
	local ok, err = pcall(ShotRunner.run, shot, function(view, step)
		k = k + 1
		-- Grain follows the match clock, so the same shot gives the same frames.
		local frame = Capture.drawFrame(view, shot, flags, canvases, step / Encoder.FPS, captionOverlay(shot, k))
		writeFrame(frame, encoder, alphaAt and alphaAt(k) or 1)
	end, function(ctx, step)
		cues:observe(ctx, step)
	end)
	if not ok then
		return false, tostring(err)
	end
	return true, nil, cues:result()
end

-- Draws a card item: text on black, or the logo end card for card = "logo"
-- (the Steam logo with an optional line under it).
local function drawCard(item)
	return function(width, height)
		if item.card ~= "logo" then
			Text.drawCard(item.card, width, height)
			return
		end
		local palette = Config.players.palette
		Logo.draw(width, height, "centre", 0.4, { palette[1], palette[2] }, 0, -height * 0.08)
		if item.sub then
			Text.drawSub(item.sub, width, height)
		end
	end
end

-- Renders a card item frame by frame into `encoder`. Glow and CRT are on, as
-- on every manifest shot. Cards make no sound.
local function renderCard(item, canvases, encoder)
	local flags = { hud = false, glow = true, crt = true }
	local draw = drawCard(item)
	local ok, err = pcall(function()
		for k = 1, item.frames do
			local frame = Capture.drawCard(draw, flags, canvases, (item.start + k) / Encoder.FPS)
			writeFrame(frame, encoder, Timeline.alpha(item, k))
		end
	end)
	if not ok then
		return false, tostring(err)
	end
	return true
end

-- Mixes `sound` ({ cues, thrust, duration }) to `wavPath`, muxes it with
-- `videoPath` (and `music`, see Encoder.muxCommand) into `outPath`, and always
-- removes both intermediates.
local function addSound(sound, sounds, videoPath, wavPath, outPath, music)
	local samples = Mixer.mix({
		rate = Sounds.RATE,
		duration = sound.duration,
		cues = sound.cues,
		thrust = sound.thrust,
		sounds = sounds,
		volume = Audio.VOLUME,
	})
	local file, ferr = io.open(wavPath, "wb")
	if not file then
		os.remove(videoPath)
		return false, ferr
	end
	file:write(Mixer.wav(samples, Sounds.RATE))
	file:close()

	local mok, merr = Encoder.mux(videoPath, wavPath, outPath, music)
	os.remove(videoPath)
	os.remove(wavPath)
	return mok, merr
end

-- Video goes to <name>.video.mp4 and the mixed sound to <name>.wav, then
-- both are muxed into <name>.mp4; the intermediates are always removed.
local function renderShot(shot, canvases, postMode, sounds)
	local base = CLIPS_DIR .. "/" .. shot.name
	local videoPath = base .. ".video.mp4"
	local encoder = Encoder.open(videoPath)
	local ok, err, result = renderFrames(shot, canvases, postMode, encoder)
	if not ok then
		encoder:abort()
		return false, err
	end
	local vok, verr = encoder:finish()
	if not vok then
		return false, verr
	end
	return addSound(result, sounds, videoPath, base .. ".wav", base .. ".mp4")
end

-- The whole sequence streams into one encoder (no clip concat, so cuts land
-- on exact frames), with one sound-effects track offset per item.
local function renderTrailer(timeline, canvases, postMode, sounds, music)
	local base = TRAILER_DIR .. "/trailer"
	local videoPath = base .. ".video.mp4"
	local encoder = Encoder.open(videoPath)
	local results = {}
	for index, item in ipairs(timeline.items) do
		local ok, err, result
		if item.kind == "card" then
			ok, err = renderCard(item, canvases, encoder)
		else
			ok, err, result = renderFrames(item.shot, canvases, postMode, encoder, function(k)
				return Timeline.alpha(item, k)
			end)
		end
		if not ok then
			encoder:abort()
			return false, (item.shot and item.shot.name or "card " .. item.card) .. ": " .. err
		end
		results[index] = result
	end
	local vok, verr = encoder:finish()
	if not vok then
		return false, verr
	end
	return addSound(Timeline.sound(timeline, results), sounds, videoPath, base .. ".wav", base .. ".mp4", music)
end

-- The manifest's music bed with its defaults filled in, or nil when there is
-- none. A missing file prints a warning and the build goes on without music.
local function resolveMusic()
	local music = Manifest.music
	if not music then
		return nil
	end
	local file = io.open(music.path, "rb")
	if not file then
		io.stderr:write("trailer build warning: music file not found, building with sound effects only: "
			.. music.path .. "\n")
		return nil
	end
	file:close()
	return {
		path = music.path,
		volume = music.volume or ManifestCheck.MUSIC_DEFAULTS.volume,
		fadeOut = music.fadeOut or ManifestCheck.MUSIC_DEFAULTS.fadeOut,
		length = Manifest.length,
	}
end

local function buildTrailer()
	if not Manifest.sequence or #Manifest.sequence == 0 then
		return fail("the manifest has no sequence")
	end
	local timeline = Timeline.build(Manifest)
	local music = resolveMusic()
	os.execute(string.format('mkdir -p "%s"', TRAILER_DIR))
	local started = os.clock()
	local canvases = Capture.newCanvases(Encoder.WIDTH, Encoder.HEIGHT)
	local ok, err = renderTrailer(timeline, canvases, SettingsStore.load().postMode, Sounds.load(), music)
	Capture.releaseCanvases(canvases)
	if not ok then
		return fail(err)
	end
	print(string.format("wrote %s/trailer.mp4 (%.1fs of video, %.0fs to render)", TRAILER_DIR,
		Timeline.duration(timeline), os.clock() - started))
	love.event.quit(0)
end

-- `args` are the launch arguments (shot=NAME limits the run).
function Build.run(mode, args)
	if mode == "scout" then
		return require("tools.trailer.scout").start(args)
	end
	if mode ~= "clips" and mode ~= "build" then
		return fail("unknown trailer mode '" .. mode .. "'")
	end
	if not Encoder.available() then
		return fail("ffmpeg not found")
	end
	local ok, err = ManifestCheck.validate(Manifest)
	if not ok then
		return fail(err)
	end
	if mode == "build" then
		return buildTrailer()
	end
	local shots, selectErr = selectShots(findArg(args, "^shot=(.+)$"))
	if not shots then
		return fail(selectErr)
	end

	os.execute(string.format('mkdir -p "%s"', CLIPS_DIR))
	local postMode = SettingsStore.load().postMode
	local sounds = Sounds.load()
	local canvases = Capture.newCanvases(Encoder.WIDTH, Encoder.HEIGHT)
	for _, shot in ipairs(shots) do
		local started = os.clock()
		local rok, rerr = renderShot(shot, canvases, postMode, sounds)
		if not rok then
			Capture.releaseCanvases(canvases)
			return fail(shot.name .. ": " .. rerr)
		end
		print(string.format("wrote %s/%s.mp4 (%.1fs of video, %.0fs to render)", CLIPS_DIR, shot.name,
			(shot.to - shot.from) / (shot.speed or 1) / Encoder.FPS, os.clock() - started))
	end
	Capture.releaseCanvases(canvases)
	love.event.quit(0)
end

return Build
