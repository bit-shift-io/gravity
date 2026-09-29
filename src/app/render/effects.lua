-- Transient visual effects: a crash's burst of line debris (docs/CONTEXT.md
-- "Crash"), a blast's expanding ring (docs/CONTEXT.md "Blast"), and a small
-- indicator ring on a currently-landed, refuelling ship (src/app/render/hud.lua
-- already shows the actual fuel level -- this is just a glance-able cue at the
-- ship itself). Reads ctx.events and ctx.pools.ships only, never mutates them
-- (docs/ARCHITECTURE.md "Rendering"). `love.*` only -- lives in src/app/
-- (docs/ARCHITECTURE.md "Layers").
local Bodies = require("src.sim.bodies")
local Vec2 = require("src.core.vec2")

local EffectsRender = {}

-- Seconds a crash's debris burst stays visible. src/game/systems/
-- ship_system.lua prunes ctx.events well after this so a crash event never
-- disappears mid-fade.
local DEBRIS_DURATION = 0.6

-- Seconds a blast's ring stays visible. src/game/systems/ship_system.lua prunes
-- ctx.events well after this so a blast event never disappears mid-fade.
local BLAST_DURATION = 0.6

-- Local-space line segments tracing the ship's hull (matching
-- src/sim/collide.lua's Collide.SHIP_SHAPE), drawn rotated by the ship's
-- angle at the moment of impact and spreading outward as the burst ages, so
-- it reads as that ship's hull breaking apart.
local DEBRIS_LINES = {
	{ { x = 0, y = -10 }, { x = 7, y = 8 } },
	{ { x = 7, y = 8 }, { x = -7, y = 8 } },
	{ { x = -7, y = 8 }, { x = 0, y = -10 } },
}

local function drawCrash(event, ctx)
	local age = ctx.time - (event.time or ctx.time)
	local t = age / DEBRIS_DURATION
	if t < 0 or t >= 1 then
		return
	end

	local spread = 1 + t * 3
	local alpha = 1 - t

	love.graphics.setColor(1, 0.4, 0.3, alpha)
	for _, line in ipairs(DEBRIS_LINES) do
		local a = Vec2.rotate(Vec2.scale(line[1], spread), event.angle or 0)
		local b = Vec2.rotate(Vec2.scale(line[2], spread), event.angle or 0)
		love.graphics.line(event.x + a.x, event.y + a.y, event.x + b.x, event.y + b.y)
	end
end

local function drawBlast(event, ctx)
	local age = ctx.time - (event.time or ctx.time)
	local t = age / BLAST_DURATION
	if t < 0 or t >= 1 then
		return
	end

	-- Ring expands from 0 to full radius and fades out
	local currentRadius = event.radius * t
	local alpha = 1 - t

	love.graphics.setColor(1, 0.8, 0.2, alpha)
	love.graphics.circle("line", event.x, event.y, currentRadius)
end

local function drawRefuelIndicator(body)
	love.graphics.setColor(0.4, 1, 0.5, 0.6)
	love.graphics.circle("line", body.x, body.y, 14)
end

function EffectsRender.draw(ctx)
	for _, event in ipairs(ctx.events) do
		if event.kind == "crash" then
			drawCrash(event, ctx)
		elseif event.kind == "blast" then
			drawBlast(event, ctx)
		end
	end

	-- for _, ship in ipairs(ctx.pools.ships) do
	-- 	if ship.lander and ship.lander.state == "tank" then
	-- 		local body = Bodies.get(ctx.sim.bodies, ship.body)
	-- 		if body then
	-- 			drawRefuelIndicator(body)
	-- 		end
	-- 	end
	-- end

	love.graphics.setColor(1, 1, 1, 1)
end

return EffectsRender
