-- Thruster component (docs/ARCHITECTURE.md "Component"): plain-data
-- sub-table `{ accel }` plus this pure function over it. Called explicitly
-- by src/game/systems/ship_system.lua -- never updates itself. Burns fuel
-- via src/game/components/fuel.lua; does nothing once the tank is empty, so
-- an out-of-fuel ship keeps rotating (no fuel cost for that) but drifts
-- instead of accelerating (slice 04 acceptance criteria).
local Fuel = require("src.game.components.fuel")
local Bodies = require("src.sim.bodies")
local Vec2 = require("src.core.vec2")

local Thruster = {}

-- The ship's un-rotated facing direction (nose) before body.angle is
-- applied: straight up the screen, since y points down (docs/ARCHITECTURE.md
-- "Rules") and angle 0 is drawn nose-up (src/app/render/ships.lua).
local NOSE = { x = 0, y = -1 }

function Thruster.apply(ship, ctx)
	local intent = ctx.intents[ship.player]
	if not intent or not intent.thrust then
		return
	end

	local fuel = ship.fuel
	if Fuel.isEmpty(fuel) then
		return
	end

	local body = Bodies.get(ctx.sim.bodies, ship.body)
	if not body then
		return
	end

	Fuel.consume(fuel, ctx.dt)

	local forward = Vec2.rotate(NOSE, body.angle or 0)
	body.vx = body.vx + forward.x * ship.thruster.accel * ctx.dt
	body.vy = body.vy + forward.y * ship.thruster.accel * ctx.dt
end

return Thruster
