-- Airburst (docs/CONTEXT.md "Airburst"): an AI remote-detonates its own
-- armed shell when an enemy ship (centre, as Blast kills) or an asteroid
-- (edge) is within config.projectile.blastRadius of it, or once the shell has
-- passed its closest approach to the nearest enemy by config.ai.missMargin px
-- (a miss, freeing the next shot). A miss is held while the AI's own ship is
-- in blast radius; a hit on an enemy is not. Never fires while the shell is
-- unarmed (the press would be ignored). Runs for every personality from
-- AI.fill, after the kind writes its intent, by overriding that intent's
-- fire. A press needs a released fire the step before, so with fire still
-- held it releases first. The closest approach is tracked on
-- state.airburst. Deterministic: no rng.
local Bodies = require("src.sim.bodies")

local Airburst = {}

local function distance(a, b)
	local dx, dy = a.x - b.x, a.y - b.y
	return math.sqrt(dx * dx + dy * dy)
end

-- The distance from `shell` to the nearest living enemy ship, or nil.
local function nearestEnemy(ctx, ship, shell)
	local best
	for _, other in ipairs(ctx.pools.ships) do
		if other ~= ship and not other.dead then
			local body = Bodies.get(ctx.sim.bodies, other.body)
			if body then
				local d = distance(body, shell)
				if not best or d < best then
					best = d
				end
			end
		end
	end
	return best
end

local function asteroidInRange(ctx, shell, blast)
	for _, asteroid in ipairs(ctx.pools.asteroids) do
		if not asteroid.dead then
			local body = Bodies.get(ctx.sim.bodies, asteroid.body)
			if body and distance(body, shell) - (body.radius or 0) <= blast then
				return true
			end
		end
	end
	return false
end

-- True when this step's closest-approach record says the shell has missed.
local function missed(ctx, ship, shell, shellId, enemyDist, state, blast)
	local track = state.airburst
	if not track or track.shell ~= shellId then
		track = { shell = shellId, closest = math.huge }
		state.airburst = track
	end
	if not enemyDist then
		return false
	end
	track.closest = math.min(track.closest, enemyDist)
	if enemyDist <= track.closest + ctx.config.ai.missMargin then
		return false
	end
	local own = Bodies.get(ctx.sim.bodies, ship.body)
	return not (own and distance(own, shell) <= blast)
end

-- Overrides ctx.intents[slot].fire with a press when slot's armed shell
-- should detonate. Leaves the intent alone otherwise.
function Airburst.update(ctx, slot, ship, state)
	local weapon = ship.weapon
	local shellId = weapon and weapon.shell
	local shell = shellId and Bodies.get(ctx.sim.bodies, shellId)
	if not shell then
		state.airburst = nil
		return
	end

	local blast = ctx.config.projectile.blastRadius
	local enemyDist = nearestEnemy(ctx, ship, shell)
	local miss = missed(ctx, ship, shell, shellId, enemyDist, state, blast)
	if not shell.armed then
		return
	end
	local hit = (enemyDist and enemyDist <= blast) or asteroidInRange(ctx, shell, blast)
	if not (hit or miss) then
		return
	end

	local intent = ctx.intents[slot] or {}
	ctx.intents[slot] = { rotate = intent.rotate or 0, thrust = intent.thrust or false, fire = not weapon.prevFire }
end

return Airburst
