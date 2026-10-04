require("src.game.ai.init")
local Match = require("src.game.match")
local Config = require("src.game.config")
local Bodies = require("src.sim.bodies")

local DT = 1 / 60

-- A floor about as heavy as a generated world (top edge y = 100); spawn
-- points on it at (-200, 100) and (200, 100), normals straight up.
local function floorLevel()
	local floor = {
		vertices = { { x = -600, y = 100 }, { x = 600, y = 100 }, { x = 600, y = 200 }, { x = -600, y = 200 } },
		mass = 40000,
	}
	local function point(x)
		return { x = x, y = 100, normal = { x = 0, y = -1 }, world = floor }
	end
	return { worlds = { floor }, spawnPoints = { point(-200), point(200) } }
end

-- Rounds never end, so a kill doesn't respawn anyone mid-scenario.
local function endless(config)
	return setmetatable({ round = setmetatable({ endDelay = math.huge }, { __index = Config.round }) }, { __index = config })
end

-- Slot 1 is a keyboard enemy that never moves; slot 2 a kamikaze at
-- `level`. `config` may override Config.
local function newKamikaze(level, config)
	local roster = {
		{ color = 1, binding = { kind = "keyboard", layout = "wasd" } },
		{ color = 2, binding = { kind = "ai", level = level, behavior = "kamikaze" } },
	}
	local ctx = Match.new(floorLevel(), endless(config or Config), 1, { roster = roster })
	ctx.dt = DT
	return ctx
end

local function distance(a, b)
	local dx, dy = a.x - b.x, a.y - b.y
	return math.sqrt(dx * dx + dy * dy)
end

-- Steps until `stop(ctx)` is true or `seconds` pass; the enemy stays idle.
local function run(ctx, seconds, stop)
	for _ = 1, seconds * 60 do
		ctx.intents[1] = { rotate = 0, thrust = false, fire = false }
		Match.step(ctx)
		ctx.time = ctx.time + ctx.dt
		if stop(ctx) then
			return true
		end
	end
	return false
end

-- A kamikaze that is never stuck, so only point-blank range sets it off.
local function patient()
	return setmetatable({ ai = setmetatable({ stuckDelay = math.huge }, { __index = Config.ai }) }, { __index = Config })
end

for _, level in ipairs({ "easy", "hard" }) do
	test((level == "easy" and "an " or "a ") .. level .. " kamikaze closes to point-blank range before it fires", function()
		local ctx = newKamikaze(level, patient())
		local enemy, own = ctx.pools.ships[1], ctx.pools.ships[2]
		local enemyBody, ownBody = Bodies.get(ctx.sim.bodies, enemy.body), Bodies.get(ctx.sim.bodies, own.body)
		local firedAt

		local fired = run(ctx, 10, function()
			if own.weapon.shell then
				firedAt = distance(enemyBody, ownBody)
				return true
			end
		end)

		assertTrue(fired, "fired at all")
		assertTrue(firedAt <= Config.ai.kamikazeRange, "fired from " .. tostring(firedAt) .. " px")
	end)

	test((level == "easy" and "an " or "a ") .. level .. " kamikaze's point-blank shell blasts the enemy only once armed", function()
		local ctx = newKamikaze(level)
		local enemy, own = ctx.pools.ships[1], ctx.pools.ships[2]
		local shellId, armed, wentOff

		run(ctx, Config.ai.stuckDelay + 2, function()
			shellId = shellId or own.weapon.shell
			local shell = shellId and Bodies.get(ctx.sim.bodies, shellId)
			if shell then
				armed = shell.armed
			elseif shellId then
				wentOff = true
				return true
			end
		end)

		assertTrue(wentOff, "the shell went off")
		assertTrue(armed, "armed the step before it went off")
		assertTrue(enemy.dead, "the enemy died in the blast")
	end)
end

-- A kamikaze whose point-blank range is too short to ever reach.
local function unreachableConfig()
	return setmetatable({ ai = setmetatable({ kamikazeRange = 0 }, { __index = Config.ai }) }, { __index = Config })
end

test("a kamikaze that can't close in fires once it is stuck", function()
	local config = unreachableConfig()
	local ctx = newKamikaze("hard", config)
	local own = ctx.pools.ships[2]
	local firedAt

	run(ctx, config.ai.stuckDelay + 3, function()
		if own.weapon.shell then
			firedAt = ctx.time
			return true
		end
	end)

	assertTrue(firedAt ~= nil, "fires at all")
	assertTrue(firedAt >= config.ai.stuckDelay, "fired at " .. tostring(firedAt) .. ", before it was stuck")
end)
