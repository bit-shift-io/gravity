-- The one AI behaviour: aim at the nearest living enemy, charge, fire, and
-- lift off when a landed ship's turret can't reach the target. Levels differ
-- only by config numbers (config.ai.levels): aim error and reaction delay.
-- Thinks every `reactionDelay` seconds and holds the resulting intent in
-- between; all randomness comes from ctx.rng.
local Bodies = require("src.sim.bodies")
local Lander = require("src.game.components.lander")

local Basic = {}

local atan2 = math.atan2 or function(y, x)
	return math.atan(y, x)
end

local function wrap(angle)
	return (angle + math.pi) % (2 * math.pi) - math.pi
end

local function nearestEnemy(ctx, ship, body)
	local best, bestDist
	for _, other in ipairs(ctx.pools.ships) do
		if other ~= ship and not other.dead then
			local otherBody = Bodies.get(ctx.sim.bodies, other.body)
			if otherBody then
				local dx, dy = otherBody.x - body.x, otherBody.y - body.y
				local dist = math.sqrt(dx * dx + dy * dy)
				if not bestDist or dist < bestDist then
					best, bestDist = { dx = dx, dy = dy, dist = dist }, dist
				end
			end
		end
	end
	return best
end

local function think(ctx, ship, body, level, state)
	local config = ctx.config
	local intent = { rotate = 0, thrust = false, fire = false }
	local target = nearestEnemy(ctx, ship, body)
	if not target then
		state.charging = false
		return intent
	end

	state.aimOffset = ctx.rng:range(-level.aimError, level.aimError)
	local worldAngle = atan2(target.dx, -target.dy) + state.aimOffset

	local err, rate
	if Lander.isGrounded(ship) then
		-- The turret angle is relative to the body (the surface normal).
		local want = wrap(worldAngle - body.angle)
		if math.abs(want) > config.tank.turretLimit then
			intent.thrust = true
			state.charging = false
			return intent
		end
		err, rate = want - ship.turret.angle, config.tank.turretSpeed
	else
		err, rate = wrap(worldAngle - body.angle), config.ship.rotationSpeed
	end

	-- Don't overshoot by more than half a held step.
	local tolerance = math.max(config.ai.fireTolerance, rate * level.reactionDelay / 2)
	if err > tolerance then
		intent.rotate = 1
	elseif err < -tolerance then
		intent.rotate = -1
	end

	local shellAlive = ship.weapon and ship.weapon.shell and Bodies.get(ctx.sim.bodies, ship.weapon.shell)
	if shellAlive then
		state.charging = false
	elseif state.charging then
		intent.fire = ctx.time < state.chargeUntil
		state.charging = intent.fire
	elseif math.abs(err) <= tolerance then
		local fraction = math.min(1, target.dist / config.ai.fullChargeDistance)
		state.charging = true
		state.chargeUntil = ctx.time + fraction * config.weapon.chargeTime
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
		state.intent = think(ctx, ship, body, level, state)
		state.nextThink = ctx.time + level.reactionDelay
	end
	local held = state.intent
	ctx.intents[slot] = { rotate = held.rotate, thrust = held.thrust, fire = held.fire }
end

return Basic
