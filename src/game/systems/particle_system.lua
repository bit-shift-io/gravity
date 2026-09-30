-- Particle pool system.
local Bodies = require("src.sim.bodies")
local Vec2 = require("src.core.vec2")
local Blast = require("src.game.blast")

local ParticleSystem = {}

-- Spawns a particle.
function ParticleSystem.spawn(ctx, origin, velocity)
    local config = ctx.config.thrusterEffect

	local body = {
		x = origin.x,
		y = origin.y,
		vx = velocity.x,
		vy = velocity.y,
		angle = 0,
		mass = config.mass,
		kind = "particle",
		radius = config.radius,
		armed = false,
	}
	local bodyId = Bodies.add(ctx.sim.bodies, body)

	local particle = {
		id = bodyId,
		body = bodyId,
		dead = false,
        life = 1, -- seconds
		age = 0,
	}

	table.insert(ctx.pools.particles, particle)

	return particle
end

-- Ticks every live particles's age
function ParticleSystem.update(ctx)
	for _, particles in ipairs(ctx.pools.particles) do
		if not particles.dead then
			particles.age = particles.age + ctx.dt

            if particles.age >= particles.life then
                particles.dead = true
            end

			local body = Bodies.get(ctx.sim.bodies, particles.body)
			if not body then
				-- Body is stale (despawned or reused): mark particle dead
				particles.dead = true
			end

			if particles.dead then
				Bodies.markDead(ctx.sim.bodies, particles.body)
			end
		end
	end
end

-- Systems handle contacts (docs/ARCHITECTURE.md "Systems and frame order",
-- step 5)
function ParticleSystem.handleContacts(ctx, contacts)
	for _, contact in ipairs(contacts) do
		if contact.kind == "particleWorld" or contact.kind == "particleShip" or contact.kind == "particleAsteroid" or contact.kind == "particleHardBoundary" then
			for _, particle in ipairs(ctx.pools.particles) do
				local body = Bodies.get(ctx.sim.bodies, particle.body)
				if body and body == contact.a and not particle.dead then
                    particle.dead = true

					-- if contact.kind == "particleWorld" or contact.kind == "particleAsteroid" or contact.kind == "particleHardBoundary" or contact.armed then
					-- 	Blast.detonate(ctx, particle, body)
					-- else
					-- 	bounceOffShip(body, contact.b, contact.normal, ctx.config)
					-- end
				end
			end
		end
	end
end

return ParticleSystem
