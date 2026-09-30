-- Draws the hard boundary as a circle outline. The boundary is a hard limit
-- that repels ships and projectiles back into the play area via the boundary
-- anti-gravity field (src/sim/field.lua). This module renders it visually so
-- players can see where the play area ends. Reads boundary field data only,
-- never mutates it (docs/ARCHITECTURE.md "Rendering"). `love.*` only -- lives
-- in src/app/ (docs/ARCHITECTURE.md "Layers").
local BoundaryRender = {}

local COLOR = { 1, 0.2, 0.2, 1 }  -- Bright red for visibility
local LINE_WIDTH = 3

-- The circle is drawn exactly where the sim kills ships: hardBoundary is the
-- total radius from the origin (src/sim/step.lua, src/sim/collide.lua).
function BoundaryRender.radius(boundaryField)
	return boundaryField.hardBoundary
end

function BoundaryRender.draw(ctx)
	if not ctx.sim.boundaryField then
		return
	end

	local bf = ctx.sim.boundaryField

	-- Boundary is a circle centered at world origin (0, 0).
	local radius = BoundaryRender.radius(bf)

	love.graphics.setColor(COLOR)
	love.graphics.setLineWidth(LINE_WIDTH)
	-- Draw the boundary circle - it's large (radius 1280) so you'll see an arc
	love.graphics.circle("line", 0, 0, radius)
	love.graphics.setLineWidth(1)
	love.graphics.setColor(1, 1, 1, 1)
end

return BoundaryRender
