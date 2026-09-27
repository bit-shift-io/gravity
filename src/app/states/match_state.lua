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

local MatchState = {}

function MatchState.enter(level, config)
	local ok, err = Level.validate(level)
	if not ok then
		error("invalid level: " .. tostring(err))
	end

	return Match.new(level, config)
end

function MatchState.update(ctx, dt)
	ctx.dt = dt
	ctx.time = ctx.time + dt
	Match.step(ctx)
end

function MatchState.draw(ctx)
	WorldsRender.draw(ctx.level)
end

return MatchState
