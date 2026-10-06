-- steam=scout seed=N (or entry=NAME for a manifest entry's seed and roster): an interactive match for picking manifest frames. Steps
-- with Scene.step (one Match.step per step, counted exactly) rather than the
-- app accumulator, so the printed step reproduces the frame. Pan and zoom
-- replace only the camera this view draws with; ctx.camera (the sim camera) is
-- never touched. Never writes files: the entry goes to the console. Dev-only.
local Starfield = require("src.app.render.starfield")
local MatchState = require("src.app.states.match_state")
local Hud = require("src.app.render.hud")
local Framing = require("tools.steam_assets.framing")
local Scene = require("tools.steam_assets.scene")
local EntryFormat = require("tools.steam_assets.entry_format")

local Scout = {}

local FIXED_DT = 1 / 60
local SPEEDS = { 1, 4, 16, 64 }
local MAX_STEPS_PER_FRAME = 256
local PAN_SPEED = 400 -- screen pixels per second
local ZOOM_RATE = 1.0 -- zoom factor e^(rate*dt) per second held

local function ai(color, level)
	return { color = color, binding = { kind = "ai", level = level } }
end

local HELP = {
	"SCOUT  seed %d  step %d  speed x%d%s",
	"space pause   . step   1-4 speed   r restart",
	"wasd/arrows pan   - = zoom   c follow sim camera",
	"p print manifest entry   h hide help   esc quit",
}

local function keyDown(...)
	for _, key in ipairs({ ... }) do
		if love.keyboard.isDown(key) then
			return true
		end
	end
	return false
end

function Scout.start(args)
	local seed, entryName
	for _, a in ipairs(args or {}) do
		seed = seed or tonumber(a:match("^seed=(.+)$"))
		entryName = entryName or a:match("^entry=(.+)$")
	end

	-- entry=NAME scouts a manifest entry's own seed and roster, so the frame
	-- matches what steam=build renders; seed=N still overrides the seed.
	local roster = { ai(1, "hard"), ai(2, "hard"), ai(3, "easy"), ai(4, "easy") }
	if entryName then
		local found
		for _, entry in ipairs(require("tools.steam_assets.manifest")) do
			if entry.name == entryName then
				found = entry
			end
		end
		if not found then
			io.stderr:write("steam scout: no manifest entry '" .. entryName .. "'\n")
			return love.event.quit(1)
		end
		seed = seed or found.seed
		roster = found.roster
	end
	if not seed then
		io.stderr:write("steam scout needs seed=N or entry=NAME\n")
		return love.event.quit(1)
	end

	local state = { ctx = nil, step = 0, paused = false, speed = 1, acc = 0, view = nil, helpOn = true }

	local function restart()
		state.ctx = Scene.build({ seed = seed, step = 0, roster = roster })
		state.step, state.acc, state.view = 0, 0, nil
	end
	restart()

	local function advance()
		Scene.step(state.ctx)
		state.step = state.step + 1
	end

	local function viewCamera()
		return state.view or state.ctx.camera
	end

	-- First pan or zoom copies the sim camera so the view can diverge from it.
	local function ownView()
		local c = state.ctx.camera
		state.view = state.view or { x = c.x, y = c.y, zoom = c.zoom }
		return state.view
	end

	function love.update(dt)
		if not state.paused then
			state.acc = math.min(state.acc + dt * state.speed, MAX_STEPS_PER_FRAME * FIXED_DT)
			while state.acc >= FIXED_DT do
				advance()
				state.acc = state.acc - FIXED_DT
			end
		end
		local dx = (keyDown("d", "right") and 1 or 0) - (keyDown("a", "left") and 1 or 0)
		local dy = (keyDown("s", "down") and 1 or 0) - (keyDown("w", "up") and 1 or 0)
		local dz = (keyDown("=", "kp+") and 1 or 0) - (keyDown("-", "kp-") and 1 or 0)
		if dx ~= 0 or dy ~= 0 or dz ~= 0 then
			local v = ownView()
			v.x = v.x + dx * PAN_SPEED * dt / v.zoom
			v.y = v.y + dy * PAN_SPEED * dt / v.zoom
			v.zoom = v.zoom * math.exp(dz * ZOOM_RATE * dt)
		end
	end

	-- Typing a key also fires love.textinput, which main.lua forwards to a flow
	-- scout never builds.
	function love.textinput() end

	function love.keypressed(key)
		if key == "escape" then
			love.event.quit(0)
		elseif key == "space" then
			state.paused = not state.paused
		elseif key == "." then
			state.paused = true
			advance()
		elseif key == "1" or key == "2" or key == "3" or key == "4" then
			state.speed = SPEEDS[tonumber(key)]
		elseif key == "r" then
			restart()
		elseif key == "c" then
			state.view = nil
		elseif key == "h" then
			state.helpOn = not state.helpOn
		elseif key == "p" then
			print(EntryFormat.entry({
				seed = seed,
				step = state.step,
				roster = roster,
				camera = state.view or false,
			}))
		end
	end

	function love.draw()
		local width, height = love.graphics.getDimensions()
		local ctx, camera = state.ctx, viewCamera()
		local frame = Framing.transform(width, height, camera)
		love.graphics.clear(0, 0, 0, 1)
		love.graphics.push()
		love.graphics.scale(frame.uiScale)
		for _, tile in ipairs(Framing.starTiles(width, height, frame.uiScale)) do
			love.graphics.push()
			love.graphics.translate(tile.x, tile.y)
			Starfield.draw(camera.x + tile.col * 7919, camera.y + tile.row * 6007, ctx.time)
			love.graphics.pop()
		end
		love.graphics.pop()
		-- A view of the match whose camera is the scout's; the sim ctx is untouched.
		local view = setmetatable({ camera = camera }, { __index = ctx })
		MatchState.drawWorld(view, frame.centreX, frame.centreY, frame.worldScale)
		love.graphics.push()
		love.graphics.scale(frame.uiScale)
		Hud.draw(ctx, { slots = "all" })
		if state.helpOn then
			love.graphics.setColor(1, 1, 1, 0.85)
			love.graphics.print(string.format(table.concat(HELP, "\n"), seed, state.step, state.speed,
				state.paused and "  PAUSED" or ""), 10, 40)
		end
		love.graphics.pop()
	end
end

return Scout
