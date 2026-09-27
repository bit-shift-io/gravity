-- Boundary system (docs/ARCHITECTURE.md "Systems and frame order"): marks
-- bodies that have drifted beyond the soft-boundary margin as dead, so they
-- are removed in the despawn sweep. Ships beyond the margin are lost to space;
-- projectiles and asteroids past the margin despawn silently. The margin
-- itself (within the boundary) is still alive -- ships there show an edge
-- arrow but are not yet destroyed (docs/CONTEXT.md "Soft boundary").
local Bodies = require("src.sim.bodies")

local BoundarySystem = {}

-- Virtual screen dimensions.
local SCREEN_WIDTH = 1280
local SCREEN_HEIGHT = 720

-- Marks any record (ship, projectile, or asteroid) whose body is outside the
-- soft-boundary margin as dead. Called before the despawn sweep so the sweep
-- removes them.
function BoundarySystem.update(ctx)
	local margin = ctx.config.boundary.margin
	local minX = -margin
	local maxX = SCREEN_WIDTH + margin
	local minY = -margin
	local maxY = SCREEN_HEIGHT + margin

	-- Check ships.
	for _, ship in ipairs(ctx.pools.ships) do
		local body = Bodies.get(ctx.sim.bodies, ship.body)
		if body then
			if body.x < minX or body.x > maxX or body.y < minY or body.y > maxY then
				if not ship.dead then
					ship.dead = true
					Bodies.markDead(ctx.sim.bodies, ship.body)
				end
			end
		end
	end

	-- Check projectiles.
	for _, projectile in ipairs(ctx.pools.projectiles) do
		local body = Bodies.get(ctx.sim.bodies, projectile.body)
		if body then
			if body.x < minX or body.x > maxX or body.y < minY or body.y > maxY then
				if not projectile.dead then
					projectile.dead = true
					Bodies.markDead(ctx.sim.bodies, projectile.body)
				end
			end
		end
	end

	-- Check asteroids.
	for _, asteroid in ipairs(ctx.pools.asteroids) do
		local body = Bodies.get(ctx.sim.bodies, asteroid.body)
		if body then
			if body.x < minX or body.x > maxX or body.y < minY or body.y > maxY then
				if not asteroid.dead then
					asteroid.dead = true
					Bodies.markDead(ctx.sim.bodies, asteroid.body)
				end
			end
		end
	end
end

return BoundarySystem
