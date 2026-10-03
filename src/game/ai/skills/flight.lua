-- Flight control for AI ships: intents for lifting off, steering, flying
-- to a point clear of worlds and the boundary, and landing gently
-- (docs/CONTEXT.md "Landing": only touchdown speed is checked). Landing reads the ship's own impact threats from
-- src/game/ai/skills/danger.lua, brakes only when the coasting touchdown
-- would be faster than config.ai.landSpeed, and thrusts toward a world when
-- none is in sight. Pure -- reads the sim, returns intents,
-- never writes bodies. No `love.*` (docs/ARCHITECTURE.md "Layers").
local Field = require("src.sim.field")
local Fuel = require("src.game.components.fuel")
local Trajectory = require("src.game.ai.skills.trajectory")

local Flight = {}

local atan2 = math.atan2 or function(y, x)
	return math.atan(y, x)
end

local function wrap(angle)
	return (angle + math.pi) % (2 * math.pi) - math.pi
end

-- A tank's thrust lifts it straight up its surface normal (the body faces
-- the normal in tank mode); steering comes after, in flight.
function Flight.liftOff()
	return { rotate = 0, thrust = true, fire = false }
end

-- World angle (0 = up) of the direction (dx, dy).
function Flight.angleOf(dx, dy)
	return atan2(dx, -dy)
end

-- Rotate intent turning `body` toward world angle `want`, holding still
-- within half of what `hold` seconds of turning covers, so a held intent
-- never overshoots by more than that. Returns rotate and the remaining error.
function Flight.steer(body, want, config, hold)
	local err = wrap(want - body.angle)
	local halfStep = config.ship.rotationSpeed * hold / 2
	if err > halfStep then
		return 1, err
	elseif err < -halfStep then
		return -1, err
	end
	return 0, err
end

-- The point config.ai.evadeDistance px across a threat's path (a Danger.scan
-- entry), on the side `body` already sits (against the local pull when dead
-- on): a Flight.flyTo goal for dodging it.
function Flight.evadeGoal(sim, body, threat, config)
	local px, py = threat.vy, -threat.vx
	local len = math.sqrt(px * px + py * py)
	if len > 1e-9 then
		px, py = px / len, py / len
	end
	local side = (body.x - threat.x) * px + (body.y - threat.y) * py
	if math.abs(side) < 1e-6 then
		local pull = Field.sample(sim.field, body.x, body.y)
		side = -(pull.x * px + pull.y * py)
	end
	if side < 0 then
		px, py = -px, -py
	end
	local reach = config.ai.evadeDistance
	return { x = body.x + px * reach, y = body.y + py * reach }
end

-- Burn now when the coasting touchdown is too fast and no later burn could
-- shed the excess: braking with thrust over distance d removes
-- 2 * accel * d of squared speed, counting on only config.ai.brakeShare of
-- the thrust (turning and rising pull eat the rest).
local function burnWindow(body, impact, config)
	local landSpeed = config.ai.landSpeed
	local excess = impact.speed * impact.speed - landSpeed * landSpeed
	local dx, dy = impact.x - body.x, impact.y - body.y
	local dist = math.sqrt(dx * dx + dy * dy)
	return dist <= excess / (2 * config.ship.thrustAccel * config.ai.brakeShare)
end

local function firstImpact(threats)
	for _, threat in ipairs(threats) do
		if threat.kind == "world" or threat.kind == "boundary" then
			return threat
		end
	end
	return nil
end

