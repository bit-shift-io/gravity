-- Draws each ship in ctx.pools.ships as either a flying triangle or a
-- tank dome with turret barrel at its body's position and angle. Reads
-- record and body data only, never mutates it (docs/ARCHITECTURE.md
-- "Rendering"). `love.*` only -- this lives in src/app/ (docs/ARCHITECTURE.md
-- "Layers").
local Bodies = require("src.sim.bodies")
local Vec2 = require("src.core.vec2")
local Collide = require("src.sim.collide")
local Turret = require("src.game.components.turret")

local ShipsRender = {}

-- Collide.SHIP_SHAPE (src/sim/collide.lua) is the single source of truth
-- for the ship's local-space triangle -- nose pointing "up" (angle 0),
-- matching the nose direction src/game/components/thruster.lua thrusts
-- along -- so the drawn hull and the collided hull can never drift apart
-- (docs/ARCHITECTURE.md "Layers": app may depend on sim, never the other
-- way).
local SHAPE = Collide.SHIP_SHAPE

-- Tank dome local-space vertices (flush base at y=8).
local TANK_DOME = {
	{ x = -8, y = 8 },
	{ x = 8, y = 8 },
	{ x = 8, y = -1 },
	{ x = 4, y = -5 },
	{ x = -4, y = -5 },
	{ x = -8, y = -1 },
}

local PLAYER_COLOR = {
	[1] = { 0.3, 0.8, 1, 1 },
	[2] = { 1, 0.6, 0.3, 1 },
}

function ShipsRender.draw(ctx)
	for _, ship in ipairs(ctx.pools.ships) do
		local body = Bodies.get(ctx.sim.bodies, ship.body)
		if body then
			love.graphics.setColor(PLAYER_COLOR[ship.player] or { 1, 1, 1, 1 })

			if ship.lander and ship.lander.state == "tank" then
				-- Draw tank dome
				local points = {}
				for _, v in ipairs(TANK_DOME) do
					local rotated = Vec2.rotate(v, body.angle or 0)
					table.insert(points, body.x + rotated.x)
					table.insert(points, body.y + rotated.y)
				end
				love.graphics.polygon("line", points)

				-- Draw turret barrel
				local tip, dir = Turret.muzzle(ship, ctx)
				love.graphics.line(body.x, body.y, tip.x, tip.y)
			else
				-- Draw flying triangle
				local points = {}
				for _, v in ipairs(SHAPE) do
					local rotated = Vec2.rotate(v, body.angle or 0)
					table.insert(points, body.x + rotated.x)
					table.insert(points, body.y + rotated.y)
				end
				love.graphics.polygon("line", points)
			end
		end
	end

	love.graphics.setColor(1, 1, 1, 1)
end

return ShipsRender
