-- Draws each particle in ctx.pools.particles as a small filled circle
-- at its body's position, following the same draw-module pattern as
-- src/app/render/ships.lua: reads record and body data only, never
-- mutates it (docs/ARCHITECTURE.md "Rendering"). `love.*` only -- lives in
-- src/app/ (docs/ARCHITECTURE.md "Layers").
local Bodies = require("src.sim.bodies")

local ParticlesRender = {}

local COLOR = { 1, 1, 0.5, 1 }

function ParticlesRender.draw(ctx)
	love.graphics.setColor(COLOR)

	for _, particle in ipairs(ctx.pools.particles) do
		local body = Bodies.get(ctx.sim.bodies, particle.body)
		if body then
			love.graphics.circle("fill", body.x, body.y, body.radius or 2)
		end
	end

	love.graphics.setColor(1, 1, 1, 1)
end

return ParticlesRender
