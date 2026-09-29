-- Lander component (docs/ARCHITECTURE.md "Component"): plain-data sub-table
-- `{ state = "flying" | "tank", host = nil }` plus these pure functions,
-- called explicitly by src/game/systems/ship_system.lua. This is the only
-- place land-vs-crash is decided (this slice's Gotcha: "The sim only
-- reports contacts. Land vs crash is decided in Lander.check, never in
-- sim/").
local Vec2 = require("src.core.vec2")
local Fuel = require("src.game.components.fuel")
local Bodies = require("src.sim.bodies")

local Lander = {}

-- Decides "land" or "crash" for one contact (docs/CONTEXT.md "Landing":
-- touching a world slowly enough, at any angle; "Crash": failing the speed
-- check). `contact.relVel` is the ship's velocity relative to the world
-- surface. `shipBody` is kept in the signature for callers' symmetry but
-- orientation no longer matters.
function Lander.check(_shipBody, contact, config)
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
-- Sim.collide resume integrating and colliding it. Does nothing while
-- flying.
function Lander.liftOff(ship, ctx)
	if not Lander.isGrounded(ship) then
		return
	end

	local body = Bodies.get(ctx.sim.bodies, ship.body)
	if body then
		body.pinned = false
	end

	ship.lander.state = "flying"
	ship.lander.host = nil
end

return Lander
