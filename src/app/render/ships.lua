-- Draws each ship in ctx.pools.ships as a small triangle at its body's
-- position and angle. Reads record and body data only, never mutates it
-- (docs/ARCHITECTURE.md "Rendering"). `love.*` only -- this lives in
-- src/app/ (docs/ARCHITECTURE.md "Layers").
local Bodies = require("src.sim.bodies")
local Vec2 = require("src.core.vec2")
local Collide = require("src.sim.collide")

local ShipsRender = {}

-- Collide.SHIP_SHAPE (src/sim/collide.lua) is the single source of truth
-- for the ship's local-space triangle -- nose pointing "up" (angle 0),
-- matching the nose direction src/game/components/thruster.lua thrusts
-- along -- so the drawn hull and the collided hull can never drift apart
-- (docs/ARCHITECTURE.md "Layers": app may depend on sim, never the other
-- way).
local SHAPE = Collide.SHIP_SHAPE

local PLAYER_COLOR = {
	[1] = { 0.3, 0.8, 1, 1 },
	[2] = { 1, 0.6, 0.3, 1 },
}

function ShipsRender.draw(ctx)
	for _, ship in ipairs(ctx.pools.ships) do
		local body = Bodies.get(ctx.sim.bodies, ship.body)
		if body then
			love.graphics.setColor(PLAYER_COLOR[ship.player] or { 1, 1, 1, 1 })

			local points = {}
			for _, v in ipairs(SHAPE) do
				local rotated = Vec2.rotate(v, body.angle or 0)
				table.insert(points, body.x + rotated.x)
				table.insert(points, body.y + rotated.y)
			end

			love.graphics.polygon("line", points)
		end
	end

	love.graphics.setColor(1, 1, 1, 1)
end

return ShipsRender
