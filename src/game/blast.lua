-- Blast detonation system. When a projectile explodes (on contact with world,
-- asteroid, or armed ship), Blast.detonate marks the projectile dead, kills all
-- ships within the blast radius, creates crash events for each killed ship, and
-- pushes all asteroids within the push radius outward (falloff-weighted by mass).
-- Creates a blast event for rendering (docs/CONTEXT.md "Blast"). The blast is
-- deadly to the shooter too if they're in range; asteroids always survive.
local Bodies = require("src.sim.bodies")
local Vec2 = require("src.core.vec2")

local Blast = {}

-- Detonates `projectile` at the blast point (the projectile body's current
-- position). Marks the projectile dead, finds all ships within
-- config.projectile.blastRadius and marks them dead with crash events, finds
-- all asteroids within config.projectile.pushRadius and pushes them outward
-- (strength falloff-weighted by mass), and pushes a blast event to ctx.events
-- for rendering. The projectile must not already be dead (caller checks via
-- projectile.dead before calling). Returns nothing.
function Blast.detonate(ctx, projectile, body)
	if projectile.dead then
		return
	end

	projectile.dead = true
	Bodies.markDead(ctx.sim.bodies, projectile.body)

	local blastRadius = ctx.config.projectile.blastRadius
	local blastX = body.x
	local blastY = body.y

	-- Kill all ships within the blast radius
	for _, ship in ipairs(ctx.pools.ships) do
		if not ship.dead then
			local shipBody = Bodies.get(ctx.sim.bodies, ship.body)
			if shipBody then
				local dx = shipBody.x - blastX
				local dy = shipBody.y - blastY
				local dist = math.sqrt(dx * dx + dy * dy)

				if dist <= blastRadius then
					ship.dead = true
					Bodies.markDead(ctx.sim.bodies, ship.body)
					table.insert(ctx.events, {
						kind = "crash",
						x = shipBody.x,
						y = shipBody.y,
						angle = shipBody.angle,
						time = ctx.time,
					})
				end
			end
		end
	end

	-- Push asteroids within the blast radius
	local pushRadius = ctx.config.projectile.pushRadius
	local pushStrength = ctx.config.projectile.pushStrength
	for _, asteroid in ipairs(ctx.pools.asteroids) do
		if not asteroid.dead then
			local asteroidBody = Bodies.get(ctx.sim.bodies, asteroid.body)
			if asteroidBody then
				local dx = asteroidBody.x - blastX
				local dy = asteroidBody.y - blastY
				local dist = math.sqrt(dx * dx + dy * dy)

				if dist <= pushRadius then
					-- Calculate outward direction (blast to asteroid)
					local direction = Vec2.normalize({ x = dx, y = dy })
					-- Linear falloff: full strength at centre (dist=0), zero at radius
					local falloff = (pushRadius - dist) / pushRadius
					-- Impulse per unit mass
					local strength = pushStrength * falloff / asteroidBody.mass
					-- Apply velocity change
					asteroidBody.vx = asteroidBody.vx + direction.x * strength
					asteroidBody.vy = asteroidBody.vy + direction.y * strength
				end
			end
		end
	end

	-- Push the blast event for rendering
	table.insert(ctx.events, {
		kind = "blast",
		x = blastX,
		y = blastY,
		radius = blastRadius,
		time = ctx.time,
	})
end

return Blast
