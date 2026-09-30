-- Minimal state shape ({enter, update, draw}) for the match screen. There is
-- no menu yet (that's slice 12) so, for now, this is the only state and
-- main.lua enters it directly instead of showing a title screen first.
--
-- `enter` validates and normalises the level once (src/game/level.lua
-- Level.validate: winding, derived mass) before building ctx -- a bad level
-- fails loudly here rather than corrupting gravity/rendering later.
local Level = require("src.game.level")
local Match = require("src.game.match")
local WorldsRender = require("src.app.render.worlds")
local BoundaryRender = require("src.app.render.boundary")
local ShipsRender = require("src.app.render.ships")
local ProjectilesRender = require("src.app.render.projectiles")
local ParticlesRender = require("src.app.render.particles")
local AsteroidsRender = require("src.app.render.asteroids")
local EffectsRender = require("src.app.render.effects")
local Hud = require("src.app.render.hud")
local DebugOverlay = require("src.app.render.debug_overlay")
local Input = require("src.app.input")

local MatchState = {}

function MatchState.enter(level, config, seed)
	local ok, err = Level.validate(level)
	if not ok then
		error("invalid level: " .. tostring(err))
	end

	local ctx = Match.new(level, config, seed)
	-- Debug-only UI state (1/2 overlay toggles), not sim data -- lives on
	-- ctx so draw can read it, but is set up here in the app layer rather
	-- than in src/game/match.lua, which may never touch `love.*`.
	ctx.debug = Input.newDebugState()
	return ctx
end

function MatchState.update(ctx, dt)
	Input.update(ctx.debug)
	Input.updateIntents(ctx)
	ctx.dt = dt
	ctx.time = ctx.time + dt
	Match.step(ctx)
end

function MatchState.draw(ctx)
	-- Apply camera transform (position + zoom) to all world-space rendering.
	-- Camera is centered at (0, 0); translate by negative camera position to
	-- move the view, then scale by zoom level.
	love.graphics.push()
	love.graphics.translate(640, 360)  -- Move viewport center to screen center
	love.graphics.scale(ctx.camera.zoom)
	love.graphics.translate(-ctx.camera.x, -ctx.camera.y)  -- Apply camera position

	WorldsRender.draw(ctx.level)
	BoundaryRender.draw(ctx)
	AsteroidsRender.draw(ctx)
	ShipsRender.draw(ctx)
	ProjectilesRender.draw(ctx)
	ParticlesRender.draw(ctx)
	EffectsRender.draw(ctx)

	love.graphics.pop()

	-- HUD and debug overlay are drawn in screen space (not affected by camera)
	Hud.draw(ctx)
	DebugOverlay.draw(ctx)
end

return MatchState
