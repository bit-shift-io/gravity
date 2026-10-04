-- The Skirmisher personality (docs/CONTEXT.md "Personality"): stays in the
-- air and circles one enemy (its quarry, the nearest when picked, kept
-- until it dies), flying with src/game/ai/skills/flight.lua (Flight.flyTo
-- keeps its predicted path clear of worlds and the hard boundary) for a
-- point a little further round a circle between config.ai.orbitMin and
-- orbitMax px from it. Where that point would sink into a world it turns
-- back, so round a landed enemy it swings to and fro overhead. With the
-- nearest enemy between two blast radii and orbitMax away and no impact
-- coming, it turns and fires a quick shot -- the shared aim-and-fire step
-- (Basic.shoot) solved over charges of at most config.ai.skirmishCharge
-- seconds -- but only a gravity-aware solution, unless stuck
-- (src/game/ai/skills/stuck.lua: no shot for config.ai.stuckDelay), when it
-- takes the best aimed shot, solved or not. It never starts or lets go of
-- a shot whose shell would strike a world within config.ai.skirmishSafety
-- seconds. Dodging incoming shells and asteroids and landing to refuel work
-- as the Hunter's do (src/game/ai/hunter.lua); lifting off, it climbs
-- straight out for the level's hopTime first.
--
-- Modes on `state.mode`: "orbit" <-> "attack" while flying, "evade" while
-- threatened, "refuel" from low fuel until refilled. Thinks every
-- `reactionDelay` seconds and holds the intent in between; levels differ
-- only by config numbers (flightHorizon, dangerHorizon, predictionHorizon,
-- hopTime). No randomness of its own beyond Basic.shoot's aim error.
local Bodies = require("src.sim.bodies")
local Field = require("src.sim.field")
local Poly = require("src.core.poly")
local Lander = require("src.game.components.lander")
local Basic = require("src.game.ai.basic")
local Danger = require("src.game.ai.skills.danger")
local Flight = require("src.game.ai.skills.flight")
local Stuck = require("src.game.ai.skills.stuck")
local Trajectory = require("src.game.ai.skills.trajectory")

local Skirmisher = {}

local function clamp(value, low, high)
	return math.max(low, math.min(high, value))
end

-- The soonest threat of one of `kinds` within `horizon` seconds, or nil.
local function firstOf(threats, kinds, horizon)
	for _, threat in ipairs(threats) do
		if threat.time > horizon then
			return nil
		elseif kinds[threat.kind] then
			return threat
		end
	end
	return nil
end

local INCOMING = { shell = true, asteroid = true }
local IMPACT = { world = true, boundary = true }

-- Squared distance from (px, py) to the segment a-b.
local function segmentDist2(px, py, a, b)
	local ex, ey = b.x - a.x, b.y - a.y
	local len2 = ex * ex + ey * ey
	local t = len2 > 0 and clamp(((px - a.x) * ex + (py - a.y) * ey) / len2, 0, 1) or 0
	local dx, dy = a.x + ex * t - px, a.y + ey * t - py
	return dx * dx + dy * dy
end

-- True when `point` lies inside a world or within `clearance` px of one.
local function blocked(worlds, point, clearance)
	local c2 = clearance * clearance
	for _, world in ipairs(worlds) do
		local vertices = world.vertices
		if Poly.pointInPolygon(vertices, point) then
			return true
		end
		local n = #vertices
		for i = 1, n do
			if segmentDist2(point.x, point.y, vertices[i], vertices[i % n + 1]) <= c2 then
				return true
			end
		end
	end
	return false
end

local function onCircle(target, angle, radius)
	return { x = target.x + math.sin(angle) * radius, y = target.y - math.cos(angle) * radius }
end

-- The point to fly for: on the circle round `target` ({ x, y }) at the
-- body's distance kept within [orbitMin, orbitMax], orbitLead rad further
-- round in the direction state.orbitDir (1 = clockwise, the default).
-- Where that point is blocked by a world the direction flips; blocked both
-- ways, it is the point straight above the target against its pull.
function Skirmisher.orbitGoal(ctx, body, target, state)
	local ai = ctx.config.ai
	local dx, dy = body.x - target.x, body.y - target.y
	local radius = clamp(math.sqrt(dx * dx + dy * dy), ai.orbitMin, ai.orbitMax)
	local pull = Field.sample(ctx.sim.field, target.x, target.y)
	local up = Flight.angleOf(-pull.x, -pull.y)
	local around = (dx ~= 0 or dy ~= 0) and Flight.angleOf(dx, dy) or up
	state.orbitDir = state.orbitDir or 1
	for _ = 1, 2 do
		local goal = onCircle(target, around + state.orbitDir * ai.orbitLead, radius)
		if not blocked(ctx.level.worlds, goal, ai.orbitClearance) then
			return goal
		end
		state.orbitDir = -state.orbitDir
	end
	return onCircle(target, up, radius)
