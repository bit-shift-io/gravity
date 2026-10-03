-- Danger sensing for AI ships: what will hit this ship, and when, if nothing
-- changes course. Shells and asteroids are flown forward with
-- src/game/ai/skills/trajectory.lua (asteroids feel the world field only, as
-- in Sim.integrate); a flying ship's own coasting path is flown the same way,
-- so the world it would strike or the hard boundary it would cross count too.
-- A landed (pinned) ship stays put and never reports worlds or the boundary.
-- Thrust is never predicted. Pure: reads the sim, never writes bodies. No
-- `love.*` (docs/ARCHITECTURE.md "Layers").
local Trajectory = require("src.game.ai.skills.trajectory")

local Danger = {}

local function speedAt(path, start, i, dt)
	local prev = path.points[i - 1] or start
	local p = path.points[i]
	local vx, vy = (p.x - prev.x) / dt, (p.y - prev.y) / dt
	return vx, vy
end

local function threat(kind, path, start, i, dt)
	local p = path.points[i]
	local vx, vy = speedAt(path, start, i, dt)
	return { kind = kind, time = i * dt, x = p.x, y = p.y, vx = vx, vy = vy, speed = math.sqrt(vx * vx + vy * vy) }
end

-- The ship's position after step i: its predicted path, held at the last
-- point once that path ends (it has landed or crashed by then).
local function shipAt(own, i)
	return own.points[math.min(i, #own.points)] or own.start
end

-- First step where `path` comes within `reach` of the ship, or nil.
local function contact(path, own, reach)
	local r2 = reach * reach
	for i, p in ipairs(path.points) do
		local s = shipAt(own, i)
		local dx, dy = p.x - s.x, p.y - s.y
		if dx * dx + dy * dy <= r2 then
			return i
		end
	end
	return nil
end

local function bodyPath(sim, worlds, body, dt, steps)
	local start = { x = body.x, y = body.y, vx = body.vx, vy = body.vy, radius = body.radius or 0 }
	return Trajectory.simulate(sim, worlds, start, dt, steps), start
end

-- `body` is the AI's own ship body (`radius` is its contact circle);
-- `opts` is `{ dt, horizon }` (horizon in seconds). Returns a list of
-- `{ kind = "shell" | "asteroid" | "world" | "boundary", time, x, y, vx, vy,
-- speed }`, soonest first: time to impact in seconds, and the threat's
-- position and velocity at impact (the ship's own, for "world" and
-- "boundary" -- `speed` is then the impact speed the landing check reads).
-- A shell threatens on contact or when it detonates on a world within blast
-- radius of the ship.
function Danger.scan(sim, worlds, body, config, opts)
	local threats = {}
	if opts.dt <= 0 then
		return threats
	end
	local dt = opts.dt
	local steps = math.floor(opts.horizon / dt)
	local radius = body.radius or 0

	local own = { points = {}, start = { x = body.x, y = body.y } }
	if not body.pinned then
		local path, start = bodyPath(sim, worlds, body, dt, steps)
		own.points = path.points
		if path.stop == "world" or path.stop == "boundary" then
			threats[#threats + 1] = threat(path.stop, path, start, #path.points, dt)
		end
	end

	local worldOnly = { field = sim.field }
	local blast = config.projectile.blastRadius
	local store = sim.bodies
	for slot = 1, store.slotCount do
		local other = store.slots[slot]
		if other and other ~= body and not other.dead then
			if other.kind == "projectile" then
				local path, start = bodyPath(sim, worlds, other, dt, steps)
				local i = contact(path, own, radius + (other.radius or 0))
				if not i and path.stop == "world" then
					local last = #path.points
					local p, s = path.points[last], shipAt(own, last)
					local dx, dy = p.x - s.x, p.y - s.y
					if dx * dx + dy * dy <= blast * blast then
						i = last
					end
				end
				if i then
					threats[#threats + 1] = threat("shell", path, start, i, dt)
				end
			elseif other.kind == "asteroid" then
				local path, start = bodyPath(worldOnly, worlds, other, dt, steps)
				local i = contact(path, own, radius + (other.radius or 0))
				if i then
					threats[#threats + 1] = threat("asteroid", path, start, i, dt)
				end
			end
		end
	end

	table.sort(threats, function(a, b)
		return a.time < b.time
	end)
	return threats
end

return Danger
