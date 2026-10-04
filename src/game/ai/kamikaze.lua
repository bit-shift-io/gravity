-- The Kamikaze personality (docs/CONTEXT.md "Personality"): lifts off at
-- the first think and flies with src/game/ai/skills/flight.lua for the
-- point config.ai.kamikazeStandoff px straight above the nearest enemy,
-- slowing to config.ai.kamikazeSpeed within config.ai.kamikazeApproach px.
-- Once that enemy is within config.ai.kamikazeRange px, it has no shell
-- out and it moves no faster than kamikazeSpeed relative to it, it turns
-- its nose (thrust off) to where its slowest shell meets the enemy --
-- leading the enemy's motion relative to its own -- and taps fire: pressed
-- for one think, let go the next. The shared airburst skill
-- (src/game/ai/skills/airburst.lua) then detonates the shell as soon as it
-- is armed with the enemy in blast radius, whether or not the kamikaze is
-- in it too. Stuck (src/game/ai/skills/stuck.lua: no shot for
-- config.ai.stuckDelay) it takes Basic's best aimed shot from wherever it
-- is. Dodging incoming shells and asteroids and landing to refuel work as
-- the Hunter's do; lifting off, it climbs straight out for the level's
-- hopTime first.
--
-- Modes on `state.mode`: "pursue" <-> "attack" while flying, "evade" while
-- threatened, "refuel" from low fuel until refilled. Thinks every
-- `reactionDelay` seconds and holds the intent in between; levels differ
-- only by config numbers (reactionDelay, flightHorizon, dangerHorizon,
-- hopTime). No randomness of its own beyond Basic.shoot's aim error when
-- stuck. Tolerates a fresh, empty state at any time (Schizo's switch).
local Bodies = require("src.sim.bodies")
local Lander = require("src.game.components.lander")
local Basic = require("src.game.ai.basic")
local Field = require("src.sim.field")
local Danger = require("src.game.ai.skills.danger")
local Flight = require("src.game.ai.skills.flight")
local Stuck = require("src.game.ai.skills.stuck")

local Kamikaze = {}

-- Flying ships fire from the nose, 10 px ahead of the centre
-- (src/game/systems/ship_system.lua).
local NOSE_LENGTH = 10

local INCOMING = { shell = true, asteroid = true }

-- Config as Flight.flyTo would be with cruiseSpeed capped at
-- config.ai.kamikazeSpeed: closing in slowly, the ship still drifts
-- little while it turns to aim with the thrust off.
local slowConfigs = setmetatable({}, { __mode = "k" })
local function slowConfig(config)
	local slow = slowConfigs[config]
	if not slow then
		slow = setmetatable({
			ai = setmetatable({ cruiseSpeed = config.ai.kamikazeSpeed }, { __index = config.ai }),
		}, { __index = config })
		slowConfigs[config] = slow
	end
	return slow
end

-- The point config.ai.kamikazeStandoff px straight above `enemy` (against
-- its local pull): hovering there, the kamikaze turns and falls toward its
-- shot rather than sweeping past it.
local function overhead(ctx, enemy)
	local pull = Field.sample(ctx.sim.field, enemy.x, enemy.y)
	local len = math.sqrt(pull.x * pull.x + pull.y * pull.y)
	local ux, uy = 0, -1
	if len > 1e-9 then
		ux, uy = -pull.x / len, -pull.y / len
	end
	local standoff = ctx.config.ai.kamikazeStandoff
	return { x = enemy.x + ux * standoff, y = enemy.y + uy * standoff }
end

-- The nearest living enemy ship's body and its distance, or nil.
local function nearestBody(ctx, ship, body)
	local best, bestDist
	for _, other in ipairs(ctx.pools.ships) do
		local otherBody = other ~= ship and not other.dead and Bodies.get(ctx.sim.bodies, other.body)
		if otherBody then
			local dx, dy = otherBody.x - body.x, otherBody.y - body.y
			local dist = math.sqrt(dx * dx + dy * dy)
			if not bestDist or dist < bestDist then
				best, bestDist = otherBody, dist
			end
		end
	end
	return best, bestDist
end

-- True while `body` moves no faster than config.ai.kamikazeSpeed relative
-- to `enemy`: any faster and it would sweep past while it turns.
local function settled(body, enemy, config)
	local vx, vy = (enemy.vx or 0) - body.vx, (enemy.vy or 0) - body.vy
	local limit = config.ai.kamikazeSpeed
	return vx * vx + vy * vy <= limit * limit
end

-- World angle (0 = up) from `body` to where a shell let go from its nose at
-- `speed` px/s meets `enemy`, both moving on as now: in the shooter's frame
-- the shell flies straight out from NOSE_LENGTH px and the enemy drifts at
-- the relative velocity. Straight at the enemy when it can't be caught.
local function interceptAngle(body, enemy, speed)
	local rx, ry = enemy.x - body.x, enemy.y - body.y
	local vx, vy = (enemy.vx or 0) - body.vx, (enemy.vy or 0) - body.vy
	local a = vx * vx + vy * vy - speed * speed
	local b = 2 * (rx * vx + ry * vy - NOSE_LENGTH * speed)
	local c = rx * rx + ry * ry - NOSE_LENGTH * NOSE_LENGTH
	local t
	if math.abs(a) < 1e-9 then
		t = b ~= 0 and -c / b or nil
	else
		local disc = b * b - 4 * a * c
		if disc >= 0 then
			local root = math.sqrt(disc)
			local t1, t2 = (-b - root) / (2 * a), (-b + root) / (2 * a)
			t = math.min(t1, t2) > 0 and math.min(t1, t2) or math.max(t1, t2)
		end
	end
	if t and t > 0 then
		rx, ry = rx + vx * t, ry + vy * t
	end
	return Flight.angleOf(rx, ry)
end

-- The intent a think holds lasts whole steps: reactionDelay rounded up to one.
local function heldSeconds(ctx, level)
	return math.max(1, math.ceil(level.reactionDelay / ctx.dt - 1e-6)) * ctx.dt
end

-- Turn onto the intercept and, lined up, press fire for one think; the
-- next think lets go, firing at the charge that one held think built.
local function pointBlank(ctx, body, level, state, enemy)
	local config = ctx.config
	local hold = heldSeconds(ctx, level)
	if state.tapping then
		state.tapping = false
		return { rotate = 0, thrust = false, fire = false }
	end
	local share = math.min(1, hold / config.weapon.chargeTime)
	local speed = config.weapon.minSpeed + (config.weapon.maxSpeed - config.weapon.minSpeed) * share
	local rotate, err = Flight.steer(body, interceptAngle(body, enemy, speed), config, hold)
	local tolerance = math.max(config.ai.fireTolerance, config.ship.rotationSpeed * hold / 2)
	if math.abs(err) <= tolerance then
		state.tapping = true
		return { rotate = 0, thrust = false, fire = true }
	end
	return { rotate = rotate, thrust = false, fire = false }
end

local function think(ctx, ship, body, level, state)
	local config = ctx.config

	if Lander.isGrounded(ship) then
		state.tapping = false
		if state.mode == "refuel" and ship.fuel.amount < config.ai.takeoffFuel then
			local intent = Stuck.cycles(ctx, state) >= 1 and Basic.shoot(ctx, ship, body, level, state)
				or { rotate = 0, thrust = false, fire = false }
			intent.thrust = false
			return intent
		end
		state.mode = "pursue"
		state.charging = false
		state.liftUntil = ctx.time + level.hopTime
		return Flight.liftOff()
	end
	-- A one-think lift-off falls back onto the surface: climb straight out
	-- for hopTime.
	if ctx.time < (state.liftUntil or 0) then
		return Flight.liftOff()
	end

	local threats = Danger.scan(ctx.sim, ctx.level.worlds, body, config, { dt = ctx.dt, horizon = level.dangerHorizon })
	if state.mode == "refuel" or Basic.lowFuel(ctx, ship) then
		state.mode = "refuel"
		state.charging, state.tapping = false, false
		return Flight.land(ctx.sim, body, threats, config, { fuel = ship.fuel, hold = level.reactionDelay })
	end

	local threat = Danger.firstOf(threats, INCOMING, level.dangerHorizon)
	if threat and not state.tapping then
		state.mode = "evade"
		state.charging = false
		return Flight.flyWith(ctx, ship, body, level, Flight.evadeGoal(ctx.sim, body, threat, config))
	end

	local enemy, dist = nearestBody(ctx, ship, body)
	if not enemy then
		state.mode = "pursue"
		state.tapping = false
		return Flight.land(ctx.sim, body, threats, config, { fuel = ship.fuel, hold = level.reactionDelay })
	end

	local shellAlive = ship.weapon and ship.weapon.shell and Bodies.get(ctx.sim.bodies, ship.weapon.shell)
	-- Settled enters the attack; once turning, it keeps on while in range.
	local inRange = not shellAlive and dist <= config.ai.kamikazeRange
	if state.tapping or (inRange and (state.mode == "attack" or settled(body, enemy, config))) then
		state.mode = "attack"
		state.charging = false
		return pointBlank(ctx, body, level, state, enemy)
	end
	if state.charging or (not shellAlive and Stuck.cycles(ctx, state) >= 1) then
		state.mode = "attack"
		return Basic.shoot(ctx, ship, body, level, state)
	end

	state.mode = "pursue"
	local goal = overhead(ctx, enemy)
	return Flight.flyWith(ctx, ship, body, level, goal, dist <= config.ai.kamikazeApproach and slowConfig(config) or nil)
end

-- Writes ctx.intents[slot]. Re-thinks once ctx.time reaches state.nextThink;
-- otherwise the previous intent stays on ctx.intents.
function Kamikaze.update(ctx, slot, ship, level, state)
	local body = Bodies.get(ctx.sim.bodies, ship.body)
	if not body then
		return
	end
	if ctx.time >= state.nextThink then
		state.intent = think(ctx, ship, body, level, state)
		if state.intent.fire then
			Stuck.fired(ctx, state)
		end
		state.nextThink = ctx.time + level.reactionDelay
	end
	local held = state.intent
	ctx.intents[slot] = { rotate = held.rotate, thrust = held.thrust, fire = held.fire }
end

return Kamikaze
