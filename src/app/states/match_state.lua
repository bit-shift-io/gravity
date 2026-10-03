-- Match screen: module functions on a ctx (enter/update/draw) plus a stack
-- state wrapper (MatchState.new).
--
-- `enter` validates and normalises the level once (src/game/level.lua
-- Level.validate: winding, derived mass) before building ctx -- a bad level
-- fails loudly here rather than corrupting gravity/rendering later.
local Level = require("src.game.level")
local Match = require("src.game.match")
local Starfield = require("src.app.render.starfield")
local WorldsRender = require("src.app.render.worlds")
local BoundaryRender = require("src.app.render.boundary")
local ShipsRender = require("src.app.render.ships")
local ProjectilesRender = require("src.app.render.projectiles")
local ParticlesRender = require("src.app.render.particles")
local AsteroidsRender = require("src.app.render.asteroids")
local EffectsRender = require("src.app.render.effects")
local Hud = require("src.app.render.hud")
local ScoreCard = require("src.app.render.score_card")
local MatchOver = require("src.app.render.match_over")
local DebugOverlay = require("src.app.render.debug_overlay")
local Input = require("src.app.input")
local LevelGen = require("src.game.level_gen")
local Config = require("src.game.config")
local RoundSystem = require("src.game.systems.round_system")
local PostMode = require("src.app.post.post_mode")

local MatchState = {}

function MatchState.enter(level, config, seed, roster, hardcore)
	local ok, err = Level.validate(level)
	if not ok then
		error("invalid level: " .. tostring(err))
	end

	local ctx = Match.new(level, config, seed, { roster = roster, hardcore = hardcore })
	-- Debug-only UI state (1/2 overlay toggles), not sim data -- lives on
	-- ctx so draw can read it, but is set up here in the app layer rather
	-- than in src/game/match.lua, which may never touch `love.*`.
	ctx.debug = Input.newDebugState()
	return ctx
end

function MatchState.update(ctx, dt)
	Input.update(ctx.debug)
	Input.updateIntents(ctx, ctx.roster)
	ctx.dt = dt
	ctx.time = ctx.time + dt
	Match.step(ctx)
end

-- `showResults` false hides the score card / win screen (the pause menu is
-- over the match, so they would be two windows at once).
function MatchState.draw(ctx, showResults)
	Starfield.draw(ctx.camera.x, ctx.camera.y, ctx.time)

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
	-- The overlay is in world coordinates (field cells, world outlines), so it
	-- shares the camera transform.
	DebugOverlay.draw(ctx)

	love.graphics.pop()

	-- HUD is drawn in screen space (not affected by camera)
	Hud.draw(ctx)
	if showResults ~= false then
		ScoreCard.draw(ctx)
		MatchOver.draw(ctx)
	end
end

-- Stack state around one match. The level is generated from `seed`, so a
-- rematch (or the R dev key) rebuilds the identical initial state.
local State = {}
State.__index = State

function MatchState.new(flow, seed, roster, hardcore)
	local level = LevelGen.generate(seed, Config)
	local self = { name = "match", flow = flow, seed = seed, roster = roster, hardcore = hardcore }
	self.ctx = MatchState.enter(level, Config, seed, roster, hardcore)
	return setmetatable(self, State)
end

function State:update(dt)
	MatchState.update(self.ctx, dt)
end

function State:draw()
	MatchState.draw(self.ctx, self.flow.stack:top() == self)
end

function State:keypressed(key)
	if key == "escape" then
		self.flow:pause()
	elseif key == "r" then
		self.flow:rematch(self)
	elseif (key == "return" or key == "kpenter" or key == "space") and RoundSystem.matchOver(self.ctx.round) then
		self.flow:rematch(self, true)
	elseif key == "p" then
		self.flow.session.postMode = PostMode.next(self.flow.session.postMode)
	end
end

function State:gamepadpressed(_, button)
	if button == "start" then
		self.flow:pause()
	elseif button == "a" and RoundSystem.matchOver(self.ctx.round) then
		self.flow:rematch(self, true)
	end
end

return MatchState
