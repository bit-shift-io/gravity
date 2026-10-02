-- Builds the "crash" event for a ship that just died (docs/CONTEXT.md
-- "Crash"). A tank carries its outline (dome and barrel at the turret's pose)
-- as `vertices`, so the renderer breaks apart the shape the player saw; a
-- flying ship carries none and the renderer falls back to the hull triangle.
local TankOutline = require("src.core.tank_outline")

local Crash = {}

function Crash.event(ctx, ship, body)
	local event = {
		kind = "crash",
		x = body.x,
		y = body.y,
		angle = body.angle,
		time = ctx.time,
	}
	if ship.lander and ship.lander.state == "tank" then
		local tank = ctx.config.tank
		event.vertices = TankOutline.build(tank.dome, ship.turret.angle, tank.barrelLength, tank.barrelHalfWidth)
	end
	return event
end

return Crash
