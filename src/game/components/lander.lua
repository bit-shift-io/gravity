-- Lander component (docs/ARCHITECTURE.md "Component"): plain-data sub-table
-- `{ state = "flying" | "tank", host = nil, liftOffTime = -1 }` plus these pure functions,
-- called explicitly by src/game/systems/ship_system.lua. This is the only
-- place land-vs-crash is decided (this slice's Gotcha: "The sim only
-- reports contacts. Land vs crash is decided in Lander.check, never in
-- sim/"). liftOffTime prevents immediate re-landing in the frame after
-- liftoff (grace period before collision can land again).
local Vec2 = require("src.core.vec2")
local Fuel = require("src.game.components.fuel")
local Bodies = require("src.sim.bodies")

local Lander = {}

-- Grace period (seconds) after liftoff during which the ship can't re-land.
-- Prevents state thrashing when the ship hasn't moved far enough away from
-- the surface in a single frame.
local LIFTOFF_GRACE_PERIOD = 0.05

-- Decides "land" or "crash" for one contact (docs/CONTEXT.md "Landing":
-- touching a world slowly enough, at any angle; "Crash": failing the speed
-- check). `contact.relVel` is the ship's velocity relative to the world
-- surface. `shipBody` is kept in the signature for callers' symmetry but
-- orientation no longer matters. Rejects landing if the ship just lifted off
-- (within the grace period).
function Lander.check(_shipBody, contact, config, ctx)
	if ctx and ctx.time and contact.shipLiftOffTime and
		ctx.time - contact.shipLiftOffTime < LIFTOFF_GRACE_PERIOD then
		return nil
	end
	if Vec2.length(contact.relVel) > config.landing.maxSpeed then
		return "crash"
	end
	return "land"
end

-- True while `ship` is in tank mode on a world (docs/CONTEXT.md "Landed").
function Lander.isGrounded(ship)
	return ship.lander ~= nil and ship.lander.state == "tank"
end

-- Refuels a landed ship by `config.landing.refuelRate` over `ctx.dt`. Does
-- nothing while flying.
function Lander.tick(ship, ctx)
	if not Lander.isGrounded(ship) then
		return
	end

	Fuel.add(ship.fuel, ctx.config.landing.refuelRate * ctx.dt)
end

-- Ends the landed state (docs/CONTEXT.md "Landed": "Ends only on thrust
-- (lift-off) or destruction."), un-pinning the ship's body so Sim.integrate/
-- Sim.collide resume integrating and colliding it. Gives the ship an upward
-- impulse to overcome gravity and ensures it escapes the surface. Records
-- the lift-off time to prevent immediate re-landing. Does nothing while
-- flying.
function Lander.liftOff(ship, ctx)
	if not Lander.isGrounded(ship) then
		return
	end

	local body = Bodies.get(ctx.sim.bodies, ship.body)
	if body then
		body.pinned = false
		-- Initial upward impulse: apply a frame of thrust as a velocity boost
		-- so the ship overcomes gravity in the first frame after liftoff.
		local thrustBoost = ctx.config.ship.thrustAccel * ctx.dt
		body.vy = body.vy - thrustBoost
	end

	ship.lander.state = "flying"
	ship.lander.host = nil
	ship.lander.liftOffTime = ctx.time
end

return Lander
