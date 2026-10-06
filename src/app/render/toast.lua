-- Screen-space toast, drawn in window pixels after the pipeline so it never
-- lands in the frame it confirms.
local Fonts = require("src.app.render.fonts")

local Toast = {}

local SIZE = 20
local PAD = 12

function Toast.draw(text, alpha)
	if not text then
		return
	end
	local font = Fonts.get(SIZE)
	local width = font:getWidth(text) + PAD * 2
	local height = font:getHeight() + PAD
	local x = love.graphics.getWidth() - width - PAD
	local y = PAD
	love.graphics.setFont(font)
	love.graphics.setColor(0, 0, 0, 0.7 * alpha)
	love.graphics.rectangle("fill", x, y, width, height)
	love.graphics.setColor(1, 1, 1, alpha)
	love.graphics.print(text, x + PAD, y + PAD / 2)
	love.graphics.setColor(1, 1, 1, 1)
end

return Toast
