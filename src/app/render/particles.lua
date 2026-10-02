-- Draws each particle in ctx.pools.particles as a small filled circle
-- at its body's position, following the same draw-module pattern as
-- src/app/render/ships.lua: reads record and body data only, never
-- mutates it (docs/ARCHITECTURE.md "Rendering"). `love.*` only -- lives in
-- src/app/ (docs/ARCHITECTURE.md "Layers").
local Bodies = require("src.sim.bodies")
local ThrusterEffect = require("src.game.components.thruster_effect")

local ParticlesRender = {}

function ParticlesRender.draw(ctx)
	local config = ctx.config.thrusterEffect
	local color = config.color

	for _, particle in ipairs(ctx.pools.particles) do
		local body = Bodies.get(ctx.sim.bodies, particle.body)
		if body then
			local alpha = ThrusterEffect.alpha(particle.age, config.holdTime, config.fadeTime)
			love.graphics.setColor(color.r, color.g, color.b, alpha)
			love.graphics.circle("fill", body.x, body.y, body.radius or 2)
		end
	end

	love.graphics.setColor(1, 1, 1, 1)
end

return ParticlesRender
