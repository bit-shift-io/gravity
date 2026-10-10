-- Sound cues for a trailer shot (no `love.*`). Fed the match after every
-- Match.step, it mirrors Audio.update (src/app/audio.lua) once per video
-- frame: each event in ctx.events is cued once (dedupe by table identity,
-- docs/memory/match-events-stay-in-ctx.md), blast and crash in one frame give
-- one blast, split shares the asteroidDeath sound, and with speed > 1 at most
-- one one-shot plays per frame (the game's fast-forward rule). Events already
-- in the list before the shot's first frame are marked seen and never cued.
--
-- Frame k (from 1) shows the state after step from + k * speed and plays at
-- (k - 1) / FPS, so a cue sounds on the first frame that shows its event.
-- A shot overlapping the one before it also shows `pre` frames before frame 1
-- (k = 0 and below): their cues have negative times, which is their trailer
-- time once the item's start is added.
local Thruster = require("src.game.components.thruster")

local Cues = {}
Cues.__index = Cues

local FPS = 60
local SOUND = { blast = "blast", crash = "blast", asteroidDeath = "asteroidDeath", asteroidSplit = "asteroidDeath", fire = "fire" }

-- `shot` needs from, to and optional speed (default 1); `pre` is the number
-- of extra frames shown before frame 1 (default 0).
function Cues.new(shot, pre)
	return setmetatable({
		from = shot.from,
		firstStep = shot.from - (pre or 0) * (shot.speed or 1),
		speed = shot.speed or 1,
		frames = (shot.to - shot.from) / (shot.speed or 1),
		seen = {},
		cues = {},
		thrust = {},
	}, Cues)
end

local function anyThrusting(ctx)
	for _, ship in ipairs(ctx.pools.ships) do
		if not ship.dead and Thruster.isThrusting(ship, ctx) then
			return true
		end
	end
	return false
end

-- Call after every Match.step with that step's number (from 1).
function Cues:observe(ctx, step)
	if step <= self.firstStep then
		for _, event in ipairs(ctx.events) do
			self.seen[event] = true
		end
		return
	end
	if (step - self.from) % self.speed ~= 0 then
		return
	end
	local frame = (step - self.from) / self.speed
	local time = (frame - 1) / FPS

	local budget = self.speed > 1 and 1 or math.huge
	local blastCued = false
	for _, event in ipairs(ctx.events) do
		if not self.seen[event] then
			self.seen[event] = true
			local sound = SOUND[event.kind]
			if sound == "blast" then
				if blastCued then
					sound = nil
				end
				blastCued = true
			end
			if sound and budget > 0 then
				budget = budget - 1
				table.insert(self.cues, { time = time, kind = sound })
			end
		end
	end

	if anyThrusting(ctx) then
		local last = self.thrust[#self.thrust]
		if last and math.abs(last.stop - time) < 1e-9 then
			last.stop = frame / FPS
		else
			table.insert(self.thrust, { start = time, stop = frame / FPS })
		end
	end
end

-- { cues = { {time, kind} }, thrust = { {start, stop} }, duration } in seconds.
function Cues:result()
	return { cues = self.cues, thrust = self.thrust, duration = self.frames / FPS }
end

return Cues
