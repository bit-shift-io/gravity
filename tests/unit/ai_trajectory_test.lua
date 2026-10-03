local Trajectory = require("src.game.ai.skills.trajectory")
local Config = require("src.game.config")
local Field = require("src.sim.field")
local Bodies = require("src.sim.bodies")
local Sim = require("src.sim.step")

local DT = 1 / 60

-- A heavy square world centred at (0, 100), 120 px across.
local function blockWorld()
	return {
		vertices = { { x = -60, y = 40 }, { x = 60, y = 40 }, { x = 60, y = 160 }, { x = -60, y = 160 } },
		mass = 40000,
	}
end

local function newSim(worlds)
	local field, boundaryField = Field.bake({ worlds = worlds }, Config)
	return { field = field, boundaryField = boundaryField, bodies = Bodies.new() }
end

local function shell(x, y, vx, vy)
	return { x = x, y = y, vx = vx, vy = vy, radius = Config.projectile.radius }
end

test("a predicted shell path matches the sim's real flight past a world", function()
	local worlds = { blockWorld() }
	local sim = newSim(worlds)
	local start = shell(-300, -50, 250, 0)
	local id = Bodies.add(sim.bodies, {
		x = start.x, y = start.y, vx = start.vx, vy = start.vy,
		angle = 0, mass = Config.projectile.mass, kind = "projectile", radius = start.radius,
	})

	local path = Trajectory.simulate(sim, worlds, start, DT, 90)

	assertEqual(90, #path.points)
	for i = 1, 90 do
		Sim.integrate(sim, DT, Config)
		local body = Bodies.get(sim.bodies, id)
		assertNear(body.x, path.points[i].x, 1e-9)
		assertNear(body.y, path.points[i].y, 1e-9)
	end
	assertTrue(path.points[90].y > -50 + 5, "gravity bent the path toward the world")
end)

test("prediction stops at world contact", function()
	local worlds = { blockWorld() }
	local sim = newSim(worlds)

	local path = Trajectory.simulate(sim, worlds, shell(0, -100, 0, 200), DT, 600)

	assertEqual("world", path.stop)
	assertTrue(#path.points < 60, "hits the block within a second")
	assertTrue(path.points[#path.points].y >= 40, "last point reached the block's top")
end)

test("prediction stops at the hard boundary", function()
	local sim = newSim({})
	local hard = sim.boundaryField.hardBoundary

	local path = Trajectory.simulate(sim, {}, shell(hard - 20, 0, 3000, 0), DT, 600)

	assertEqual("boundary", path.stop)
	local last = path.points[#path.points]
	assertTrue(math.sqrt(last.x * last.x + last.y * last.y) > hard - Config.projectile.radius)
end)

test("prediction stops at the horizon when nothing is hit", function()
	local sim = newSim({})

	local path = Trajectory.simulate(sim, {}, shell(0, 0, 50, 0), DT, 30)

	assertEqual("horizon", path.stop)
	assertEqual(30, #path.points)
end)

local Aim = require("src.game.ai.skills.aim")

-- Shooter and target level with each other either side of the block, 600 px
-- apart: a shell aimed straight across sags into the block's pull.
local SHOOTER = { x = -300, y = -40, vx = 0, vy = 0, muzzle = Config.tank.barrelLength }
local TARGET = { x = 300, y = -40, radius = Config.ship.collisionRadius }
local HIT = TARGET.radius + Config.projectile.radius

local function closestApproach(path, target)
	local best = math.huge
	for _, p in ipairs(path.points) do
		local dx, dy = p.x - target.x, p.y - target.y
		best = math.min(best, math.sqrt(dx * dx + dy * dy))
	end
	return best
end

-- Flies a shot from SHOOTER at `angle` and `speed` the way the weapon spawns it.
local function fly(sim, worlds, angle, speed)
	local dx, dy = math.sin(angle), -math.cos(angle)
	local start = shell(
		SHOOTER.x + dx * SHOOTER.muzzle,
		SHOOTER.y + dy * SHOOTER.muzzle,
		SHOOTER.vx + dx * speed,
		SHOOTER.vy + dy * speed
	)
	return Trajectory.simulate(sim, worlds, start, DT, 600)
end

local function speedFor(charge)
	local w = Config.weapon
	return w.minSpeed + (w.maxSpeed - w.minSpeed) * math.min(1, charge / w.chargeTime)
end

test("a solved shot hits a stationary target that a straight shot misses", function()
	local worlds = { blockWorld() }
	local sim = newSim(worlds)
	local direct = math.pi / 2 -- straight along +x

	assertTrue(closestApproach(fly(sim, worlds, direct, Config.weapon.maxSpeed), TARGET) > HIT, "fixture: straight shot misses")

	local solution = Aim.solve(sim, worlds, SHOOTER, TARGET, Config, { dt = DT, horizon = 3 })

	assertTrue(solution ~= nil, "a hit exists")
	local path = fly(sim, worlds, solution.angle, speedFor(solution.charge))
	assertTrue(closestApproach(path, TARGET) <= HIT, "solved shot passes through the target")
end)

test("Aim.solve returns nil when no hit is found within the horizon", function()
	local worlds = { blockWorld() }
	local sim = newSim(worlds)

	assertEqual(nil, Aim.solve(sim, worlds, SHOOTER, TARGET, Config, { dt = DT, horizon = 0.5 }))
end)

test("Aim.solve finds no shot whose blast would reach the shooter", function()
	local worlds = { blockWorld() }
	local sim = newSim(worlds)
	-- An enemy sitting just inside blast radius: any hit kills the shooter too.
	local near = { x = SHOOTER.x + Config.projectile.blastRadius - 5, y = SHOOTER.y, radius = TARGET.radius }

	assertEqual(nil, Aim.solve(sim, worlds, SHOOTER, near, Config, { dt = DT, horizon = 3 }))
end)

test("the same inputs solve to the same angle and charge", function()
	local worlds = { blockWorld() }
	local sim = newSim(worlds)
	local a = Aim.solve(sim, worlds, SHOOTER, TARGET, Config, { dt = DT, horizon = 3 })
	local b = Aim.solve(sim, worlds, SHOOTER, TARGET, Config, { dt = DT, horizon = 3 })

	assertEqual(a.angle, b.angle)
	assertEqual(a.charge, b.charge)
end)

local AI = require("src.game.ai.init")
local Match = require("src.game.match")

-- Two tanks on small platforms with a heavy block between and below them:
-- slot 1 (an AI) at (-200, 0), slot 2 (an idle keyboard slot) at (200, -100).
-- A shell aimed straight at slot 2 sags into the block.
local function platform(x, y)
	return {
		vertices = { { x = x - 30, y = y }, { x = x + 30, y = y }, { x = x + 30, y = y + 20 }, { x = x - 30, y = y + 20 } },
		mass = 1000,
	}
end

local function gravityLevel()
	local left, right = platform(-200, 0), platform(200, -100)
	local block = {
		vertices = { { x = -50, y = 40 }, { x = 50, y = 40 }, { x = 50, y = 140 }, { x = -50, y = 140 } },
		mass = 30000,
	}
	local function point(world, x, y)
		return { x = x, y = y, normal = { x = 0, y = -1 }, world = world }
	end
	return { worlds = { left, right, block }, spawnPoints = { point(left, -200, 0), point(right, 200, -100) } }
end

-- `levelOverrides` replaces fields of the hard level's numbers.
local function hardConfig(levelOverrides)
	local hard = {}
	for k, v in pairs(Config.ai.levels.hard) do
		hard[k] = v
	end
	for k, v in pairs(levelOverrides or {}) do
		hard[k] = v
	end
	return setmetatable({
		ai = setmetatable({ levels = { hard = hard } }, { __index = Config.ai }),
	}, { __index = Config })
end

local function gravityMatch(config, seed)
	local roster = {
		{ color = 1, binding = { kind = "ai", level = "hard", behavior = "basic" } },
		{ color = 2, binding = { kind = "keyboard", layout = "wasd" } },
	}
	local ctx = Match.new(gravityLevel(), config, seed or 1, { roster = roster })
	ctx.dt = DT
	local places = { { x = -200, y = 0 }, { x = 200, y = -100 } }
	for slot, ship in ipairs(ctx.pools.ships) do
		local body = Bodies.get(ctx.sim.bodies, ship.body)
		body.x, body.y = places[ship.player].x, places[ship.player].y
	end
	return ctx
end

local function shipOf(ctx, slot)
	for _, ship in ipairs(ctx.pools.ships) do
		if ship.player == slot then
			return ship
		end
	end
end

local function directAngle()
	return math.atan2(200 - -200, -(-100 - 0))
end

test("basic falls back to a direct aim when no hit is found within the horizon", function()
	local config = hardConfig({ predictionHorizon = 0.05 })
	local ctx = gravityMatch(config)

	AI.fill(ctx)

	assertNear(directAngle(), ctx.ai[1].aim.angle, 1e-9)
	assertTrue(math.abs(ctx.ai[1].aimOffset) <= config.ai.levels.hard.aimError)
end)

test("basic aims along the solved shot when one is found", function()
	local ctx = gravityMatch(hardConfig())

	AI.fill(ctx)

	assertTrue(math.abs(ctx.ai[1].aim.angle - directAngle()) > 0.05, "aims off the straight line to allow for gravity")
end)

-- Steps the match until slot 2 dies or `seconds` pass; true when it died.
-- Holds the ship record: the despawn sweep drops it from the pool on death.
local function targetKilled(ctx, seconds)
	local target = shipOf(ctx, 2)
	for _ = 1, math.floor(seconds / DT) do
		Match.step(ctx)
		ctx.time = ctx.time + DT
		if target.dead then
			return true
		end
	end
	return false
end

test("a hard AI hits a target through gravity that the direct-aim AI misses", function()
	assertFalse(targetKilled(gravityMatch(hardConfig({ predictionHorizon = 0.05 })), 8), "direct aim misses")
	assertTrue(targetKilled(gravityMatch(hardConfig()), 8), "gravity-aware aim hits")
end)

-- Counts Aim.solve calls made by `fn`.
local function countSolves(fn)
	local real, calls = Aim.solve, 0
	Aim.solve = function(...)
		calls = calls + 1
		return real(...)
	end
	local ok, err = pcall(fn)
	Aim.solve = real
	if not ok then
		error(err, 0)
	end
	return calls
end

test("basic re-solves only when the shooter or target has moved", function()
	local ctx = gravityMatch(hardConfig())
	local target = Bodies.get(ctx.sim.bodies, shipOf(ctx, 2).body)

	local still = countSolves(function()
		AI.fill(ctx)
		ctx.time = 1
		AI.fill(ctx)
	end)
	assertEqual(1, still, "nothing moved: the first solve is reused")

	local moved = countSolves(function()
		target.x = target.x + 2 * Config.ship.collisionRadius
		ctx.time = 2
		AI.fill(ctx)
	end)
	assertEqual(1, moved, "target moved: solved again")
end)

test("Aim.solve returns nil instead of looping when dt is zero", function()
	local worlds = { blockWorld() }
	local sim = newSim(worlds)

	assertEqual(nil, Aim.solve(sim, worlds, SHOOTER, TARGET, Config, { dt = 0, horizon = 3 }))
end)
