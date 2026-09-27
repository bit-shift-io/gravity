-- Boots a match the same way src/app/main.lua does, but from a literal level
-- table -- never a file path (docs/memory/test-framework-from-fido-and-kitch.md:
-- "GameHarness.startMatch(levelTable, opts) replaces fido-and-kitch's
-- startGame(mapPath)"). Works under plain LuaJIT with no `love` global,
-- because src.game.match has none (docs/ARCHITECTURE.md "Layers"); `game:draw()`
-- does reach into src/app/render (which does use love.*), but that only runs
-- under the e2e tier, which supplies a real `love`.
local Match = require("src.game.match")
local Config = require("src.game.config")
local Level = require("src.game.level")
local WorldsRender = require("src.app.render.worlds")

local GameHarness = {}

-- opts.config overrides the tuning table (defaults to src/game/config.lua).
-- opts.real = true additionally announces the started game to the e2e
-- runner via _G.E2E_ON_GAME_STARTED, mirroring the real app's fixed-timestep
-- accumulator so headless and headed tests drive the match identically.
function GameHarness.startMatch(level, opts)
	opts = opts or {}

	local ok, err = Level.validate(level)
	if not ok then
		error("invalid level: " .. tostring(err))
	end

	local ctx = Match.new(level, opts.config or Config)

	local game = { ctx = ctx }

	function game:update(dt)
		ctx.dt = dt
		ctx.time = ctx.time + dt
		Match.step(ctx)
	end

	-- Draws via the real render path (src/app/render/worlds.lua) so an e2e
	-- capture shows the level's worlds, not a blank frame.
	function game:draw()
		WorldsRender.draw(ctx.level)
	end

	if opts.real and _G.E2E_ON_GAME_STARTED then
		-- Matches src/app/main.lua's real background so a Capture.capture
		-- (which clears to the current background color) shows the same
		-- black backdrop the actual game renders against, not the canvas's
		-- default transparent black.
		love.graphics.setBackgroundColor(0, 0, 0, 1)
		_G.E2E_ON_GAME_STARTED(game)
	end

	return game
end

return GameHarness
