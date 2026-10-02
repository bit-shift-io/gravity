-- Particle pool system.
local Bodies = require("src.sim.bodies")

local ParticleSystem = {}

-- Marks the particle and its body dead.
-- Pools.sweep / Bodies.sweep do the actual removal.
local function kill(ctx, particle)
	particle.dead = true
	Bodies.markDead(ctx.sim.bodies, particle.body)
end

-- Spawns a particle.
function ParticleSystem.spawn(ctx, origin, velocity)
    local config = ctx.config.thrusterEffect

	local body = {
		x = origin.x,
		y = origin.y,
		vx = velocity.x,
		vy = velocity.y,
		angle = 0,
		-- Passive: exerts and receives no pairwise gravity, so mass is unused.
		mass = 0,
		passive = true,
		kind = "particle",
		radius = config.radius,
		armed = false,
	}
	local bodyId = Bodies.add(ctx.sim.bodies, body)

	local particle = {
		id = bodyId,
		body = bodyId,
		dead = false,
		life = config.holdTime + config.fadeTime,
		age = 0,
	}

	table.insert(ctx.pools.particles, particle)
	-- Body-table -> particle record, so handleContacts needn't scan the pool.
	-- Weak keys: entries vanish once Bodies.sweep frees the body.
	ctx.pools.particleByBody = ctx.pools.particleByBody or setmetatable({}, { __mode = "k" })
	ctx.pools.particleByBody[body] = particle

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
-- step 5). Only marks `dead`; Pools.sweep removes the record. Particles
-- ignore ships and projectiles, so only world, asteroid and hard-boundary
-- contacts are read. Looks each contact's body up in the body index, so the
-- cost is O(contacts), not contacts x pool size. An asteroid appears in many
-- contacts per step but is never `a` of a particle contact, so no other
-- system's contact is consumed here.
function ParticleSystem.handleContacts(ctx, contacts)
	local byBody = ctx.pools.particleByBody
	if not byBody then
		return
	end

	for _, contact in ipairs(contacts) do
		local kind = contact.kind
		if kind == "particleWorld" or kind == "particleAsteroid" or kind == "particleHardBoundary" then
			local particle = byBody[contact.a]
			if particle then
				kill(ctx, particle)
			end
		end
	end
end

return ParticleSystem
