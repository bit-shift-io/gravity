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

-- `camera` is nil (sim camera), one { x, y, zoom } (fixed), or a list of
-- keyframes. For keyframes, frame k of n draws at t = (k - 1) / (n - 1), so the
-- first frame is t = 0 and the last is t = 1 (a one-frame shot is t = 0).
function ShotRunner.run(shot, onFrame, onStep)
	local speed = shot.speed or 1
	local ctx = Scene.build({ seed = shot.seed, roster = shot.roster, step = 0 })
	local keyed = type(shot.camera) == "table" and shot.camera[1] ~= nil
	local fixedView = not keyed and viewOf(ctx, shot.camera) or nil
	local frames = (shot.to - shot.from) / speed
	local frame = 0
	for step = 1, shot.to do
		Scene.step(ctx)
		if onStep then
			onStep(ctx, step)
		end
		if step > shot.from and (step - shot.from) % speed == 0 then
			frame = frame + 1
			local view = fixedView
			if keyed then
				local t = frames > 1 and (frame - 1) / (frames - 1) or 0
				view = viewOf(ctx, Keyframes.at(shot.camera, t))
			end
			onFrame(view, step)
		end
	end
end

return ShotRunner
