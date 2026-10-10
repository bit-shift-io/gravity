-- Steps a shot's match (no `love.*`): built at step 0 the same way as a Steam
-- manifest entry (Scene.build), then advanced one Match.step at a time up to
-- `to`. Every `speed` steps after `from`, onFrame(view, step) is called, so a
-- shot gives (to - from) / speed frames and the last one shows step `to`.
-- onStep(ctx, step), when given, runs after every step (frame or not), for
-- consumers that must see the pre-roll, such as tools/trailer/cues.lua.
-- Stepping incrementally keeps a shot O(to), where rebuilding per frame
-- (as Capture.render does) would be O(to^2).
local Scene = require("tools.steam_assets.scene")
local Keyframes = require("tools.trailer.keyframes")

local ShotRunner = {}

-- A camera replaces only what is drawn: frames get a view of the match with
-- that camera, and the sim's own camera (zoomed by Match.step) is untouched.
local function viewOf(ctx, camera)
	if not camera then
		return ctx
	end
	local fixed = { x = camera.x, y = camera.y, zoom = camera.zoom }
	return setmetatable({ camera = fixed }, { __index = ctx })
end

-- A shot opened for stepping, so two can advance together over an overlap.
-- `extra` is { pre, post } (video frames, default 0): the shot also gives
-- `pre` frames before its first and `post` after its last, showing steps
-- `from - (pre - 1) * speed` .. `from` and `to + speed` .. `to + post * speed`.
-- Frames inside from..to are the same steps as without them. onStep(ctx, step)
-- runs after every step, the pre-roll included.
-- `camera` is nil (sim camera), one { x, y, zoom } (fixed), or a list of
-- keyframes. For keyframes, frame k of n draws at t = (k - 1) / (n - 1), so the
-- first frame is t = 0 and the last is t = 1 (a one-frame shot is t = 0); extra
-- frames hold the first or last view.
local Stepper = {}
Stepper.__index = Stepper

function ShotRunner.open(shot, extra, onStep)
	extra = extra or {}
	local speed = shot.speed or 1
	return setmetatable({
		shot = shot,
		speed = speed,
		onStep = onStep,
		ctx = Scene.build({ seed = shot.seed, roster = shot.roster, step = 0 }),
		keyed = type(shot.camera) == "table" and shot.camera[1] ~= nil,
		frames = (shot.to - shot.from) / speed,
		k = -(extra.pre or 0), -- frame number of the last frame given (frame 1 shows step from + speed)
		last = (shot.to - shot.from) / speed + (extra.post or 0),
		step = 0,
	}, Stepper)
end

-- Advances to the next frame and returns view, step, k (k from 1 is the
-- frame's place in from..to; extra frames before it are 0 and below, after it
-- above the shot's frame count), or nil after the last frame.
function Stepper:next()
	if self.k >= self.last then
		return nil
	end
	self.k = self.k + 1
	local target = self.shot.from + self.k * self.speed
	while self.step < target do
		self.step = self.step + 1
		Scene.step(self.ctx)
		if self.onStep then
			self.onStep(self.ctx, self.step)
		end
	end
	local camera = self.shot.camera
	if self.keyed then
		local t = self.frames > 1 and (self.k - 1) / (self.frames - 1) or 0
		camera = Keyframes.at(camera, math.max(0, math.min(1, t)))
	end
	return viewOf(self.ctx, camera), self.step, self.k
end

-- Runs the whole shot: onFrame(view, step) once per frame of from..to.
function ShotRunner.run(shot, onFrame, onStep)
	local stepper = ShotRunner.open(shot, nil, onStep)
	while true do
		local view, step = stepper:next()
		if not view then
			return
		end
		onFrame(view, step)
	end
end

return ShotRunner
