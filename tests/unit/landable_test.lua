local Landable = require("src.game.components.landable")
local Vec2 = require("src.core.vec2")

test("Landable.surfaceVelocityAt returns zero for a static world host", function()
	local world = { vertices = {} }
	local v = Landable.surfaceVelocityAt(world, { x = 5, y = 5 })

	assertNear(0, v.x)
	assertNear(0, v.y)
end)

test("Landable.surfaceVelocityAt at the rim of a spinning static asteroid equals omega x r", function()
	local host = { x = 0, y = 0, vx = 0, vy = 0, angularVelocity = 2, angle = 0 }
	local point = { x = 0, y = -10 } -- r = (0, -10), offset from host centre

	local v = Landable.surfaceVelocityAt(host, point)

	-- omega x r in this codebase's convention (matching src/core/vec2.lua's
	-- Vec2.rotate and src/sim/integrate.lua's angle += angularVelocity * dt):
	-- v = omega * (-r.y, r.x).
	assertNear(host.angularVelocity * 10, v.x, 0.0001)
	assertNear(0, v.y, 0.0001)
end)

test("Landable.surfaceVelocityAt matches the finite-difference derivative of Vec2.rotate", function()
	local host = { x = 0, y = 0, vx = 0, vy = 0, angularVelocity = 1.7, angle = 0 }
	local r = { x = 3, y = -4 }
	local point = { x = host.x + r.x, y = host.y + r.y }

	local v = Landable.surfaceVelocityAt(host, point)

	local dt = 0.0001
	local rAfter = Vec2.rotate(r, host.angularVelocity * dt)
	local approxV = { x = (rAfter.x - r.x) / dt, y = (rAfter.y - r.y) / dt }

	assertNear(approxV.x, v.x, 0.01)
	assertNear(approxV.y, v.y, 0.01)
end)

test("Landable.surfaceVelocityAt adds the host's own linear velocity", function()
	local host = { x = 0, y = 0, vx = 12, vy = -5, angularVelocity = 0, angle = 0 }
	local v = Landable.surfaceVelocityAt(host, { x = 100, y = 100 })

	assertNear(12, v.x)
	assertNear(-5, v.y)
end)

test("Landable.refuelMultiplier reads an asteroid host's own multiplier", function()
	local asteroid = { refuelMultiplier = 2.5 }
	assertNear(2.5, Landable.refuelMultiplier(asteroid))
end)

test("Landable.refuelMultiplier defaults to 1 for a world with no override", function()
	assertNear(1, Landable.refuelMultiplier({}))
end)
