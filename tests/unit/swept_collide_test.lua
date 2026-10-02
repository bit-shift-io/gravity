local Collide = require("src.sim.collide")
local Poly = require("src.core.poly")

-- Same flat square world as tests/unit/collide_test.lua's squareWorld():
-- x:[0,100], y:[0,100], top edge's outward normal points up (0,-1).
local function squareWorld()
	return {
		vertices = Poly.normalize({
			{ x = 0, y = 0 },
			{ x = 100, y = 0 },
			{ x = 100, y = 100 },
			{ x = 0, y = 100 },
		}),
	}
end

test("Collide.circleContact reports a contact when two circles overlap", function()
	local contact = Collide.circleContact(0, 0, 5, 8, 0, 5)

	assertTrue(contact ~= nil, "expected an overlap (distance 8 < radius sum 10)")
	assertNear(-1, contact.normal.x, 0.0001)
	assertNear(0, contact.normal.y, 0.0001)
end)

test("Collide.circleContact returns nil when two circles don't overlap", function()
	local contact = Collide.circleContact(0, 0, 5, 20, 0, 5)

	assertTrue(contact == nil)
end)

test("Collide.circleContact's normal points from b toward a", function()
	local contact = Collide.circleContact(8, 0, 5, 0, 0, 5)

	assertNear(1, contact.normal.x, 0.0001)
	assertNear(0, contact.normal.y, 0.0001)
end)

test("Collide.checkProjectileWorlds catches a fast projectile crossing a thin edge in one step", function()
	local world = squareWorld()
	-- One step at typical projectile speed (muzzleSpeed ~500px/s * 1/60s
	-- ~8px/frame is nowhere near enough to skip a whole 100px-wide world in
	-- one step, but a much faster body easily can -- this segment jumps
	-- from well above the world's top edge to well below it, well past the
	-- edge itself (y=0), in a single frame. Testing only the endpoint
	-- (Collide.checkShipWorlds's approach) would miss this collision
	-- entirely since the endpoint alone is deep inside the world; the swept
	-- test must catch the crossing.
	local contact = Collide.checkProjectileWorlds(55, -500, 55, 500, { world })

	assertTrue(contact ~= nil, "expected the swept segment to be caught crossing the top edge")
	assertNear(0, contact.normal.x, 0.0001)
	assertNear(-1, contact.normal.y, 0.0001)
	assertNear(55, contact.point.x, 0.0001)
	assertNear(0, contact.point.y, 0.0001)
end)

test("Collide.checkProjectileWorlds returns nil when the segment never crosses any world", function()
	local world = squareWorld()
	local contact = Collide.checkProjectileWorlds(55, -50, 55, -20, { world })

	assertTrue(contact == nil)
end)

test("Sim.collide emits particleWorld for a fast particle that tunnels through a thin edge", function()
	local Sim = require("src.sim.step")
	local Bodies = require("src.sim.bodies")
	local sim = { bodies = Bodies.new() }
	-- Starts above the world, ends deep inside it after one step: the endpoint
	-- alone is inside, but prevY/prevX make the swept test cross the top edge.
	Bodies.add(sim.bodies, {
		kind = "particle", passive = true, radius = 1,
		x = 55, y = 500, prevX = 55, prevY = -500, vx = 0, vy = 0, mass = 0,
	})
	-- A thin sliver world the endpoint test would miss entirely.
	local thin = {
		vertices = Poly.normalize({
			{ x = 0, y = 0 }, { x = 100, y = 0 }, { x = 100, y = 2 }, { x = 0, y = 2 },
		}),
	}

	local contacts = Sim.collide(sim, { thin })

	assertEqual(1, #contacts)
	assertEqual("particleWorld", contacts[1].kind)
	assertEqual("particle", contacts[1].a.kind)
end)
