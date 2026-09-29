-- HUD: one fuel bar per player, fixed to opposite top corners of the
-- 1280x720 virtual resolution (docs/ARCHITECTURE.md "Rules"). Also draws
-- a charge bar under each ship while charging. Reads record data only,
-- never mutates it (docs/ARCHITECTURE.md "Rendering"). `love.*` only --
-- this lives in src/app/ (docs/ARCHITECTURE.md "Layers").
local Bodies = require("src.sim.bodies")
local Hud = {}

local BAR_WIDTH = 200
local BAR_HEIGHT = 16
local MARGIN = 16
local CHARGE_BAR_WIDTH = 200
local CHARGE_BAR_HEIGHT = 6

local SCREEN_WIDTH = 1280
local SCREEN_HEIGHT = 720

local PLAYER_COLOR = {
	[1] = { 0.3, 0.8, 1, 1 },
	[2] = { 1, 0.6, 0.3, 1 },
}

-- The soft-boundary margin beyond the screen edge where ships show an arrow.
local BOUNDARY_MARGIN = 128

local function barX(player)
	if player == 1 then
		return MARGIN
	end
	return 1280 - MARGIN - BAR_WIDTH
end

local function drawFuelBar(player, fuel)
	local x = barX(player)
	local y = MARGIN
	local ratio = fuel.amount / fuel.capacity

	love.graphics.setColor(1, 1, 1, 0.3)
	love.graphics.rectangle("line", x, y, BAR_WIDTH, BAR_HEIGHT)

	love.graphics.setColor(PLAYER_COLOR[player] or { 1, 1, 1, 1 })
	love.graphics.rectangle("fill", x, y, BAR_WIDTH * math.max(0, ratio), BAR_HEIGHT)
end

-- Draws an arrow at the screen edge pointing to a ship that is in the
-- soft-boundary margin (outside the screen but not yet lost). The arrow's
-- colour matches the ship's colour.
local function drawEdgeArrow(ship, body)
	local minX = -BOUNDARY_MARGIN
	local maxX = SCREEN_WIDTH + BOUNDARY_MARGIN
	local minY = -BOUNDARY_MARGIN
	local maxY = SCREEN_HEIGHT + BOUNDARY_MARGIN

	-- Ship is already marked dead if it's past the margin, so we don't need to
	-- check that. Only draw if the ship is in the margin (between the screen
	-- edge and the boundary).
	if body.x >= 0 and body.x <= SCREEN_WIDTH and body.y >= 0 and body.y <= SCREEN_HEIGHT then
		-- Ship is fully on screen, don't draw an arrow.
		return
	end

	if body.x < minX or body.x > maxX or body.y < minY or body.y > maxY then
		-- Ship is past the margin (already marked dead by boundary system).
		return
	end

	-- Clamp the position to the screen edge.
	local screenX = math.max(0, math.min(SCREEN_WIDTH, body.x))
	local screenY = math.max(0, math.min(SCREEN_HEIGHT, body.y))

	-- Arrow size and direction.
	local arrowSize = 10
	local angle = 0

	-- Determine which edge the arrow is on and its angle.
	if body.x < 0 then
		screenX = 0
		angle = 0
	elseif body.x > SCREEN_WIDTH then
		screenX = SCREEN_WIDTH
		angle = math.pi
	end

	if body.y < 0 then
		screenY = 0
		angle = math.pi / 2
	elseif body.y > SCREEN_HEIGHT then
		screenY = SCREEN_HEIGHT
		angle = -math.pi / 2
	end

	-- If the ship is off-corner (both x and y outside the screen), use the
	-- angle that points toward the ship.
	if (body.x < 0 or body.x > SCREEN_WIDTH) and (body.y < 0 or body.y > SCREEN_HEIGHT) then
		local dx = body.x - (SCREEN_WIDTH / 2)
		local dy = body.y - (SCREEN_HEIGHT / 2)
		angle = math.atan2(dy, dx)
	end

	love.graphics.setColor(PLAYER_COLOR[ship.player] or { 1, 1, 1, 1 })

	-- Draw an arrow pointing in the direction of the ship.
	local cos_a = math.cos(angle)
	local sin_a = math.sin(angle)

	local p1x = screenX + cos_a * arrowSize
	local p1y = screenY + sin_a * arrowSize

	local p2x = screenX + math.cos(angle + 2.5) * arrowSize
	local p2y = screenY + math.sin(angle + 2.5) * arrowSize

	local p3x = screenX + math.cos(angle - 2.5) * arrowSize
	local p3y = screenY + math.sin(angle - 2.5) * arrowSize

	love.graphics.polygon("fill", p1x, p1y, p2x, p2y, p3x, p3y)
end

-- Draws a fixed charge bar under the fuel bar. Shows current charge level,
-- a vertical line at the previous charge level, and the turret angle in degrees.
local function drawChargeBar(ship, ctx)
	if not ship.weapon then
		return
	end

	local barX = barX(ship.player)
	local barY = MARGIN + BAR_HEIGHT + 8  -- 8 px gap below fuel bar

	local chargeTime = ctx.config.weapon.chargeTime
	local ratio = math.min(1, ship.weapon.charge / chargeTime)

	-- Draw bar outline (always visible)
	love.graphics.setColor(1, 1, 1, 0.3)
	love.graphics.rectangle("line", barX, barY, CHARGE_BAR_WIDTH, CHARGE_BAR_HEIGHT)

	-- Draw current charge fill
	love.graphics.setColor(PLAYER_COLOR[ship.player] or { 1, 1, 1, 1 })
	love.graphics.rectangle("fill", barX, barY, CHARGE_BAR_WIDTH * ratio, CHARGE_BAR_HEIGHT)

	-- Draw previous charge line (vertical line in player color)
	if ship.weapon.prevChargeThisRound > 0 then
		local prevRatio = math.min(1, ship.weapon.prevChargeThisRound / chargeTime)
		local lineX = barX + CHARGE_BAR_WIDTH * prevRatio
		love.graphics.setColor(PLAYER_COLOR[ship.player] or { 1, 1, 1, 1 })
		love.graphics.setLineWidth(2)
		love.graphics.line(lineX, barY, lineX, barY + CHARGE_BAR_HEIGHT)
		love.graphics.setLineWidth(1)
	end

	-- Draw turret angle in degrees
	local angleText = "0°"
	if ship.turret and ship.turret.angle then
		local degrees = math.deg(ship.turret.angle)
		angleText = string.format("%.0f°", degrees)
	end

	love.graphics.setColor(PLAYER_COLOR[ship.player] or { 1, 1, 1, 1 })
	if ship.player == 1 then
		-- Player 1: angle text to the right of the bar
		love.graphics.print(angleText, barX + CHARGE_BAR_WIDTH + 8, barY)
	else
		-- Player 2: angle text to the left of the bar (toward center)
		local textWidth = love.graphics.getFont():getWidth(angleText)
		love.graphics.print(angleText, barX - textWidth - 8, barY)
	end
end

function Hud.draw(ctx)
	for _, ship in ipairs(ctx.pools.ships) do
		drawFuelBar(ship.player, ship.fuel)
		drawChargeBar(ship, ctx)

		local body = Bodies.get(ctx.sim.bodies, ship.body)
		if body then
			drawEdgeArrow(ship, body)
		end
	end

	love.graphics.setColor(1, 1, 1, 1)
end

return Hud