end

-- The enemy it circles, kept on state.quarry until that ship dies: chasing
-- whichever enemy is nearest swings it to and fro between two of them.
local function quarry(ctx, body, state)
	local held = state.quarry
	if not (held and not held.dead and Bodies.get(ctx.sim.bodies, held.body)) then
		held = nil
		local bestDist
		for _, other in ipairs(ctx.pools.ships) do
			local otherBody = not other.dead and other ~= state.ship and Bodies.get(ctx.sim.bodies, other.body)
			if otherBody then
				local dx, dy = otherBody.x - body.x, otherBody.y - body.y
				local dist = dx * dx + dy * dy
				if not bestDist or dist < bestDist then
					held, bestDist = other, dist
				end
			end
		end
		state.quarry = held
	end
	return held and Bodies.get(ctx.sim.bodies, held.body)
end

local function fly(ctx, ship, body, level, goal)
	return (Flight.flyTo(ctx.sim, ctx.level.worlds, body, goal, ctx.config, {
		fuel = ship.fuel,
		hold = level.reactionDelay,
		dt = ctx.dt,
		horizon = level.flightHorizon,
	}))
end

local function lowFuel(ctx, ship)
	local reserve = ctx.config.ai.refuelFuel
	if ctx.hardcore then
		reserve = reserve + ctx.config.ai.hardcoreReserve
	end
	return ship.fuel.amount < reserve
end

-- Config as the weapon would be with a skirmishCharge-second charge cap:
-- Aim.solve then only searches shells that fast, and the charge it returns
-- (a share of the capped chargeTime) launches at the speed it solved for.
local quickConfigs = setmetatable({}, { __mode = "k" })
local function quickConfig(config)
	local quick = quickConfigs[config]
	if not quick then
		local weapon = config.weapon
		local share = config.ai.skirmishCharge / weapon.chargeTime
		quick = setmetatable({
			weapon = setmetatable({
				chargeTime = config.ai.skirmishCharge,
				maxSpeed = weapon.minSpeed + (weapon.maxSpeed - weapon.minSpeed) * share,
			}, { __index = weapon }),
		}, { __index = config })
		quickConfigs[config] = quick
	end
	return quick
end

-- Basic.shoot with quick charges, fire and charge dropped unless the aim is
-- a solved shot (or the skirmisher is stuck). An intent is held for whole
-- steps -- reactionDelay rounded up to one -- and Basic.shoot is told so:
-- turning for a shorter hold than it gets, the nose overshoots each held
-- turn and can swing round the aim without ever settling inside
-- fireTolerance, which a ship turning off a fast orbit does all the time.
local function quickShot(ctx, ship, body, level, state)
	local quick = setmetatable({ config = quickConfig(ctx.config) }, { __index = ctx })
	local steps = math.max(1, math.ceil(level.reactionDelay / ctx.dt - 1e-6))
	local held = setmetatable({ reactionDelay = steps * ctx.dt }, { __index = level })
	local intent = Basic.shoot(quick, ship, body, held, state)
	if not (state.aim and state.aim.solved) and Stuck.cycles(ctx, state) < 1 then
		intent.fire = false
		state.charging = false
	end
	return intent
end

-- Flying ships fire from the nose, 10 px ahead of the centre
-- (src/game/systems/ship_system.lua).
local NOSE_LENGTH = 10

