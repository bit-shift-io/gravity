local ThrusterEffect = require("src.game.components.thruster_effect")
local Bodies = require("src.sim.bodies")
local Collide = require("src.sim.collide")
local Config = require("src.game.config")
local Rng = require("src.core.rng")
local Vec2 = require("src.core.vec2")

local ANGLES = { 0, math.pi / 2, math.pi, -0.7, 2.4 }

local function newShip(bodies, angle, vx, vy)
	local bodyId = Bodies.add(bodies, { x = 300, y = 200, vx = vx or 0, vy = vy or 0, angle = angle })
	return { body = bodyId, player = 1, thrusterEffect = {} }
end

local function newCtx(bodies, seed)
	return { config = Config, sim = { bodies = bodies }, rng = Rng.new(seed or 1) }
end

-- Rear edge of the hull derived from SHIP_SHAPE the same way the component
-- should: the edge whose midpoint lies furthest behind the nose.
local function rearEdgeWorld(body)
	local pts = Collide.transform(Collide.SHIP_SHAPE, body.x, body.y, body.angle)
	local best, bestScore
	for i = 1, #pts do
		local a, b = Collide.SHIP_SHAPE[i], Collide.SHIP_SHAPE[i % #pts + 1]
		local score = (a.y + b.y) / 2 -- local y grows toward the rear
		if not bestScore or score > bestScore then
			best, bestScore = i, score
		end
	end
	return pts[best], pts[best % #pts + 1]
end

test("ThrusterEffect.emit places points on the rear edge within its centre 50%", function()
	for _, angle in ipairs(ANGLES) do
		local bodies = Bodies.new()
		local ship = newShip(bodies, angle)
		local ctx = newCtx(bodies, 7)
		local body = Bodies.get(bodies, ship.body)
		local a, b = rearEdgeWorld(body)
		local edge = Vec2.sub(b, a)
		local len2 = Vec2.dot(edge, edge)

		for _ = 1, 50 do
			local pos = ThrusterEffect.emit(ship, ctx)
			local rel = Vec2.sub(pos, a)
			local t = Vec2.dot(rel, edge) / len2
			local off = rel.x * edge.y - rel.y * edge.x
			assertNear(0, off / math.sqrt(len2), 1e-6)
			assertTrue(t >= 0.25 - 1e-9 and t <= 0.75 + 1e-9, "t=" .. t .. " outside centre 50% at angle " .. angle)
		end
	end
end)

test("ThrusterEffect.emit velocity is ship velocity plus exhaust along the rotated rear normal", function()
	local spread = Config.thrusterEffect.spreadSpeed
	local speed = Config.thrusterEffect.exhaustSpeed
	for _, angle in ipairs(ANGLES) do
		local bodies = Bodies.new()
		local ship = newShip(bodies, angle, 30, -12)
		local ctx = newCtx(bodies, 3)
		local rearNormal = Vec2.rotate({ x = 0, y = 1 }, angle)
		local sideways = { x = -rearNormal.y, y = rearNormal.x }

		for _ = 1, 20 do
			local _, vel = ThrusterEffect.emit(ship, ctx)
			local rel = { x = vel.x - 30, y = vel.y + 12 }
			assertNear(speed, Vec2.dot(rel, rearNormal), 1e-6)
			assertTrue(math.abs(Vec2.dot(rel, sideways)) <= spread + 1e-9, "sideways spread exceeds config")
		end
	end
end)
