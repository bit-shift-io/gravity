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
local ShipsRender = require("src.app.render.ships")
local ProjectilesRender = require("src.app.render.projectiles")
local AsteroidsRender = require("src.app.render.asteroids")
local EffectsRender = require("src.app.render.effects")
local Hud = require("src.app.render.hud")
local ScoreCard = require("src.app.render.score_card")
local MatchOver = require("src.app.render.match_over")
local DebugOverlay = require("src.app.render.debug_overlay")
local Input = require("src.app.input")

local GameHarness = {}

-- opts.config overrides the tuning table (defaults to src/game/config.lua).
-- opts.seed (optional) fixes the match's RNG seed (docs/CONTEXT.md "Seed")
-- -- a test that needs a reproducible asteroid sequence passes an explicit
-- one; omitted, Match.new falls back to its own per-run default.
-- opts.real = true additionally announces the started game to the e2e
-- runner via _G.E2E_ON_GAME_STARTED, mirroring the real app's fixed-timestep
-- accumulator so headless and headed tests drive the match identically.
function GameHarness.startMatch(level, opts)
	opts = opts or {}

	local ok, err = Level.validate(level)
	if not ok then
		error("invalid level: " .. tostring(err))
	end

	local ctx = Match.new(level, opts.config or Config, opts.seed)
	-- Same debug-toggle wiring as src/app/states/match_state.lua, so e2e
	-- scenarios can press 1/2 (tests/support/fake_input.lua) against a
	-- harnessed match exactly as they would against the real app.
	ctx.debug = Input.newDebugState()

	local game = { ctx = ctx }

	function game:update(dt)
		-- Only under the e2e tier (or a future integration `love` mock) is
		-- there a `love` global to poll; the integration tier drives this
		-- same harness with none (file header), so skip debug input there
		-- rather than erroring on a missing love.keyboard.
		if love then
			Input.update(ctx.debug)
			Input.updateIntents(ctx)
		end
		ctx.dt = dt
		ctx.time = ctx.time + dt
		Match.step(ctx)
	end

	-- Draws via the real render path (src/app/render/worlds.lua) so an e2e
	-- capture shows the level's worlds, not a blank frame.
	function game:draw()
		WorldsRender.draw(ctx.level)
		AsteroidsRender.draw(ctx)
		ShipsRender.draw(ctx)
		ProjectilesRender.draw(ctx)
		EffectsRender.draw(ctx)
		Hud.draw(ctx)
		ScoreCard.draw(ctx)
		MatchOver.draw(ctx)
		DebugOverlay.draw(ctx)
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
