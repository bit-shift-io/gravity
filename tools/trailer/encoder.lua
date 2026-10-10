-- Pipes raw RGBA frames into ffmpeg and writes an H.264 MP4 (video only);
-- Encoder.mux then adds a WAV as an AAC track.
-- ffmpeg writes to `<path>.part`; finish() renames it into place, abort()
-- deletes it, so a failing shot never leaves a partial MP4. Dev-only.
local Encoder = {}
Encoder.__index = Encoder

local WIDTH, HEIGHT, FPS = 1920, 1080, 60
Encoder.WIDTH, Encoder.HEIGHT, Encoder.FPS = WIDTH, HEIGHT, FPS

local function succeeded(status)
	-- LuaJIT returns the exit code; Lua 5.2+ (and 5.2-compat builds) return true.
	return status == 0 or status == true
end

function Encoder.available()
	return succeeded(os.execute("command -v ffmpeg >/dev/null 2>&1"))
end

-- Raw RGBA in at 1920x1080 / 60 fps; yuv420p out, or QuickTime will not play it.
function Encoder.open(path)
	local partPath = path .. ".part"
	local command = table.concat({
		"ffmpeg -y -loglevel error",
		string.format("-f rawvideo -pix_fmt rgba -s %dx%d -r %d -i -", WIDTH, HEIGHT, FPS),
		"-an -c:v libx264 -preset medium -crf 18 -pix_fmt yuv420p -movflags +faststart",
		string.format('-f mp4 "%s"', partPath),
	}, " ")
	local pipe = assert(io.popen(command, "w"))
	return setmetatable({ path = path, partPath = partPath, pipe = pipe, frames = 0 }, Encoder)
end

-- `imageData` is a 1920x1080 RGBA8 ImageData (a canvas readback, top-down).
function Encoder:write(imageData)
	assert(self.pipe:write(imageData:getString()))
	self.frames = self.frames + 1
end

-- Close the pipe and move the finished file into place. Returns ok, err.
function Encoder:finish()
	self.pipe:close()
	-- LuaJIT's pipe close does not report ffmpeg's exit status, so check the file.
	local file = io.open(self.partPath, "rb")
	local size = file and file:seek("end") or 0
	if file then
		file:close()
	end
	if size == 0 then
		os.remove(self.partPath)
		return false, "ffmpeg wrote no output for " .. self.path
	end
	os.remove(self.path)
	local ok, err = os.rename(self.partPath, self.path)
	if not ok then
		os.remove(self.partPath)
		return false, err
	end
	return true
end

local function num(value)
	return string.format("%g", value)
end

-- Pure (no love): the filter_complex that mixes the music bed (input 2) under
-- the sound effects (input 1) into [aout]. The music is resampled to 48 kHz,
-- trimmed to `length` seconds, faded out over its last `fadeOut` seconds (none
-- when 0) and set to `volume`. amix with normalize=0 keeps both inputs at full
-- level, and duration=first ends the mix with the effects track.
function Encoder.mixFilter(length, volume, fadeOut)
	local music = { "aresample=48000", "atrim=0:" .. num(length) }
	if fadeOut > 0 then
		table.insert(music, string.format("afade=t=out:st=%s:d=%s", num(length - fadeOut), num(fadeOut)))
	end
	table.insert(music, "volume=" .. num(volume))
	return "[1:a]aresample=48000[fx];[2:a]" .. table.concat(music, ",")
		.. "[mu];[fx][mu]amix=inputs=2:duration=first:normalize=0[aout]"
end

-- Pure (no love): the ffmpeg command that copies the video of `videoPath` and
-- adds `wavPath` as AAC into `partPath`. `music` ({ path, volume, fadeOut, length })
-- is mixed under the effects when given; the source file is read in place.
function Encoder.muxCommand(videoPath, wavPath, partPath, music)
	local inputs = string.format('-i "%s" -i "%s"', videoPath, wavPath)
	local audio = "-map 1:a:0"
	if music then
		inputs = inputs .. string.format(' -i "%s"', music.path)
		audio = string.format('-filter_complex "%s" -map "[aout]"',
			Encoder.mixFilter(music.length, music.volume, music.fadeOut))
	end
	return table.concat({
		"ffmpeg -y -loglevel error",
		inputs,
		"-map 0:v:0",
		audio,
		"-c:v copy -c:a aac -b:a 192k -movflags +faststart -f mp4",
		string.format('"%s"', partPath),
	}, " ")
end

-- Copies the video of `videoPath` and adds `wavPath` (and `music`, see
-- muxCommand) as AAC into `path` (via `path`.part, renamed on success).
-- Returns ok, err.
function Encoder.mux(videoPath, wavPath, path, music)
	local partPath = path .. ".part"
	if not succeeded(os.execute(Encoder.muxCommand(videoPath, wavPath, partPath, music))) then
		os.remove(partPath)
		return false, "ffmpeg could not add audio to " .. path
	end
	os.remove(path)
	local ok, err = os.rename(partPath, path)
	if not ok then
		os.remove(partPath)
		return false, err
	end
	return true
end

function Encoder:abort()
	pcall(self.pipe.close, self.pipe)
	os.remove(self.partPath)
end

return Encoder
