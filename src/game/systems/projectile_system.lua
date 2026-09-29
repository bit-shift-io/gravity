-- Projectile pool system (docs/ARCHITECTURE.md "Systems and frame order"):
-- the only place projectile records are spawned or driven each frame.
-- Spawning is called from src/game/components/weapon.lua's Weapon.update,
-- not from Match.step's step-3 spawner slot -- that slot is asteroids
-- (slice 09); a fired shot is a direct result of step 2's ship controls,
-- not a spawner.
local Bodies = require("src.sim.bodies")
local Lifetime = require("src.game.components.lifetime")
local Vec2 = require("src.core.vec2")
local Blast = require("src.game.blast")

local ProjectileSystem = {}

-- Spawns a projectile fired by `ship` from `origin` (world-space position,
-- already computed by the caller as nose for flying or turret muzzle for
-- tank) along unit vector `direction` (world space, already rotated by the
-- appropriate angle). Velocity is the ship's own velocity plus `speed` along
-- `direction` (docs "Fire spawns a projectile from the nose with ship
-- velocity + charge speed"). The body starts unarmed (`armed = false`) --
-- src/game/systems/ship_system.lua's ProjectileSystem.update flips it true
-- once config.projectile.armDelay has elapsed (this slice's Gotcha:
-- armed/unarmed is computed once, here, and read as plain data by both
-- handleContacts functions, never recomputed).
function ProjectileSystem.spawn(ctx, ship, origin, direction, speed)
	local config = ctx.config.projectile
	local shipBody = Bodies.get(ctx.sim.bodies, ship.body)
	if not shipBody then
		return
	end

	local body = {
		x = origin.x,
		y = origin.y,
		vx = shipBody.vx + direction.x * speed,
		vy = shipBody.vy + direction.y * speed,
		angle = 0,
		mass = config.mass,
		kind = "projectile",
		radius = config.radius,
		armed = false,
	}
	local bodyId = Bodies.add(ctx.sim.bodies, body)

	local projectile = {
		id = bodyId,
		body = bodyId,
		shooter = ship.id,
		dead = false,
		age = 0,
		lifetime = { remaining = config.lifetime },
	}

	table.insert(ctx.pools.projectiles, projectile)
	return projectile
end

-- Ticks every live projectile's age and lifetime (docs/ARCHITECTURE.md
-- "Systems and frame order", step 2/3 -- called once per frame from
-- Match.step, right after ShipSystem.update so a projectile fired this same
-- frame still gets its armed flag computed before Sim.step's contact
-- detection runs). Sets the body's `armed` flag from the projectile's own
-- age vs config.projectile.armDelay -- this is the one place that fact is
-- computed (this slice's Gotcha); src/sim/step.lua's contact detection and
-- both handleContacts functions below just read `body.armed`/`contact.armed`
-- as plain data from here on.
function ProjectileSystem.update(ctx)
	local armDelay = ctx.config.projectile.armDelay

	for _, projectile in ipairs(ctx.pools.projectiles) do
		if not projectile.dead then
			projectile.age = projectile.age + ctx.dt
			Lifetime.tick(projectile, ctx)

			local body = Bodies.get(ctx.sim.bodies, projectile.body)
			if body then
				body.armed = projectile.age >= armDelay
			end

			if projectile.dead then
				Bodies.markDead(ctx.sim.bodies, projectile.body)
			end
		end
	end
end

-- Reflects `projectileBody`'s velocity off `shipBody` (mass-weighted
-- elastic impulse, restitution from config.projectile.restitution) -- an
-- unarmed hit's "bounce" (docs "Unarmed projectiles bounce off ships").
-- `shipBody` only receives the reaction impulse when it isn't pinned (a
-- landed ship's body is fixed to the surface, same guard src/sim/step.lua
-- already applies to integration). Also nudges the projectile fully out of
-- the overlap along `normal` so it doesn't stay embedded and re-trigger the
-- same contact next frame.
local function bounceOffShip(projectileBody, shipBody, normal, config)
	local relVel = { x = projectileBody.vx - shipBody.vx, y = projectileBody.vy - shipBody.vy }
	local approachSpeed = Vec2.dot(relVel, normal)

	if approachSpeed < 0 then
		local restitution = config.projectile.restitution or 1
		local m1, m2 = projectileBody.mass, shipBody.mass
		local impulseMagnitude = -(1 + restitution) * approachSpeed / (1 / m1 + 1 / m2)
		local impulse = Vec2.scale(normal, impulseMagnitude)

		projectileBody.vx = projectileBody.vx + impulse.x / m1
		projectileBody.vy = projectileBody.vy + impulse.y / m1

		if not shipBody.pinned then
			shipBody.vx = shipBody.vx - impulse.x / m2
			shipBody.vy = shipBody.vy - impulse.y / m2
		end
	end

	local dx = projectileBody.x - shipBody.x
	local dy = projectileBody.y - shipBody.y
	local dist = math.sqrt(dx * dx + dy * dy)
	local minDist = (projectileBody.radius or 0) + (shipBody.radius or 0)
	local depth = minDist - dist
	if depth > 0 then
		projectileBody.x = projectileBody.x + normal.x * depth
		projectileBody.y = projectileBody.y + normal.y * depth
	end
end

-- Systems handle contacts (docs/ARCHITECTURE.md "Systems and frame order",
-- step 5): projectile-vs-world always detonates (terrain), projectile-vs-ship
-- bounces when unarmed or detonates when armed -- `contact.armed` is read,
-- never recomputed (see ProjectileSystem.update's Gotcha above), and
-- projectile-vs-asteroid always detonates. src/game/blast.lua's Blast.detonate
-- handles both the projectile's death and the blast effects (ship kills, events).
function ProjectileSystem.handleContacts(ctx, contacts)
	for _, contact in ipairs(contacts) do
		if contact.kind == "projectileWorld" or contact.kind == "projectileShip" or contact.kind == "projectileAsteroid" then
			for _, projectile in ipairs(ctx.pools.projectiles) do
				local body = Bodies.get(ctx.sim.bodies, projectile.body)
				if body and body == contact.a and not projectile.dead then
					if contact.kind == "projectileWorld" or contact.kind == "projectileAsteroid" or contact.armed then
						Blast.detonate(ctx, projectile, body)
					else
						bounceOffShip(body, contact.b, contact.normal, ctx.config)
					end
				end
			end
		end
	end
end

return ProjectileSystem
