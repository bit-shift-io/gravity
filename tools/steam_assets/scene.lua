-- Builds a manifest entry's match (no `love.*`): the seed's level, the entry's
-- roster, advanced exactly `step` steps with Match.step (Match.advance would
-- fast-forward once no human is alive).
local Config = require("src.game.config")
local Level = require("src.game.level")
local LevelGen = require("src.game.level_gen")
local Match = require("src.game.match")
local Roster = require("src.game.roster")

local Scene = {}

local FIXED_DT = 1 / 60

-- One fixed step, exactly as Scene.build runs them; scout mode steps live.
function Scene.step(ctx)
	ctx.dt = FIXED_DT
	ctx.time = ctx.time + FIXED_DT
	Match.step(ctx)
end

function Scene.build(entry)
	local level = LevelGen.generate(entry.seed, Config)
	local ok, err = Level.validate(level)
	if not ok then
		error("invalid level: " .. tostring(err))
	end
	local ctx = Match.new(level, Config, entry.seed, { roster = Roster.copy(entry.roster) })
	for _ = 1, entry.step do
		Scene.step(ctx)
	end
	if entry.camera then
		ctx.camera = { x = entry.camera.x, y = entry.camera.y, zoom = entry.camera.zoom }
	end
	return ctx
end

return Scene
