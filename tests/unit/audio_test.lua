local Audio = require("src.app.audio")

-- A love.audio that counts plays and tracks the thruster loop, installed for
-- the duration of one test. Audio caches its sources after the first load, so
-- they all write to one shared `log`, reset per test.
local log = { plays = 0, loopPlaying = false, musicPlays = 0 }

local function withFakeAudio(fn)
	local saved = _G.love
	log.plays, log.loopPlaying, log.musicPlays = 0, false, 0
	local function newSource(path)
		local source = {}
		local playing = false
		function source.setVolume() end
		function source.setLooping() end
		function source.seek() end
		function source:isPlaying()
			return playing
		end
		function source:play()
			if path:find("msc") then
				playing = true
				log.musicPlays = log.musicPlays + 1
			elseif path:find("thruster") then
				log.loopPlaying = true
			else
				log.plays = log.plays + 1
			end
		end
		function source:stop()
			if path:find("msc") then
				playing = false
			elseif path:find("thruster") then
				log.loopPlaying = false
			end
		end
		function source:clone()
			return source
		end
		return source
	end
	_G.love = { audio = { newSource = newSource } }
	local ok, err = pcall(fn, log)
	_G.love = saved
	Audio.setEnabled(true)
	Audio.setMusicEnabled(true)
	Audio.stopAll()
	Audio.stopMusic()
	if not ok then
		error(err, 0)
	end
end

local function thrustingCtx()
	return {
		events = {},
		intents = { [1] = { thrust = true } },
		pools = { ships = { { player = 1, dead = false, fuel = { amount = 10, capacity = 10, burnRate = 1 } } } },
	}
end

test("Audio is safe with no love.audio, muted and unmuted", function()
	local saved = _G.love
	_G.love = nil
	local ctx = { events = { { kind = "fire" } }, pools = { ships = {} }, intents = {} }
	Audio.setEnabled(false)
	Audio.menu("forward")
	Audio.update(ctx)
	Audio.stopAll()
	Audio.setEnabled(true)
	Audio.menu("back")
	Audio.update(ctx)
	_G.love = saved
end)

test("muted, menu sounds and match events play nothing", function()
	withFakeAudio(function(log)
		Audio.setEnabled(false)
		Audio.menu("forward")
		Audio.update({ events = { { kind = "fire" }, { kind = "blast" } }, pools = { ships = {} }, intents = {} })
		assertEqual(0, log.plays)
		Audio.setEnabled(true)
		Audio.menu("forward")
		assertEqual(1, log.plays)
	end)
end)

test("muting mid-thrust stops the loop, and it stays off while muted", function()
	withFakeAudio(function(log)
		local ctx = thrustingCtx()
		Audio.update(ctx)
		assertTrue(log.loopPlaying, "loop should start while thrusting")
		Audio.setEnabled(false)
		assertFalse(log.loopPlaying)
		Audio.update(ctx)
		assertFalse(log.loopPlaying)
		Audio.setEnabled(true)
		Audio.update(ctx)
		assertTrue(log.loopPlaying, "loop should resume after unmuting while still thrusting")
	end)
end)

test("fast-forwarding, a burst of events plays at most one sound per update", function()
	withFakeAudio(function(log)
		local ctx = {
			events = { { kind = "fire" }, { kind = "blast" }, { kind = "asteroidDeath" }, { kind = "fire" } },
			pools = { ships = {} },
			intents = {},
		}
		Audio.update(ctx, true)
		assertEqual(1, log.plays)
		-- The rest were consumed, not deferred to a later update.
		Audio.update(ctx, true)
		Audio.update(ctx, false)
		assertEqual(1, log.plays)
	end)
end)

test("fast-forwarding keeps the thruster loop off", function()
	withFakeAudio(function(log)
		local ctx = thrustingCtx()
		Audio.update(ctx)
		assertTrue(log.loopPlaying)
		Audio.update(ctx, true)
		assertFalse(log.loopPlaying)
	end)
end)

test("music starts with the first update and keeps one track playing", function()
	withFakeAudio(function(log)
		local ctx = { events = {}, pools = { ships = {} }, intents = {} }
		Audio.update(ctx)
		assertEqual(1, log.musicPlays)
		Audio.update(ctx)
		assertEqual(1, log.musicPlays)
	end)
end)

test("music stays silent when music or sound is disabled, and resumes when re-enabled", function()
	withFakeAudio(function(log)
		local ctx = { events = {}, pools = { ships = {} }, intents = {} }
		Audio.setMusicEnabled(false)
		Audio.update(ctx)
		assertEqual(0, log.musicPlays)
		Audio.setMusicEnabled(true)
		Audio.setEnabled(false)
		Audio.update(ctx)
		assertEqual(0, log.musicPlays)
		Audio.setEnabled(true)
		Audio.update(ctx)
		assertEqual(1, log.musicPlays)
	end)
end)

test("stopMusic ends the track; the next update starts the next one", function()
	withFakeAudio(function(log)
		local ctx = { events = {}, pools = { ships = {} }, intents = {} }
		Audio.update(ctx)
		Audio.stopMusic()
		Audio.update(ctx)
		assertEqual(2, log.musicPlays)
	end)
end)