-- False when a shell let go from the nose now, at the charge held so far,
-- would strike a world within config.ai.skirmishSafety seconds -- close
-- enough for its blast to reach the ship.
local function safeRelease(ctx, ship, body)
	local weapon, config = ship.weapon, ctx.config
	local share = math.min(1, (weapon.charge or 0) / config.weapon.chargeTime)
	local speed = config.weapon.minSpeed + (config.weapon.maxSpeed - config.weapon.minSpeed) * share
	local dx, dy = math.sin(body.angle), -math.cos(body.angle)
	local shell = {
		x = body.x + dx * NOSE_LENGTH,
		y = body.y + dy * NOSE_LENGTH,
		vx = body.vx + dx * speed,
		vy = body.vy + dy * speed,
		radius = config.projectile.radius,
	}
	local steps = math.max(1, math.ceil(config.ai.skirmishSafety / ctx.dt))
	return Trajectory.simulate(ctx.sim, ctx.level.worlds, shell, ctx.dt, steps).stop ~= "world"
end

-- In flight, near worlds and turning off a fast orbit, a loose aim can
-- point the nose into rock: a shot that would start or be let go there
-- is held back -- not started, or kept charging -- until it is safe.
local function guardRelease(ctx, ship, body, state, intent)
	local charging = ship.weapon and ship.weapon.charging or false
	if Lander.isGrounded(ship) or intent.fire == charging or safeRelease(ctx, ship, body) then
		return intent
	end
	intent.fire = charging
	if not charging then
		state.charging = false
	end
	return intent
end

local function think(ctx, ship, body, level, state)
	local config = ctx.config

	if Lander.isGrounded(ship) then
		if state.mode == "refuel" and ship.fuel.amount < config.ai.takeoffFuel then
			local intent = quickShot(ctx, ship, body, level, state)
			intent.thrust = false
			return intent
		end
		state.mode = "orbit"
		state.charging = false
		state.liftUntil = ctx.time + level.hopTime
		return Flight.liftOff()
	end
	-- A one-think lift-off falls back onto the surface before a near
	-- orbit point asks for much thrust: climb straight out for hopTime.
	if ctx.time < (state.liftUntil or 0) then
		return Flight.liftOff()
	end

	-- Shells and asteroids count within the level's dangerHorizon; the scan
	-- reaches attackClearance too, so an attack never coasts into a world.
	local horizon = math.max(level.dangerHorizon, config.ai.attackClearance)
	local threats = Danger.scan(ctx.sim, ctx.level.worlds, body, config, { dt = ctx.dt, horizon = horizon })
	if state.mode == "refuel" or lowFuel(ctx, ship) then
		state.mode = "refuel"
		state.charging = false
		return Flight.land(ctx.sim, body, threats, config, { fuel = ship.fuel, hold = level.reactionDelay })
	end

	local threat = firstOf(threats, INCOMING, level.dangerHorizon)
	if threat then
		state.mode = "evade"
		state.charging = false
		return fly(ctx, ship, body, level, Flight.evadeGoal(ctx.sim, body, threat, config))
	end

	local target = Basic.nearestEnemy(ctx, ship, body)
	if not target then
		state.mode = "orbit"
		return Flight.land(ctx.sim, body, threats, config, { fuel = ship.fuel, hold = level.reactionDelay })
	end

	local clear = not firstOf(threats, IMPACT, config.ai.attackClearance)
	local shellAlive = ship.weapon and ship.weapon.shell and Bodies.get(ctx.sim.bodies, ship.weapon.shell)
	local inBand = target.dist >= 2 * config.projectile.blastRadius and target.dist <= config.ai.orbitMax
	if clear and inBand and (state.charging or not shellAlive) then
		local intent = quickShot(ctx, ship, body, level, state)
		if state.aim.solved or Stuck.cycles(ctx, state) >= 1 then
			state.mode = "attack"
			return intent
		end
	end

	state.mode = "orbit"
	state.charging = false
	return fly(ctx, ship, body, level, Skirmisher.orbitGoal(ctx, body, quarry(ctx, body, state) or target, state))
end

-- Writes ctx.intents[slot]. Re-thinks once ctx.time reaches state.nextThink;
-- otherwise the previous intent stays on ctx.intents.
function Skirmisher.update(ctx, slot, ship, level, state)
	local body = Bodies.get(ctx.sim.bodies, ship.body)
	if not body then
		return
	end
	if ctx.time >= state.nextThink then
		state.intent = guardRelease(ctx, ship, body, state, think(ctx, ship, body, level, state))
		if state.intent.fire then
			Stuck.fired(ctx, state)
		end
		state.nextThink = ctx.time + level.reactionDelay
	end
	local held = state.intent
	ctx.intents[slot] = { rotate = held.rotate, thrust = held.thrust, fire = held.fire }
end

return Skirmisher
