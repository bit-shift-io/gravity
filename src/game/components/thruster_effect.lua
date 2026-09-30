-- ThrusterEffect component (docs/ARCHITECTURE.md "Component"): plain-data
-- sub-table `{ accel }` plus this pure function over it.
local Fuel = require("src.game.components.fuel")
local Bodies = require("src.sim.bodies")
local Vec2 = require("src.core.vec2")
local ParticleSystem = require("src.game.systems.particle_system")

local ThrusterEffect = {}

-- Returns (tip, direction) where `tip` is the world-space position of the
-- barrel tip and `direction` is a unit vector along the barrel pointing away
-- from the ship. The barrel is local (0, -barrelLength) and rotated by
-- body.angle + turret.angle.
function ThrusterEffect.emitPositionAndDirection(ship, ctx)
	local body = Bodies.get(ctx.sim.bodies, ship.body)
	if not body then
		return { x = 0, y = 0 }, { x = 0, y = -1 }
	end

	local barrelLength = ctx.config.tank.barrelLength
	local worldAngle = body.angle + ship.turret.angle

	-- Local barrel points up (0, -barrelLength), rotated by worldAngle
	local localTip = { x = 0, y = -barrelLength }
	local rotatedTip = Vec2.rotate(localTip, worldAngle)
	local position = {
		x = body.x, -- + rotatedTip.x,
		y = body.y, -- + rotatedTip.y,
	}

	-- Direction is unit vector along the barrel (perpendicular to the
	-- ship's body when turret.angle = 0)
	local direction = {
		x = math.sin(worldAngle),
		y = -math.cos(worldAngle),
	}

	return position, direction
end

function ThrusterEffect.update(ship, ctx)
	local thrusterEffect = ship.thrusterEffect
	if not thrusterEffect then
		return
	end

	local config = ctx.config

	thrusterEffect.particleSpawnTimer = (thrusterEffect.particleSpawnTimer or 0) + ctx.dt

	if thrusterEffect.particleSpawnTimer < config.thrusterEffect.spawnDelay then
		return
	end
	thrusterEffect.particleSpawnTimer = 0

	-- create a new particle to emit from the thruster
	local pos, dir = ThrusterEffect.emitPositionAndDirection(ship, ctx)
	-- local velocity = {
	-- 	x = shipBody.vx + dir.x, -- * ctx.config.thrusterEffect.particleSpeed,
	-- 	y = shipBody.vy + dir.y, -- * ctx.config.thrusterEffect.particleSpeed,
	-- }
	ParticleSystem.spawn(ctx, pos, dir)
end

return ThrusterEffect