-- Intent bringing a flying `body` down gently. `threats` is Danger.scan's
-- list for this body; `opts` is `{ fuel, hold }` -- the ship's fuel record
-- and the seconds the intent will be held. Heading for a too-fast
-- touchdown it turns retrograde early and burns late; heading for a soft
-- one it coasts upright against the local pull. Heading out of the arena,
-- or fast away from the pull with no world in sight, it brakes now; slow
-- with no world in sight, it thrusts down the pull toward one.
function Flight.land(sim, body, threats, config, opts)
	local landSpeed = config.ai.landSpeed
	local impact = firstImpact(threats)
	local pull = Field.sample(sim.field, body.x, body.y)
	local retro = { x = -body.vx, y = -body.vy }
	local face, thrust
	if impact and impact.kind == "boundary" then
		face, thrust = retro, true
	elseif impact and impact.speed > landSpeed then
		face, thrust = retro, burnWindow(body, impact, config)
	elseif impact then
		face, thrust = { x = -pull.x, y = -pull.y }, false
	elseif body.vx * body.vx + body.vy * body.vy > landSpeed * landSpeed then
		-- Fast: brake when moving away from the pull, else coast in nose-first
		-- for the burn.
		face, thrust = retro, body.vx * pull.x + body.vy * pull.y < 0
	else
		face, thrust = pull, true
	end
	local rotate, err = Flight.steer(body, Flight.angleOf(face.x, face.y), config, opts.hold)
	-- Steering holds still within half a held turn, so thrust is allowed
	-- at least that far off.
	local tolerance = math.max(config.ai.thrustTolerance, config.ship.rotationSpeed * opts.hold / 2)
	return {
		rotate = rotate,
		thrust = thrust and math.abs(err) <= tolerance and not Fuel.isEmpty(opts.fuel),
		fire = false,
	}
end

-- The thrust (px/s^2, before the burn decision) that turns velocity
-- (vx, vy) toward travel angle `travel` at the speed suited to `dist` px
-- from the goal -- cruiseSpeed, or less where braking at brakeShare of
-- thrust must start -- over flightTau seconds, cancelling the local pull.
local function wantedThrust(config, vx, vy, pull, travel, dist)
	local ai = config.ai
	local speed = math.min(ai.cruiseSpeed, math.sqrt(2 * config.ship.thrustAccel * ai.brakeShare * dist))
	local wx, wy = math.sin(travel) * speed, -math.cos(travel) * speed
	return (wx - vx) / ai.flightTau - pull.x, (wy - vy) / ai.flightTau - pull.y
end

local function bearing(x, y, target)
	local dx, dy = target.x - x, target.y - y
	return Flight.angleOf(dx, dy), math.sqrt(dx * dx + dy * dy)
end

-- Intent steering toward, and burning for, wantedThrust along travel angle
-- `angle` with `dist` px to go; `opts` is `{ fuel, hold }`.
local function travel(body, pull, angle, dist, config, opts)
	local ai = config.ai
	local ax, ay = wantedThrust(config, body.vx, body.vy, pull, angle, dist)
	local rotate, err = Flight.steer(body, Flight.angleOf(ax, ay), config, opts.hold)
	local tolerance = math.max(ai.thrustTolerance, config.ship.rotationSpeed * opts.hold / 2)
	local minThrust = ai.thrustShare * config.ship.thrustAccel
	return {
		rotate = rotate,
		thrust = ax * ax + ay * ay >= minThrust * minThrust and math.abs(err) <= tolerance and not Fuel.isEmpty(opts.fuel),
		fire = false,
	}
end

-- Flies the ship's own path for `steps` steps of `dt`, travelling
-- `offset` rad off the bearing to `target` (re-taken every step): the nose
-- turns at rotationSpeed toward the wanted thrust, and burns once within
-- thrustTolerance of it while the tank lasts. Returns Trajectory's path.
local function predict(sim, worlds, body, target, offset, config, fuel, dt, steps)
	local ai, ship = config.ai, config.ship
	local nose = body.angle
	local burnable = fuel.amount / fuel.burnRate
	local turn = ship.rotationSpeed * dt
	local minThrust = ai.thrustShare * ship.thrustAccel
	local function push(flown, accel)
		local angle, dist = bearing(flown.x, flown.y, target)
		local ax, ay = wantedThrust(config, flown.vx, flown.vy, accel, angle + offset, dist)
		local err = wrap(Flight.angleOf(ax, ay) - nose)
		nose = nose + math.max(-turn, math.min(turn, err))
		if burnable > 0 and ax * ax + ay * ay >= minThrust * minThrust and math.abs(err) <= ai.thrustTolerance then
			burnable = burnable - dt
			accel.x = accel.x + math.sin(nose) * ship.thrustAccel
			accel.y = accel.y - math.cos(nose) * ship.thrustAccel
		end
	end
	local start = { x = body.x, y = body.y, vx = body.vx, vy = body.vy, radius = body.radius or 0 }
	return Trajectory.simulate(sim, worlds, start, dt, steps, push)
