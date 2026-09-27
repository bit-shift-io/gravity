-- Draws each projectile in ctx.pools.projectiles as a small filled circle
-- at its body's position, following the same draw-module pattern as
-- src/app/render/ships.lua: reads record and body data only, never
-- mutates it (docs/ARCHITECTURE.md "Rendering"). `love.*` only -- lives in
-- src/app/ (docs/ARCHITECTURE.md "Layers").
local Bodies = require("src.sim.bodies")

local ProjectilesRender = {}

local COLOR = { 1, 1, 0.5, 1 }

function ProjectilesRender.draw(ctx)
	love.graphics.setColor(COLOR)

	for _, projectile in ipairs(ctx.pools.projectiles) do
		local body = Bodies.get(ctx.sim.bodies, projectile.body)
		if body then
			love.graphics.circle("fill", body.x, body.y, body.radius or 2)
		end
	end

	love.graphics.setColor(1, 1, 1, 1)
end

return ProjectilesRender
