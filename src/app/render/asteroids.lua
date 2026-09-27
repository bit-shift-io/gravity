-- Draws each asteroid in ctx.pools.asteroids as its convex polygon hull,
-- transformed to world space by the body's current position/angle --
-- follows the same draw-module pattern as src/app/render/ships.lua: reads
-- record and body data only, never mutates it (docs/ARCHITECTURE.md
-- "Rendering"). `love.*` only -- lives in src/app/ (docs/ARCHITECTURE.md
-- "Layers"). Reuses src/sim/collide.lua's Collide.transform (already
-- generic over any local-space vertex list) rather than duplicating the
-- rotate+translate math, so the drawn hull can never drift from the
-- collided hull.
local Bodies = require("src.sim.bodies")
local Collide = require("src.sim.collide")

local AsteroidsRender = {}

local COLOR = { 0.6, 0.6, 0.65, 1 }

function AsteroidsRender.draw(ctx)
	love.graphics.setColor(COLOR)

	for _, asteroid in ipairs(ctx.pools.asteroids) do
		local body = Bodies.get(ctx.sim.bodies, asteroid.body)
		if body and body.vertices then
			local points = {}
			for _, p in ipairs(Collide.transform(body.vertices, body.x, body.y, body.angle)) do
				table.insert(points, p.x)
				table.insert(points, p.y)
			end

			love.graphics.polygon("line", points)
		end
	end

	love.graphics.setColor(1, 1, 1, 1)
end

return AsteroidsRender
