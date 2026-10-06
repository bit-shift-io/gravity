-- Screenshot requests and the confirmation toast. A key press only requests;
-- the capture happens in the draw hook after the whole frame (pipeline
-- included) is composited. The capture function is injected (Compat in the
-- app, a fake in tests), so this module touches no love.* itself.
local Screenshot = {}
Screenshot.__index = Screenshot

local DIR = "screenshots"
local TOAST_SECONDS = 2

-- opts.capture(path, done): writes the next presented frame to `path` in the
-- save directory, then calls done(). opts.stamp(): timestamp for the filename.
function Screenshot.new(opts)
	return setmetatable({
		capture = opts.capture,
		stamp = opts.stamp or function() return os.date("%Y%m%d-%H%M%S") end,
		pending = false,
		toastLeft = 0,
		toastText = nil,
		lastStamp = nil,
		repeats = 0,
	}, Screenshot)
end

function Screenshot:request()
	self.pending = true
end

-- Two shots inside one second must not overwrite each other.
function Screenshot:nextPath()
	local stamp = self.stamp()
	if stamp == self.lastStamp then
		self.repeats = self.repeats + 1
		stamp = string.format("%s-%d", stamp, self.repeats + 1)
	else
		self.lastStamp = stamp
		self.repeats = 0
	end
	return string.format("%s/gravity-%s.png", DIR, stamp)
end

-- Called from love.draw after the frame is fully drawn.
function Screenshot:afterDraw()
	if not self.pending then
		return
	end
	self.pending = false
	local path = self:nextPath()
	self.capture(path, function()
		self.toastLeft = TOAST_SECONDS
		self.toastText = "SCREENSHOT SAVED"
	end)
end

function Screenshot:update(dt)
	if self.toastLeft > 0 then
		self.toastLeft = math.max(0, self.toastLeft - dt)
	end
end

-- Text and opacity of the toast, or nil when none is showing. Fades over the last half second.
function Screenshot:toast()
	if self.toastLeft <= 0 then
		return nil
	end
	return self.toastText, math.min(1, self.toastLeft / 0.5)
end

Screenshot.DIR = DIR

return Screenshot
