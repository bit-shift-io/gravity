local Blast = require("src.game.blast")
local Bodies = require("src.sim.bodies")
local Config = require("src.game.config")
local TankOutline = require("src.core.tank_outline")

local function blastShip(shipFields)
	local bodies = Bodies.new()
	local ctx = {
		dt = 1 / 60,
		time = 0,
		sim = { bodies = bodies },
		pools = { ships = {}, projectiles = {}, asteroids = {} },
		config = Config,
		events = {},
	}
	local body = { x = 0, y = 0, vx = 0, vy = 0, angle = 0.5, mass = 1000, kind = "ship", radius = 9 }
	local id = Bodies.add(bodies, body)
	local ship = { id = id, body = id, player = 1, dead = false }
	for k, v in pairs(shipFields) do
		ship[k] = v
	end
	table.insert(ctx.pools.ships, ship)
	local pBody = { x = 5, y = 0, vx = 0, vy = 0, angle = 0, mass = 0.001, kind = "projectile", radius = 3 }
	local pId = Bodies.add(bodies, pBody)
	local projectile = { id = pId, body = pId, shooter = -1, dead = false, age = 0 }
	table.insert(ctx.pools.projectiles, projectile)
	Blast.detonate(ctx, projectile, pBody)
	for _, e in ipairs(ctx.events) do
		if e.kind == "crash" then
			return e
		end
	end
end

test("a tank killed by a blast crashes as its dome-and-barrel outline at the turret's pose", function()
	local event = blastShip({ lander = { state = "tank" }, turret = { angle = 0.7 } })
	local tank = Config.tank
	local expected = TankOutline.build(tank.dome, 0.7, tank.barrelLength, tank.barrelHalfWidth)
	assertEqual(#expected, #event.vertices)
	for i, p in ipairs(expected) do
		assertNear(p.x, event.vertices[i].x, 1e-9)
		assertNear(p.y, event.vertices[i].y, 1e-9)
	end
end)

test("a flying ship killed by a blast crashes with no custom outline", function()
	local event = blastShip({ lander = { state = "flying" } })
	assertEqual(nil, event.vertices)
end)
