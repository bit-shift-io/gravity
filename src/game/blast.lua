-- Blast detonation system. When a projectile explodes (on contact with world,
-- asteroid, or armed ship), Blast.detonate marks the projectile dead, kills all
-- ships within the blast radius, creates crash events for each killed ship, and
-- pushes a blast event for rendering (docs/CONTEXT.md "Blast"). The blast is
-- deadly to the shooter too if they're in range.
local Bodies = require("src.sim.bodies")

local Blast = {}

-- Detonates `projectile` at the blast point (the projectile body's current
-- position). Marks the projectile dead, finds all ships within
-- config.projectile.blastRadius, marks them dead with crash events, and
-- pushes a blast event to ctx.events for rendering. The projectile must not
-- already be dead (caller checks via projectile.dead before calling).
-- Returns nothing.
function Blast.detonate(ctx, projectile, body)
	if projectile.dead then
		return
	end

	projectile.dead = true
	Bodies.markDead(ctx.sim.bodies, projectile.body)

	local blastRadius = ctx.config.projectile.blastRadius
	local blastX = body.x
	local blastY = body.y

	-- Kill all ships within the blast radius
	for _, ship in ipairs(ctx.pools.ships) do
		if not ship.dead then
			local shipBody = Bodies.get(ctx.sim.bodies, ship.body)
			if shipBody then
				local dx = shipBody.x - blastX
				local dy = shipBody.y - blastY
				local dist = math.sqrt(dx * dx + dy * dy)

				if dist <= blastRadius then
					ship.dead = true
					Bodies.markDead(ctx.sim.bodies, ship.body)
					table.insert(ctx.events, {
						kind = "crash",
						x = shipBody.x,
						y = shipBody.y,
						angle = shipBody.angle,
						time = ctx.time,
					})
				end
			end
		end
	end

	-- Push the blast event for rendering
	table.insert(ctx.events, {
		kind = "blast",
		x = blastX,
		y = blastY,
		radius = blastRadius,
		time = ctx.time,
	})
end

return Blast
