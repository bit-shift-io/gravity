-- A sparse field of dim dots behind everything, so the game reads as space.
-- Screen space over the 1280x720 virtual resolution. In a match the stars
-- drift a little against the camera (`depth` scales how much); menus pass no
-- camera and the field sits still. Layout is pure and seeded; only `draw`
-- touches `love.*` (docs/ARCHITECTURE.md "Layers").
local Rng = require("src.core.rng")

local Starfield = {}

local SCREEN_WIDTH = 1280
local SCREEN_HEIGHT = 720
local COUNT = 70
local SEED = 1977
-- Each star twinkles once per `period` seconds (15-40, so at any moment only a
-- few are mid-flash), for TWINKLE_TIME seconds.
Starfield.TWINKLE_TIME = 1.2

-- Stars are 1-2 px dots, dimmer when deeper. `depth` (0.02-0.12) is the
-- fraction of camera movement the star follows.
function Starfield.generate(seed, count)
	local rng = Rng.new(seed)
	-- Brightness at time `t`: the star's resting alpha, swelling to 1 and back
-- over its twinkle window.
function Starfield.brightness(star, t)
	local phase = (t + star.offset) % star.period
	if phase >= Starfield.TWINKLE_TIME then
		return star.alpha
	end
	local k = math.sin(math.pi * phase / Starfield.TWINKLE_TIME)
	return star.alpha + (1 - star.alpha) * k
end

local stars = {}
	for i = 1, count do
		local near = rng:next()
		stars[i] = {
			x = rng:next() * SCREEN_WIDTH,
			y = rng:next() * SCREEN_HEIGHT,
			size = near > 0.8 and 2 or 1,
			alpha = 0.2 + near * 0.5,
			depth = 0.02 + near * 0.1,
			period = 15 + rng:next() * 25,
			offset = rng:next() * 40,
		}
	end
	return stars
end

-- Screen position of `star` for a camera at (camX, camY), wrapped to the screen.
function Starfield.position(star, camX, camY)
	return (star.x - camX * star.depth) % SCREEN_WIDTH, (star.y - camY * star.depth) % SCREEN_HEIGHT
end

-- Brightness at time `t`: the star's resting alpha, swelling to 1 and back
-- over its twinkle window.
function Starfield.brightness(star, t)
	local phase = (t + star.offset) % star.period
	if phase >= Starfield.TWINKLE_TIME then
		return star.alpha
	end
	local k = math.sin(math.pi * phase / Starfield.TWINKLE_TIME)
	return star.alpha + (1 - star.alpha) * k
end

local stars = Starfield.generate(SEED, COUNT)

-- `time` (seconds) drives the twinkle; menus omit it and use the wall clock.
function Starfield.draw(camX, camY, time)
	camX, camY = camX or 0, camY or 0
	time = time or love.timer.getTime()
	for _, s in ipairs(stars) do
		local x, y = Starfield.position(s, camX, camY)
		local b = Starfield.brightness(s, time)
		local size = b > 0.9 and s.size + 1 or s.size
		love.graphics.setColor(1, 1, 1, b)
		love.graphics.rectangle("fill", x, y, size, size)
	end
	love.graphics.setColor(1, 1, 1, 1)
end

return Starfield
