-- Turret component (docs/ARCHITECTURE.md "Component"): plain-data sub-table
-- `{ angle = 0 }` plus these pure functions, called explicitly by
-- src/game/systems/ship_system.lua. Turret angle is stored relative to the
-- body. The body angle faces the surface normal after landing, so world aim
-- = body.angle + turret.angle.
local Bodies = require("src.sim.bodies")
local Vec2 = require("src.core.vec2")

local Turret = {}

-- Resets the turret to point straight up along the surface normal.
function Turret.reset(ship)
	ship.turret.angle = 0
end

-- Rotates the turret based on `player` intent (from `ctx.intents`), clamped
-- to ±config.tank.turretLimit from the surface normal. Moves the turret at
-- config.tank.turretSpeed radians/sec * ctx.dt.
function Turret.aim(ship, ctx, player)
	local intent = ctx.intents[player]
	if not intent or intent.rotate == 0 then
		return
	end

	local speedPerFrame = ctx.config.tank.turretSpeed * ctx.dt
	ship.turret.angle = ship.turret.angle + intent.rotate * speedPerFrame

	-- Clamp to ±limit
	local limit = ctx.config.tank.turretLimit
	if ship.turret.angle > limit then
		ship.turret.angle = limit
	elseif ship.turret.angle < -limit then
		ship.turret.angle = -limit
	end
end

-- Returns (tip, direction) where `tip` is the world-space position of the
-- barrel tip and `direction` is a unit vector along the barrel pointing away
-- from the ship. The barrel is local (0, -barrelLength) and rotated by
-- body.angle + turret.angle.
function Turret.muzzle(ship, ctx)
	local body = Bodies.get(ctx.sim.bodies, ship.body)
	if not body then
		return { x = 0, y = 0 }, { x = 0, y = -1 }
	end

	local barrelLength = ctx.config.tank.barrelLength
	local worldAngle = body.angle + ship.turret.angle

	-- Local barrel points up (0, -barrelLength), rotated by worldAngle
	local localTip = { x = 0, y = -barrelLength }
	local rotatedTip = Vec2.rotate(localTip, worldAngle)
	local tip = {
		x = body.x + rotatedTip.x,
		y = body.y + rotatedTip.y,
	}

	-- Direction is unit vector along the barrel (perpendicular to the
	-- ship's body when turret.angle = 0)
	local direction = {
		x = math.sin(worldAngle),
		y = -math.cos(worldAngle),
	}

	return tip, direction
end

return Turret