end

-- Squared distance from (px, py) to the segment a-b.
local function segmentDist2(px, py, a, b)
	local ex, ey = b.x - a.x, b.y - a.y
	local len2 = ex * ex + ey * ey
	local t = len2 > 0 and math.max(0, math.min(1, ((px - a.x) * ex + (py - a.y) * ey) / len2)) or 0
	local dx, dy = a.x + ex * t - px, a.y + ey * t - py
	return dx * dx + dy * dy
end

-- True when any point of `path` passes within `clearance` px of a world's
-- edge (the predicted path is the ship's centre; its hull reaches further).
local function grazes(worlds, path, clearance)
	local c2 = clearance * clearance
	for _, world in ipairs(worlds) do
		local vertices = world.vertices
		local n = #vertices
		for _, p in ipairs(path.points) do
			for i = 1, n do
				if segmentDist2(p.x, p.y, vertices[i], vertices[i % n + 1]) <= c2 then
					return true
				end
			end
		end
	end
	return false
end

-- Intent flying a flying `body` toward the point `target` ({ x, y }),
-- arriving slowly. `opts` is `{ fuel, hold, dt, horizon }`: the ship's fuel
-- record, the seconds the intent will be held, and the step and seconds
-- its own thrusting path is predicted over. Travel straight at the target
-- is flown ahead first, then turns of detourStep rad off it, nearest first
-- and the side away from the local pull first, up to config.ai.detours
-- each side. The first whose path keeps flightClearance px from every
-- world and never crosses the hard boundary is flown, or, with none clear,
-- the one clear the longest. Returns the intent and the plan
-- `{ angle, clear }` (world travel angle now, 0 = up).
function Flight.flyTo(sim, worlds, body, target, config, opts)
	local ai = config.ai
	local steps = math.max(1, math.floor(opts.horizon / opts.dt))
	local pull = Field.sample(sim.field, body.x, body.y)
	local angle, dist = bearing(body.x, body.y, target)
	-- The detour side whose first turn points further against the pull.
	local function against(turn)
		local travel = angle + turn
		return -(math.sin(travel) * pull.x - math.cos(travel) * pull.y)
	end
	local first = against(ai.detourStep) >= against(-ai.detourStep) and 1 or -1

	local offset, clear, longest = 0, false, -1
	for k = 0, 2 * ai.detours do
		local candidate = math.ceil(k / 2) * (k % 2 == 1 and first or -first) * ai.detourStep
		local path = predict(sim, worlds, body, target, candidate, config, opts.fuel, opts.dt, steps)
		if path.stop == "horizon" and not grazes(worlds, path, ai.flightClearance) then
			offset, clear = candidate, true
			break
		elseif #path.points > longest then
			offset, longest = candidate, #path.points
		end
	end

	return travel(body, pull, angle + offset, dist, config, opts), { angle = wrap(angle + offset), clear = clear }
end

-- Intent flying a flying `body` straight at the point `target`, arriving
-- slowly, with no path check -- for the last stretch onto a surface, which
-- Flight.flyTo's world clearance would refuse. `opts` is `{ fuel, hold }`.
function Flight.approach(sim, body, target, config, opts)
	local angle, dist = bearing(body.x, body.y, target)
	return travel(body, Field.sample(sim.field, body.x, body.y), angle, dist, config, opts)
end

return Flight
