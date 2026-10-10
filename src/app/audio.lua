-- Sound effects and match music. Reads ctx.events (fire, blast, crash, asteroidDeath, asteroidSplit) and ship thrust
-- intent after each Match.step and plays the matching sound; game code only
-- emits events and never touches audio (docs/ARCHITECTURE.md "Layers").
-- Every call is guarded so a machine with no audio device (CI, headless
-- test runs) plays silence instead of crashing.
local Thruster = require("src.game.components.thruster")

local Audio = {}

local FILES = {
	fire = "res/snd/laserRetro_000.ogg",
	blast = "res/snd/explosionCrunch_000.ogg",
	asteroidDeath = "res/snd/lowFrequency_explosion_001.ogg",
	thruster = "res/snd/thrusterFire_003.ogg",
	menuForward = "res/snd/doorOpen_000.ogg",
	menuBack = "res/snd/doorClose_001.ogg",
}

local VOLUME = { fire = 0.5, blast = 0.8, asteroidDeath = 0.8, thruster = 0.35, menuForward = 0.6, menuBack = 0.6 }

-- Read-only views of FILES and VOLUME, so the trailer tool's sound mix
-- (tools/trailer/sounds.lua) uses the same files and gains as the game.
local function readOnly(t, name)
	return setmetatable({}, {
		__index = t,
		__newindex = function()
			error("Audio." .. name .. " is read-only", 2)
		end,
	})
end
Audio.FILES = readOnly(FILES, "FILES")
Audio.VOLUME = readOnly(VOLUME, "VOLUME")

-- Match music: streamed, played in order (primary track first), one after
-- another for as long as a match is running. Credits in res/msc/info.txt.
local MUSIC_FILES = {
	"res/msc/synthwave_the_mountain.mp3",
	"res/msc/midnight_synthwave_the_mountain.mp3",
	"res/msc/synthwave_mondamusic.mp3",
}
local MUSIC_VOLUME = 0.4

local tracks = nil -- Sources for MUSIC_FILES that loaded, loaded lazily
local trackIndex = 0
local currentTrack = nil
local musicEnabled = true
local sources = nil -- name -> template Source, loaded lazily
-- Events already played, so the 2s retention window doesn't replay them.
local played = setmetatable({}, { __mode = "k" })
local thrusting = false
local enabled = true

local function load()
	sources = {}
	for name, path in pairs(FILES) do
		local ok, source = pcall(love.audio.newSource, path, "static")
		if ok then
			source:setVolume(VOLUME[name])
			sources[name] = source
		end
	end
	if sources.thruster then
		sources.thruster:setLooping(true)
	end
end

local function stopMusic()
	if currentTrack then
		local track = currentTrack
		currentTrack = nil
		pcall(function()
			track:stop()
		end)
	end
end

-- Keeps the playlist going: starts a track when none is playing, moves on when one ends.
local function updateMusic()
	if not (enabled and musicEnabled) then
		stopMusic()
		return
	end
	if not tracks then
		tracks = {}
		for _, path in ipairs(MUSIC_FILES) do
			local ok, source = pcall(love.audio.newSource, path, "stream")
			if ok then
				source:setVolume(MUSIC_VOLUME)
				tracks[#tracks + 1] = source
			end
		end
	end
	if #tracks == 0 then
		return
	end
	if currentTrack and currentTrack:isPlaying() then
		return
	end
	trackIndex = trackIndex % #tracks + 1
	currentTrack = tracks[trackIndex]
	local track = currentTrack
	local ok = pcall(function()
		track:seek(0)
		track:play()
	end)
	if not ok then
		currentTrack = nil
	end
end

local function playOnce(name)
	local template = sources[name]
	if template then
		-- A clone per play so overlapping explosions don't cut each other off.
		pcall(function()
			template:clone():play()
		end)
	end
end

local function setThrusting(on)
	local source = sources.thruster
	if not source or on == thrusting then
		return
	end
	thrusting = on
	pcall(function()
		if on then
			source:play()
		else
			source:stop()
		end
	end)
end

-- Menu feedback: "forward" (accepting) or "back" (leaving); nil plays nothing.
function Audio.menu(direction)
	if direction ~= "forward" and direction ~= "back" then
		return
	end
	if not enabled or not (love and love.audio) then
		return
	end
	if not sources then
		load()
	end
	playOnce(direction == "forward" and "menuForward" or "menuBack")
end

-- Call once per frame, after that frame's Match.steps. `fastForward` true
-- (several steps this frame, src/app/states/match_state.lua) throttles: at
-- most one one-shot sound per update, the rest marked played, and no
-- thruster loop.
function Audio.update(ctx, fastForward)
	if not (love and love.audio) then
		return
	end
	if not sources then
		load()
	end
	updateMusic()
	if not enabled then
		-- Muted: mark the events played so they stay silent after unmuting.
		for _, event in ipairs(ctx.events) do
			played[event] = true
		end
		return
	end

	-- Event kind -> sound. A ship killed by a blast raises both "blast" and
	-- "crash"; they share a sound, so it plays once per update.
	local blastPlayed = false
	local budget = fastForward and 1 or math.huge
	local function play(name)
		if budget > 0 then
			budget = budget - 1
			playOnce(name)
		end
	end
	for _, event in ipairs(ctx.events) do
		if not played[event] then
			played[event] = true
			local kind = event.kind
			if kind == "blast" or kind == "crash" then
				if not blastPlayed then
					blastPlayed = true
					play("blast")
				end
			elseif kind == "asteroidDeath" or kind == "asteroidSplit" then
				play("asteroidDeath")
			elseif kind == "fire" then
				play("fire")
			end
		end
	end

	if fastForward then
		setThrusting(false)
		return
	end

	local any = false
	for _, ship in ipairs(ctx.pools.ships) do
		if not ship.dead and Thruster.isThrusting(ship, ctx) then
			any = true
			break
		end
	end
	setThrusting(any)
end

-- Mutes (false) or unmutes (true) all sound. Muting stops the thruster loop at
-- once; menu sounds and match sounds are skipped while muted.
function Audio.setEnabled(on)
	enabled = on and true or false
	if not enabled then
		Audio.stopAll()
		stopMusic()
	end
end

-- Turns the match music on or off (on by default). Music also needs sound
-- enabled; it starts with the next Audio.update.
function Audio.setMusicEnabled(on)
	musicEnabled = on and true or false
	if not musicEnabled then
		stopMusic()
	end
end

-- Stops the music, for leaving a match; the next match starts the next track.
function Audio.stopMusic()
	stopMusic()
end

-- Silences the looping thruster, for leaving a match.
function Audio.stopAll()
	if sources then
		setThrusting(false)
	end
end

return Audio
