-- Shared menu drawing in the vector/line style of the other overlays: a title,
-- a column of items, and a line bracket around the selected one. Screen space
-- over the 1280x720 virtual resolution. Only `draw` touches `love.*`.
local Fonts = require("src.app.render.fonts")

local Menu = {}

local SCREEN_WIDTH = 1280
local SCREEN_HEIGHT = 720
local TITLE_SIZE = 72
local ITEM_SIZE = 36
local ITEM_SPACING = 64
local BRACKET_PAD = 24
local BRACKET_ARM = 14

-- Compact layout for the roster setup screen: a smaller title and a tighter
-- column so a full roster plus its settings fit on screen.
local COMPACT = { titleSize = 48, titleY = 24, itemSize = 26, spacing = 41, top = 100, swatch = 20, noticeY = 676 }

-- opts.title (string), opts.items ({ { label, color = {r,g,b,a}|nil, flag = bool|nil } }),
-- opts.selected (1-based), opts.dim (backdrop alpha, for overlays drawn over a
-- frozen match). Setup passes opts.compact, items with a `color` (a swatch
-- before the label; `flag` draws it red) and opts.notice (a line at the foot,
-- red when opts.alert).
function Menu.draw(opts)
	local compact = opts.compact and COMPACT
	local titleFont = Fonts.get(compact and compact.titleSize or TITLE_SIZE)
	local itemFont = Fonts.get(compact and compact.itemSize or ITEM_SIZE)
	local spacing = compact and compact.spacing or ITEM_SPACING

	if opts.dim then
		love.graphics.setColor(0, 0, 0, opts.dim)
		love.graphics.rectangle("fill", 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)
	end

	love.graphics.setFont(titleFont)
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.print(opts.title, (SCREEN_WIDTH - titleFont:getWidth(opts.title)) / 2, compact and compact.titleY or 150)

	love.graphics.setFont(itemFont)
	love.graphics.setLineWidth(2)
	local top = compact and compact.top or 320
	for i, item in ipairs(opts.items) do
		local width = itemFont:getWidth(item.label)
		local x = (SCREEN_WIDTH - width) / 2
		local y = top + (i - 1) * spacing
		local selected = i == opts.selected
		local alpha = selected and 1 or 0.5
		if item.color then
			local size = compact and compact.swatch or 24
			local c = item.color
			love.graphics.setColor(c[1], c[2], c[3], alpha)
			love.graphics.rectangle("fill", x - BRACKET_PAD - size - 16, y + (itemFont:getHeight() - size) / 2, size, size)
		end
		if item.flag then
			love.graphics.setColor(1, 0.3, 0.3, alpha)
		else
			love.graphics.setColor(1, 1, 1, alpha)
		end
		love.graphics.print(item.label, x, y)
		if selected then
			local height = itemFont:getHeight()
			local left, right = x - BRACKET_PAD, x + width + BRACKET_PAD
			local y1, y2 = y - 6, y + height + 6
			love.graphics.line(left + BRACKET_ARM, y1, left, y1, left, y2, left + BRACKET_ARM, y2)
			love.graphics.line(right - BRACKET_ARM, y1, right, y1, right, y2, right - BRACKET_ARM, y2)
		end
	end

	if opts.notice then
		local font = Fonts.get(compact and 22 or 28)
		love.graphics.setFont(font)
		if opts.alert then
			love.graphics.setColor(1, 0.3, 0.3, 1)
		else
			love.graphics.setColor(1, 1, 1, 0.8)
		end
		love.graphics.print(opts.notice, (SCREEN_WIDTH - font:getWidth(opts.notice)) / 2, compact and compact.noticeY or 640)
	end
end

return Menu
