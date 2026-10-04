-- Sound effects. Reads ctx.events (fire, blast, crash, asteroidDeath, asteroidSplit) and ship thrust
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

-- Call once per Match.step.
function Audio.update(ctx)
	if not (love and love.audio) then
		return
	end
	if not sources then
		load()
	end
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
	for _, event in ipairs(ctx.events) do
		if not played[event] then
			played[event] = true
			local kind = event.kind
			if kind == "blast" or kind == "crash" then
				if not blastPlayed then
					blastPlayed = true
					playOnce("blast")
				end
			elseif kind == "asteroidDeath" or kind == "asteroidSplit" then
				playOnce("asteroidDeath")
			elseif kind == "fire" then
				playOnce("fire")
			end
		end
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
	end
end

-- Silences the looping thruster, for leaving a match.
function Audio.stopAll()
	if sources then
		setThrusting(false)
	end
end

return Audio
