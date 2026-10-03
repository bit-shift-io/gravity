local TitleState = require("src.app.states.title_state")

local function newTitle(opts)
	local played = false
	local flow = { play = function() played = true end, quit = function() end }
	return TitleState.new(flow, opts), function() return played end
end

test("intro holds the title alone for a second, then slides in", function()
	local title = newTitle({ intro = true })
	assertEqual(0, title:reveal())
	title:update(0.9)
	assertEqual(0, title:reveal())
	title:update(0.45)
	assert(title:reveal() > 0 and title:reveal() < 1)
	title:update(5)
	assertEqual(1, title:reveal())
end)

test("without intro the title starts settled", function()
	assertEqual(1, newTitle():reveal())
end)

test("a key during the intro skips it instead of choosing an item", function()
	local title, played = newTitle({ intro = true })
	title:keypressed("return")
	assertEqual(1, title:reveal())
	assertEqual(false, played())
	title:keypressed("return")
	assertEqual(true, played())
end)
