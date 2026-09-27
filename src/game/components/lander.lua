-- Lander component (docs/ARCHITECTURE.md "Component"): plain-data sub-table
-- `{ state = "flying" | "landed", host = nil }` plus these pure functions,
-- called explicitly by src/game/systems/ship_system.lua. This is the only
-- place land-vs-crash is decided (this slice's Gotcha: "The sim only
-- reports contacts. Land vs crash is decided in Lander.check, never in
-- sim/").
local Vec2 = require("src.core.vec2")
local Fuel = require("src.game.components.fuel")
local Landable = require("src.game.components.landable")
local Bodies = require("src.sim.bodies")

local Lander = {}

-- The ship's un-rotated nose vector, matching src/game/components/
-- thruster.lua's NOSE: straight up the screen at angle 0.
local NOSE = { x = 0, y = -1 }

-- Decides "land" or "crash" for one contact (docs/CONTEXT.md "Landing":
-- "Touching a world or asteroid slowly enough, with the nose aligned to the
-- surface normal. Speed is measured relative to the surface point touched.
-- Failing either check is a crash."). `shipBody` is the ship's sim body
-- (needs only `.angle`) -- callers pass the body, not the pool record,
-- since orientation lives there. `contact.relVel` must already be relative
-- to the contact's host surface (src/game/systems/ship_system.lua resolves
-- that via src/game/components/landable.lua before calling this).
function Lander.check(shipBody, contact, config)
	local landing = config.landing

	local speed = Vec2.length(contact.relVel)
	if speed > landing.maxSpeed then
		return "crash"
	end

	local nose = Vec2.rotate(NOSE, shipBody.angle or 0)
	local alignment = math.max(-1, math.min(1, Vec2.dot(nose, contact.normal)))
	local angle = math.acos(alignment)
	if angle > landing.maxAngle then
		return "crash"
	end

	return "land"
end

-- True while `ship` is fixed to a surface -- landed on a world, or riding an
-- asteroid (docs/CONTEXT.md "Landed", "Riding"): the two states share almost
-- all of the same behaviour (can't rotate or fire, refuels, thrust lifts
-- off), differing only in whether the body tracks a moving/rotating host
-- every frame (riding) or simply stays put (landed, a world never moves).
-- src/game/systems/ship_system.lua's ShipSystem.update uses this instead of
-- comparing ship.lander.state to a single literal.
function Lander.isGrounded(ship)
	local state = ship.lander and ship.lander.state
	return state == "landed" or state == "riding"
end

-- Refuels a grounded ship (landed or riding) by
-- `config.landing.refuelRate * host multiplier` over `ctx.dt` (docs/
-- CONTEXT.md "Landed": "fixed to the surface, refuelling"; "Riding" refuels
-- too, typically faster via an asteroid host's own refuelMultiplier). Does
-- nothing while flying -- reuses Fuel.add rather than writing new fuel math.
function Lander.tick(ship, ctx)
	if not Lander.isGrounded(ship) then
		return
	end

	local multiplier = Landable.refuelMultiplier(ship.lander.host)
	local rate = ctx.config.landing.refuelRate * multiplier
	Fuel.add(ship.fuel, rate * ctx.dt)
end

-- Starts riding `hostBody` (an asteroid's sim body, slice 09, docs/
-- CONTEXT.md "Riding": "the ship moves and rotates with it"): stores a
-- LOCAL offset -- the ship's position/angle relative to the host's, AT THE
-- MOMENT OF LANDING, expressed in the host's own rotating frame -- so
-- Lander.followHost can recompute the ship's world position/angle from the
-- host's CURRENT position/angle every frame afterward, however the host has
-- since moved or spun. Also registers the ship's body id on the host body's
-- generic `riders` list (src/sim/bodies.lua Bodies.effectiveMass) so
-- asteroid-asteroid bounce treats a docked host as heavier by the rider's
-- mass. Called from src/game/systems/ship_system.lua's handleContacts, the
-- same place a "land" outcome is decided for a world contact.
function Lander.startRiding(ship, hostBody, shipBody)
	local worldOffset = Vec2.sub({ x = shipBody.x, y = shipBody.y }, { x = hostBody.x, y = hostBody.y })
	local localOffset = Vec2.rotate(worldOffset, -(hostBody.angle or 0))

	ship.lander.state = "riding"
	ship.lander.host = hostBody
	ship.lander.localOffset = localOffset
	ship.lander.localAngleOffset = (shipBody.angle or 0) - (hostBody.angle or 0)

	hostBody.riders = hostBody.riders or {}
	table.insert(hostBody.riders, ship.body)
end

-- Recomputes a riding ship's body position/angle from its CURRENT host
-- position/angle plus the stored local offset (docs/CONTEXT.md "Riding":
-- "the ship moves and rotates with it") -- called every frame from
-- src/game/systems/ship_system.lua's ShipSystem.followRiders, between
-- Sim.integrate and Sim.collide (this slice's Gotcha: update rider position
-- from the host after integrate, before collide, or riders jitter). Does
-- nothing for a non-riding ship or a host that's gone missing (already dead
-- this same frame -- src/game/systems/asteroid_system.lua's handleContacts
-- kills the rider outright in that case, so this function never runs for it
-- again afterward).
function Lander.followHost(ship, shipBody)
	if not ship.lander or ship.lander.state ~= "riding" then
		return
	end

	local host = ship.lander.host
	if not host then
		return
	end

	local rotatedOffset = Vec2.rotate(ship.lander.localOffset, host.angle or 0)
	shipBody.x = host.x + rotatedOffset.x
	shipBody.y = host.y + rotatedOffset.y
	shipBody.angle = (host.angle or 0) + ship.lander.localAngleOffset
	shipBody.vx = host.vx or 0
	shipBody.vy = host.vy or 0
	shipBody.angularVelocity = host.angularVelocity or 0
end

-- Ends the landed/riding state (docs/CONTEXT.md "Landed": "Ends only on
-- thrust (lift-off) or destruction."), un-pinning the ship's body so
-- Sim.integrate/Sim.collide resume integrating and colliding it, and (when
-- riding) removing the ship's body id from the host asteroid's rider list
-- and clearing the stored local offset. Does nothing while already flying.
function Lander.liftOff(ship, ctx)
	if not Lander.isGrounded(ship) then
		return
	end

	local state = ship.lander.state
	local host = ship.lander.host

	local body = Bodies.get(ctx.sim.bodies, ship.body)
	if body then
		body.pinned = false
	end

	if state == "riding" and host and host.riders then
		for i = #host.riders, 1, -1 do
			if host.riders[i] == ship.body then
				table.remove(host.riders, i)
			end
		end
	end

	ship.lander.state = "flying"
	ship.lander.host = nil
	ship.lander.localOffset = nil
	ship.lander.localAngleOffset = nil
end

return Lander
