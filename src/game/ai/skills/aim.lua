-- Gravity-aware shot solving for AI aim: searches launch angles and charges,
-- flying each candidate with src/game/ai/skills/trajectory.lua, for one that
-- passes through a stationary target before the horizon -- never one whose
-- blast (config.projectile.blastRadius) would reach the shooter. Search cost is
-- capped by config.ai (aimAngles coarse candidates over +/- aimSpread around
-- the direct angle, then aimRefine halvings around the closest miss, for each
-- of aimCharges) and by the horizon's step count. Pure and deterministic --
-- no rng, no `love.*` (docs/ARCHITECTURE.md "Layers").
local Angle = require("src.core.angle")
local Trajectory = require("src.game.ai.skills.trajectory")

local Aim = {}

local atan2 = math.atan2 or function(y, x)
	return math.atan(y, x)
end

-- Closest approach of the flight to the target, and the step it happens at.
-- A flight that would blast within `blast` px of the shooter -- where it
-- meets the target, or a world before that -- never counts as a hit.
local function miss(sim, worlds, shooter, target, angle, speed, radius, dt, steps, blast)
	local dx, dy = math.sin(angle), -math.cos(angle)
	local path = Trajectory.simulate(sim, worlds, {
		x = shooter.x + dx * shooter.muzzle,
		y = shooter.y + dy * shooter.muzzle,
		vx = shooter.vx + dx * speed,
		vy = shooter.vy + dy * speed,
		radius = radius,
	}, dt, steps)
	local best, bestStep = math.huge, steps
	for i, p in ipairs(path.points) do
		local ox, oy = p.x - target.x, p.y - target.y
		local d = ox * ox + oy * oy
		if d < best then
			best, bestStep = d, i
		end
	end
	local at = path.points[bestStep]
	if at then
		local sx, sy = at.x - shooter.x, at.y - shooter.y
		if sx * sx + sy * sy <= blast * blast then
			return math.huge, bestStep
		end
	end
	return math.sqrt(best), bestStep
end

-- `shooter` is `{ x, y, vx, vy, muzzle }` (body centre, velocity, and the
-- muzzle's distance from the centre along the aim); `target` is
-- `{ x, y, radius }`; `opts` is `{ dt, horizon }` (horizon in seconds).
-- Returns `{ angle, charge, steps }` -- world aim angle (0 = up, the same
-- convention as body.angle), seconds of charge to hold, and steps to impact
-- -- for the first hit found, or nil when nothing hits within the horizon.
-- Charges are tried fastest first, so a slower lob is only searched when no
-- fast shot gets through.
function Aim.solve(sim, worlds, shooter, target, config, opts)
	local ai, weapon = config.ai, config.weapon
	local radius = config.projectile.radius
	local hitRadius = target.radius + radius
	-- Match.new starts ctx.dt at 0; horizon / 0 would never end the search.
	if opts.dt <= 0 then
		return nil
	end
	local steps = math.floor(opts.horizon / opts.dt)
	local direct = atan2(target.x - shooter.x, -(target.y - shooter.y))
	local coarse = ai.aimAngles

	for c = 1, ai.aimCharges do
		local fraction = ai.aimCharges > 1 and (ai.aimCharges - c) / (ai.aimCharges - 1) or 1
		local speed = weapon.minSpeed + (weapon.maxSpeed - weapon.minSpeed) * fraction

		local function try(angle)
			return miss(sim, worlds, shooter, target, angle, speed, radius, opts.dt, steps, config.projectile.blastRadius)
		end

		local step = 2 * ai.aimSpread / (coarse - 1)
		local angle, d, at
		for k = 0, coarse - 1 do
			local candidate = direct - ai.aimSpread + k * step
			local cd, cat = try(candidate)
			if not d or cd < d then
				angle, d, at = candidate, cd, cat
			end
		end
		for _ = 1, ai.aimRefine do
			step = step / 2
			for _, candidate in ipairs({ angle - step, angle + step }) do
				local cd, cat = try(candidate)
				if cd < d then
					angle, d, at = candidate, cd, cat
				end
			end
		end

		if d <= hitRadius then
			return { angle = Angle.wrap(angle), charge = fraction * weapon.chargeTime, steps = at }
		end
	end
	return nil
end

return Aim
