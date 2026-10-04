-- Steam assets render through the real renderer: exact pixel size, and the
-- logo is transparent at the corners with something drawn in it. Output goes
-- to tests/screenshots/ (gitignored), never steam-assets/.
local Capture = require("tools.steam_assets.capture")
local Manifest = require("tools.steam_assets.manifest")

local OUTPUT_DIR = "tests/screenshots/steam_assets_test"

local function entryNamed(name)
	for _, entry in ipairs(Manifest) do
		if entry.name == name then
			return entry
		end
	end
	error("manifest has no entry named " .. name)
end

local function writePng(imageData, name)
	os.execute(string.format('mkdir -p "%s"', OUTPUT_DIR))
	local file = assert(io.open(OUTPUT_DIR .. "/" .. name .. ".png", "wb"))
	file:write(imageData:encode("png"):getString())
	file:close()
end

test("the logo renders at its exact size, transparent at the corners, opaque somewhere", function()
	local entry = entryNamed("logo")
	local image = Capture.render(entry)
	writePng(image, entry.name)

	assertEqual(entry.width, image:getWidth())
	assertEqual(entry.height, image:getHeight())

	local w, h = image:getWidth(), image:getHeight()
	for _, corner in ipairs({ { 0, 0 }, { w - 1, 0 }, { 0, h - 1 }, { w - 1, h - 1 } }) do
		local _, _, _, a = image:getPixel(corner[1], corner[2])
		assertEqual(0, a)
	end

	local drawn = false
	for y = 0, h - 1, 2 do
		for x = 0, w - 1, 2 do
			local _, _, _, a = image:getPixel(x, y)
			if a > 0 then
				drawn = true
				break
			end
		end
		if drawn then
			break
		end
	end
	assertTrue(drawn, "logo has no non-transparent pixel")
end)

test("a screenshot entry renders at its exact size", function()
	local entry = entryNamed("screenshot_01")
	local image = Capture.render(entry)
	writePng(image, entry.name)
	assertEqual(entry.width, image:getWidth())
	assertEqual(entry.height, image:getHeight())
end)
