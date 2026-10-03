-- Shared menu drawing in the vector/line style of the other overlays: a title,
-- a column of items, and a line bracket around the selected one. Screen space
-- over the 1280x720 virtual resolution. Only `draw` touches `love.*`.
local Fonts = require("src.app.render.fonts")
local Starfield = require("src.app.render.starfield")

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
local COMPACT = { titleSize = 48, titleGap = 28, itemSize = 26, spacing = 41, swatch = 20, noticeY = 676 }
local TITLE_GAP = 90
local SLIDE_RISE = 60

local function easeOut(t)
	return 1 - (1 - t) ^ 3
end

-- Prints `title` centred at y. With `colors` ({ c1, c2 }) the two slashes of
-- GRAV//TY take those colours; the rest stays white.
local function printTitle(font, title, y, colors, alpha)
	local a, c = title:match("^(.-)//(.*)$")
	if not (colors and a) then
		love.graphics.setColor(1, 1, 1, alpha)
		love.graphics.print(title, (SCREEN_WIDTH - font:getWidth(title)) / 2, y)
		return
	end
	local parts = { { a, nil }, { "/", colors[1] }, { "/", colors[2] }, { c, nil } }
	local width = 0
	for _, part in ipairs(parts) do
		width = width + font:getWidth(part[1])
	end
	local x = (SCREEN_WIDTH - width) / 2
	for _, part in ipairs(parts) do
		local col = part[2] or { 1, 1, 1 }
		love.graphics.setColor(col[1], col[2], col[3], alpha)
		love.graphics.print(part[1], x, y)
		x = x + font:getWidth(part[1])
	end
end

-- opts.title (string), opts.items ({ { label, color = {r,g,b,a}|nil, flag = bool|nil } }),
-- opts.selected (1-based), opts.dim (backdrop alpha, for overlays drawn over a
-- frozen match). Setup passes opts.compact, items with a `color` (a swatch
-- before the label; `flag` draws it red, `dim` fades the row) and opts.notice (a line at the foot,
-- red when opts.alert). The title and items are centred vertically as one
-- block. opts.titleColors colours the title's slashes; opts.reveal (0..1, nil =
-- settled) plays the intro: the title starts alone at screen centre and slides up
-- into place while the items rise and fade in.
function Menu.draw(opts)
	local compact = opts.compact and COMPACT
	local titleFont = Fonts.get(compact and compact.titleSize or TITLE_SIZE)
	local itemFont = Fonts.get(compact and compact.itemSize or ITEM_SIZE)
	local spacing = compact and compact.spacing or ITEM_SPACING

	-- A dimmed menu is an overlay over a match, which already has its stars.
	if not opts.dim then
		Starfield.draw()
	end
	if opts.dim then
		love.graphics.setColor(0, 0, 0, opts.dim)
		love.graphics.rectangle("fill", 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)
		love.graphics.setColor(1, 1, 1, 1)
		love.graphics.setLineWidth(2)
		love.graphics.rectangle("line", 1, 1, SCREEN_WIDTH - 2, SCREEN_HEIGHT - 2)
		love.graphics.setLineWidth(1)
	end

	local titleHeight = titleFont:getHeight()
	local itemsHeight = (#opts.items - 1) * spacing + itemFont:getHeight()
	local gap = compact and compact.titleGap or TITLE_GAP
	local blockTop = (SCREEN_HEIGHT - (titleHeight + gap + itemsHeight)) / 2
	local reveal = opts.reveal and easeOut(opts.reveal) or 1
	local titleSettled = blockTop
	local titleAlone = (SCREEN_HEIGHT - titleHeight) / 2
	local titleY = titleAlone + (titleSettled - titleAlone) * reveal

	love.graphics.setFont(titleFont)
	printTitle(titleFont, opts.title, titleY, opts.titleColors, 1)

	love.graphics.setFont(itemFont)
	love.graphics.setLineWidth(2)
	local top = blockTop + titleHeight + gap + (1 - reveal) * SLIDE_RISE
	-- Swatches share one column, left of the widest coloured label, so they
	-- stay put when a label's width changes.
	local swatchLeft = math.huge
	for _, item in ipairs(opts.items) do
		if item.color then
			swatchLeft = math.min(swatchLeft, (SCREEN_WIDTH - itemFont:getWidth(item.label)) / 2)
		end
	end
	for i, item in ipairs(opts.items) do
		if reveal <= 0 then
			break
		end
		local width = itemFont:getWidth(item.label)
		local x = (SCREEN_WIDTH - width) / 2
		local y = top + (i - 1) * spacing
		local selected = i == opts.selected
		local alpha = (selected and 1 or 0.5) * reveal
		if item.dim then
			alpha = alpha * 0.5
		end
		if item.color then
			local size = compact and compact.swatch or 24
			local c = item.color
			love.graphics.setColor(c[1], c[2], c[3], alpha)
			love.graphics.rectangle("fill", swatchLeft - BRACKET_PAD - size - 16, y + (itemFont:getHeight() - size) / 2, size, size)
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
