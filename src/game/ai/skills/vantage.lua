-- Vantage points for a landed sniper: the surface point to land on for a
-- clear, gravity-corrected shot at an enemy. Candidates are spawn-style
-- surface points with clear space above (src/game/spawn_points.lua's
-- clearance, never a copy of it). Every (point, enemy) pair whose direct
-- line sits inside the tank's turret limit is ranked cheaply by how near
-- its distance is to the wanted range; only the best config.ai.vantageSolves
-- pairs are then solved with src/game/ai/skills/aim.lua, in rank order, and
-- the first whose solved aim the turret can reach wins. The concealed
-- option (Artillery's pick, docs/CONTEXT.md "Concealed position") keeps
-- only pairs a world blocks the direct line of, and widens the turret
-- pre-check by the aim search's spread (config.ai.aimSpread), since a lob
-- leaves well off the direct line. Pure and deterministic -- no rng, no
-- `love.*` (docs/ARCHITECTURE.md "Layers").
local Angle = require("src.core.angle")
local Aim = require("src.game.ai.skills.aim")
local Collide = require("src.sim.collide")
local SpawnPoints = require("src.game.spawn_points")

local Vantage = {}

local atan2 = math.atan2 or function(y, x)
	return math.atan(y, x)
end

-- A landed hull stands flush on the surface, so its centre sits as far up
-- the normal as the hull's base reaches below its centre.
local function standHeight()
	local height = 0
	for _, v in ipairs(Collide.SHIP_SHAPE) do
		height = math.max(height, v.y)
	end
	return height
end

local STAND = standHeight()

-- True when no world crosses the straight line from `from` to `target`
-- (each `{ x, y }`).
function Vantage.inSight(worlds, from, target)
	return Collide.checkProjectileWorlds(from.x, from.y, target.x, target.y, worlds) == nil
end

-- `targets` is a list of enemies `{ x, y, radius }`; `opts` is
-- `{ dt, horizon, range, points?, concealed? }`: the solve's step and seconds, the
-- wanted distance to the enemy (px), and the candidate surface points
-- (each `{ x, y, normal, world }`, already cleared -- a generated level's
-- level.spawnCandidates), defaulting to SpawnPoints.cleared(worlds, config).
-- `concealed` picks only points with no direct line to the enemy, solving
-- up to config.ai.concealedSolves of them.
-- Returns the picked point (one of the candidates: `{ x, y, normal, world }`)
-- and the enemy it has the shot at, or nil when none of the solved
-- candidates has one.
function Vantage.pick(sim, worlds, targets, config, opts)
	local points = opts.points or SpawnPoints.cleared(worlds, config)
	local limit = config.tank.turretLimit
	local reach = opts.concealed and limit + config.ai.aimSpread or limit
	local pairs_ = {}
	for i, p in ipairs(points) do
		local facing = atan2(p.normal.x, -p.normal.y)
		local sx, sy = p.x + p.normal.x * STAND, p.y + p.normal.y * STAND
		for j, target in ipairs(targets) do
			local dx, dy = target.x - sx, target.y - sy
			local hidden = not opts.concealed or not Vantage.inSight(worlds, { x = sx, y = sy }, target)
			if hidden and math.abs(Angle.wrap(atan2(dx, -dy) - facing)) <= reach then
				local dist = math.sqrt(dx * dx + dy * dy)
				pairs_[#pairs_ + 1] = {
					point = p, target = target, facing = facing, x = sx, y = sy,
					score = math.abs(dist - opts.range), order = i * (#targets + 1) + j,
				}
			end
		end
	end
	table.sort(pairs_, function(a, b)
		if a.score ~= b.score then
			return a.score < b.score
		end
		return a.order < b.order
	end)

	local muzzle = config.tank.barrelLength
	local solves = opts.concealed and config.ai.concealedSolves or config.ai.vantageSolves
	for k = 1, math.min(#pairs_, solves) do
		local pair = pairs_[k]
		local shooter = { x = pair.x, y = pair.y, vx = 0, vy = 0, muzzle = muzzle }
		local solution = Aim.solve(sim, worlds, shooter, pair.target, config, { dt = opts.dt, horizon = opts.horizon })
		if solution and math.abs(Angle.wrap(solution.angle - pair.facing)) <= limit then
			return pair.point, pair.target
		end
	end
	return nil
end

return Vantage
