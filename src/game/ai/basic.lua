-- The basic behaviour: aim at the nearest living enemy, charge, fire, and
-- lift off when a landed ship's turret can't reach the target. Not in the
-- personality pool (src/game/ai/init.lua); a binding picks it by name, and
-- its aim-and-fire step, Basic.shoot, is shared with the personalities.
-- The aim comes
-- from src/game/ai/skills/aim.lua's gravity-aware solve, falling back to a
-- straight line at the target when no hit is found within the level's
-- prediction horizon. Levels differ only by config numbers
-- (config.ai.levels): aim error, reaction delay, prediction horizon.
-- Thinks every `reactionDelay` seconds and holds the resulting intent in
-- between. The aim error is redrawn, and the aim re-planned, only while
-- neither a charge nor a shell is in flight; the solve itself also waits
-- until shooter or target has moved, so it stays off most thinks. All
-- randomness comes from ctx.rng.
local Angle = require("src.core.angle")
local Bodies = require("src.sim.bodies")
local Lander = require("src.game.components.lander")
local Aim = require("src.game.ai.skills.aim")

local Basic = {}

local atan2 = math.atan2 or function(y, x)
	return math.atan(y, x)
end

-- The nearest living enemy ship to `body`: `{ x, y, radius, dx, dy, dist }`
-- (offset and distance from `body`), or nil.
function Basic.nearestEnemy(ctx, ship, body)
	local best, bestDist
	for _, other in ipairs(ctx.pools.ships) do
		if other ~= ship and not other.dead then
			local otherBody = Bodies.get(ctx.sim.bodies, other.body)
			if otherBody then
				local dx, dy = otherBody.x - body.x, otherBody.y - body.y
				local dist = math.sqrt(dx * dx + dy * dy)
				if not bestDist or dist < bestDist then
					best = { x = otherBody.x, y = otherBody.y, radius = otherBody.radius or 0, dx = dx, dy = dy, dist = dist }
					bestDist = dist
				end
			end
		end
	end
	return best
end

-- Flying ships fire from the nose, 10 px ahead of the centre
-- (src/game/systems/ship_system.lua); tanks from the turret muzzle.
local NOSE_LENGTH = 10

-- World aim angle and seconds of charge for a shot at `target`.
local function plan(ctx, ship, body, level, target)
	local config = ctx.config
	local shooter = {
		x = body.x,
		y = body.y,
		vx = body.vx,
		vy = body.vy,
		muzzle = Lander.isGrounded(ship) and config.tank.barrelLength or NOSE_LENGTH,
	}
	local solution = Aim.solve(ctx.sim, ctx.level.worlds, shooter, target, config, {
		dt = ctx.dt,
		horizon = level.predictionHorizon,
	})
	local aim
	if solution then
		aim = { angle = solution.angle, charge = solution.charge, solved = true }
	else
		local fraction = math.min(1, target.dist / config.ai.fullChargeDistance)
		aim = { angle = atan2(target.dx, -target.dy), charge = fraction * config.weapon.chargeTime }
	end
	aim.fromX, aim.fromY, aim.atX, aim.atY = body.x, body.y, target.x, target.y
	return aim
end

-- A plan holds while shooter and target each stay within a ship radius of
-- where it was solved, so a duel between tanks solves once, not every think.
local function stale(aim, body, target)
	if not aim then
		return true
	end
	local r = target.radius
	local function moved(x0, y0, x1, y1)
		local dx, dy = x1 - x0, y1 - y0
		return dx * dx + dy * dy > r * r
	end
	return moved(aim.fromX, aim.fromY, body.x, body.y) or moved(aim.atX, aim.atY, target.x, target.y)
end

-- True when the ship's fuel is below config.ai.refuelFuel.
function Basic.lowFuel(ctx, ship)
	return ship.fuel.amount < ctx.config.ai.refuelFuel
end

-- True when `point` lies within `reach` px of `body`.
function Basic.near(body, point, reach)
	local dx, dy = point.x - body.x, point.y - body.y
	return dx * dx + dy * dy <= reach * reach
end

-- The shared aim-and-fire step (Hopper's landed turret uses it too): plans
-- a shot at the nearest enemy on `state` (aim, aimOffset, charging;
-- `aim.solved` is true only for a gravity-aware solution), turns
-- turret or nose toward it, charges and releases. Returns a fresh intent;
-- `thrust` is set only when a tank's turret cannot reach the aim.
function Basic.shoot(ctx, ship, body, level, state)
	local config = ctx.config
	local intent = { rotate = 0, thrust = false, fire = false }
	local target = Basic.nearestEnemy(ctx, ship, body)
	if not target then
		state.charging = false
		return intent
	end

	local shellAlive = ship.weapon and ship.weapon.shell and Bodies.get(ctx.sim.bodies, ship.weapon.shell)
	if not state.aim or not (state.charging or shellAlive) then
		state.aimOffset = ctx.rng:range(-level.aimError, level.aimError)
		if stale(state.aim, body, target) then
			state.aim = plan(ctx, ship, body, level, target)
		end
	end
	local worldAngle = state.aim.angle + state.aimOffset

	local err, rate
	if Lander.isGrounded(ship) then
		-- The turret angle is relative to the body (the surface normal).
		local want = Angle.wrap(worldAngle - body.angle)
		if math.abs(want) > config.tank.turretLimit then
			intent.thrust = true
			state.charging = false
			return intent
		end
		err, rate = want - ship.turret.angle, config.tank.turretSpeed
	else
		err, rate = Angle.wrap(worldAngle - body.angle), config.ship.rotationSpeed
	end

	-- Keep turning (charging too) until within half a held step, so it
	-- never overshoots by more than that; a charge may start a little looser.
	local halfStep = rate * level.reactionDelay / 2
	local tolerance = math.max(config.ai.fireTolerance, halfStep)
	if err > halfStep then
		intent.rotate = 1
	elseif err < -halfStep then
		intent.rotate = -1
	end

	if shellAlive then
		state.charging = false
	elseif state.charging then
		intent.fire = ctx.time < state.chargeUntil
		state.charging = intent.fire
	elseif math.abs(err) <= tolerance then
		state.charging = true
		state.chargeUntil = ctx.time + state.aim.charge
		intent.fire = true
	end
	return intent
end

-- Writes ctx.intents[slot]. Re-thinks once ctx.time reaches state.nextThink;
-- otherwise the previous intent stays on ctx.intents.
function Basic.update(ctx, slot, ship, level, state)
	local body = Bodies.get(ctx.sim.bodies, ship.body)
	if not body then
		return
	end
	if ctx.time >= state.nextThink then
		state.intent = Basic.shoot(ctx, ship, body, level, state)
		state.nextThink = ctx.time + level.reactionDelay
	end
	local held = state.intent
	ctx.intents[slot] = { rotate = held.rotate, thrust = held.thrust, fire = held.fire }
end

return Basic
