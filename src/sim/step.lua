-- Sim.integrate(sim, dt, config) + Sim.collide(sim, worlds): the sim-layer
-- half of Match.step's frame order (docs/ARCHITECTURE.md "Systems and frame
-- order", step 4). Split into two functions: src/game/match.lua's Match.step
-- calls Sim.integrate, then Sim.collide. Sim.step below remains as a
-- wrapper calling both in sequence.
--
-- Sim.integrate samples the baked static field plus pairwise dynamic
-- gravity (src/sim/gravity.lua Gravity.pairwise, docs/adr/
-- 0002-hybrid-gravity-field.md) at each live body's position, then
-- integrates. Sim.collide detects every contact kind and returns them for
-- step 5 (the game-layer systems' handleContacts) to consume. Worlds aren't
-- sim bodies (docs/CONTEXT.md "World": "Not stored in the body store"), so
-- they're passed in separately rather than living on `sim`. Pinned bodies
-- (a landed ship, docs/CONTEXT.md "Landed") skip
-- integrate and collide -- a resting contact must not integrate away from
-- the surface or re-collide with it every frame -- but still exert
-- pairwise gravity on everyone else (Gravity.pairwise handles that split).
-- Every body's combined acceleration is computed before any body integrates
-- (accumulate first, so results don't depend on iteration order). Pure --
-- no `love.*` (docs/ARCHITECTURE.md "Layers").
local Field = require("src.sim.field")
local Gravity = require("src.sim.gravity")
local Integrate = require("src.sim.integrate")
local Collide = require("src.sim.collide")

local Sim = {}

local ZERO = { x = 0, y = 0 }
local EMPTY = {}

-- Gravity + integrate only. Snapshots every live body's pre-integration
-- position (body.prevX/prevY) for the swept projectile-vs-world test in
-- Sim.collide -- a fast projectile can otherwise tunnel through a thin edge
-- between one frame's sample and the next. Samples the static field (world
-- field only for asteroids, world + boundary for ships/projectiles).
function Sim.integrate(sim, dt, config)
	local G = config.gravity.G
	local eps = config.gravity.softening
	local pairwiseAccel = EMPTY
	if config.gravity.pairwise ~= false then
		pairwiseAccel = Gravity.pairwise(sim.bodies.slots, G, eps, config.gravity.falloff)
	end

	for _, body in pairs(sim.bodies.slots) do
		if not body.dead then
			body.prevX = body.x
			body.prevY = body.y
		end
	end

	for slot, body in pairs(sim.bodies.slots) do
		if not body.dead and not body.pinned then
			local staticAccel = Field.sample(sim.field, body.x, body.y)
			-- Asteroids use only the world field; ships and projectiles also include the boundary field
			if body.kind ~= "asteroid" and sim.boundaryField then
				local boundaryAccel = Field.sample(sim.boundaryField, body.x, body.y)
				staticAccel.x = staticAccel.x + boundaryAccel.x
				staticAccel.y = staticAccel.y + boundaryAccel.y
			end
			-- Passive bodies have no pairwise entry: static + boundary fields only
			local dynamicAccel = pairwiseAccel[slot] or ZERO
			local ax = staticAccel.x + dynamicAccel.x
			local ay = staticAccel.y + dynamicAccel.y
			Integrate.step(body, ax, ay, dt)
		end
	end
end

-- Every contact this frame carries a `kind` so step 5's systems
-- (src/game/systems/{ship,projectile,asteroid}_system.lua) can each read
-- only the contacts meant for them without recomputing what kind of thing
-- touched what (the sim only reports contacts, it never decides outcomes):
--   "shipWorld"         -- a.body is a ship, b is the world it touched (land/crash).
--   "shipAsteroid"      -- a.body is a ship, b is the asteroid body it touched (land/crash/ride).
--   "shipHardBoundary"  -- a.body is a ship that touched the hard boundary (always dies).
--   "projectileWorld"   -- a.body is a projectile, b is the world it touched (always dies).
--   "projectileShip"    -- a.body is a projectile, b.body is the ship it touched;
--                          `armed` is the projectile's own armed flag, snapshotted
--                          here as plain data -- bounce-vs-kill is never decided
--                          in this file.
--   "projectileAsteroid"-- a.body is a projectile, b is the asteroid body it
--                          touched (always dies; the asteroid's momentum is
--                          never touched by this file or its caller).
--   "projectileHardBoundary" -- a.body is a projectile that touched the hard boundary (always dies).
--   "particleWorld"     -- a is an exhaust particle, b is the world it touched (always dies).
--   "particleAsteroid"  -- a is an exhaust particle, b is the asteroid body it touched (always dies).
--   "particleHardBoundary" -- a is an exhaust particle that touched the hard boundary (always dies).
--                          Particles have no ship or projectile contact kinds.
--   "shipShip"          -- a.body and b.body are both ships (always bounces),
--                          reported once per pair, never once from each side.
--   "asteroidWorld"      -- a is an asteroid body, b is the world it touched
--                          (the game layer splits or destroys it).
--   "asteroidAsteroid"   -- a and b are both asteroid bodies (the game layer splits or
--                          destroys each), reported once per pair.
function Sim.collide(sim, worlds)
	local contacts = {}

	local ships, unpinnedShips, projectiles, asteroids, particles  = {}, {}, {}, {}, {}
	for _, body in pairs(sim.bodies.slots) do
		if not body.dead then
			if body.kind == "ship" then
				table.insert(ships, body)
				if not body.pinned then
					table.insert(unpinnedShips, body)
				end
			elseif body.kind == "projectile" then
				table.insert(projectiles, body)
			elseif body.kind == "asteroid" then
				table.insert(asteroids, body)
			elseif body.kind == "particle" then
				table.insert(particles, body)
			end
		end
	end

	if worlds then
		for _, body in ipairs(unpinnedShips) do
			local hit = Collide.checkShipWorlds(body, worlds)
			if hit then
				table.insert(contacts, {
					kind = "shipWorld",
					a = body,
					b = hit.world,
					point = hit.point,
					normal = hit.normal,
					relVel = hit.relVel,
				})
			end
		end

		for _, body in ipairs(projectiles) do
			local hit = Collide.checkProjectileWorlds(body.prevX or body.x, body.prevY or body.y, body.x, body.y, worlds)
			if hit then
				table.insert(contacts, {
					kind = "projectileWorld",
					a = body,
					b = hit.world,
					point = hit.point,
					normal = hit.normal,
					relVel = { x = body.vx, y = body.vy },
				})
			end
		end

		for _, body in ipairs(particles) do
			local hit = Collide.checkProjectileWorlds(body.prevX or body.x, body.prevY or body.y, body.x, body.y, worlds)
			if hit then
				table.insert(contacts, {
					kind = "particleWorld",
					a = body,
					b = hit.world,
					point = hit.point,
					normal = hit.normal,
				})
			end
		end

		for _, asteroid in ipairs(asteroids) do
			local hit = Collide.checkAsteroidWorlds(asteroid, worlds)
			if hit then
				table.insert(contacts, {
					kind = "asteroidWorld",
					a = asteroid,
					b = hit.world,
					point = hit.point,
					normal = hit.normal,
				})
			end
		end
	end

	-- Ship-vs-asteroid: a ship already landed is pinned and excluded
	-- (unpinnedShips), same as ship-vs-world above.
	for _, body in ipairs(unpinnedShips) do
		local hit = Collide.checkShipAsteroids(body, asteroids)
		if hit then
			table.insert(contacts, {
				kind = "shipAsteroid",
				a = body,
				b = hit.asteroid,
				point = hit.point,
				normal = hit.normal,
				relVel = hit.relVel,
			})
		end
	end

	for _, projectile in ipairs(projectiles) do
		for _, ship in ipairs(ships) do
			local hit = Collide.circleContact(projectile.x, projectile.y, projectile.radius or 0, ship.x, ship.y, ship.radius or 0)
			if hit then
				table.insert(contacts, {
					kind = "projectileShip",
					a = projectile,
					b = ship,
					point = hit.point,
					normal = hit.normal,
					relVel = { x = projectile.vx - ship.vx, y = projectile.vy - ship.vy },
					armed = projectile.armed,
				})
			end
		end

		for _, asteroid in ipairs(asteroids) do
			local hit = Collide.checkProjectileAsteroid(projectile, asteroid)
			if hit then
				table.insert(contacts, {
					kind = "projectileAsteroid",
					a = projectile,
					b = asteroid,
					point = hit.point,
					normal = hit.normal,
				})
			end
		end
	end

	for _, particle in ipairs(particles) do
		for _, asteroid in ipairs(asteroids) do
			local hit = Collide.checkProjectileAsteroid(particle, asteroid)
			if hit then
				table.insert(contacts, {
					kind = "particleAsteroid",
					a = particle,
					b = asteroid,
					point = hit.point,
					normal = hit.normal,
				})
			end
		end
	end

	for i = 1, #unpinnedShips do
		for j = i + 1, #unpinnedShips do
			local a, b = unpinnedShips[i], unpinnedShips[j]
			local hit = Collide.circleContact(a.x, a.y, a.radius or 0, b.x, b.y, b.radius or 0)
			if hit then
				table.insert(contacts, {
					kind = "shipShip",
					a = a,
					b = b,
					point = hit.point,
					normal = hit.normal,
					relVel = { x = a.vx - b.vx, y = a.vy - b.vy },
				})
			end
		end
	end

	for i = 1, #asteroids do
		for j = i + 1, #asteroids do
			local a, b = asteroids[i], asteroids[j]
			local hit = Collide.circleContact(a.x, a.y, a.radius or 0, b.x, b.y, b.radius or 0)
			if hit then
				table.insert(contacts, {
					kind = "asteroidAsteroid",
					a = a,
					b = b,
					point = hit.point,
					normal = hit.normal,
					relVel = { x = a.vx - b.vx, y = a.vy - b.vy },
				})
			end
		end
	end

	-- Hard boundary contacts (only ships, projectiles and particles; asteroids despawn
	-- via BoundarySystem). The boundary field carries the hard boundary
	-- radius (1280px from origin).
	if sim.boundaryField then
		local boundaryRadius = sim.boundaryField.hardBoundary

		-- Ships vs hard boundary
		for _, body in ipairs(unpinnedShips) do
			local hit = Collide.checkHardBoundary(body.x, body.y, body.radius or 0, boundaryRadius)
			if hit then
				table.insert(contacts, {
					kind = "shipHardBoundary",
					a = body,
					point = hit.point,
					normal = hit.normal,
					relVel = { x = body.vx, y = body.vy },
				})
			end
		end

		-- Projectiles vs hard boundary
		for _, body in ipairs(projectiles) do
			local hit = Collide.checkHardBoundary(body.x, body.y, body.radius or 0, boundaryRadius)
			if hit then
				table.insert(contacts, {
					kind = "projectileHardBoundary",
					a = body,
					point = hit.point,
					normal = hit.normal,
					relVel = { x = body.vx, y = body.vy },
				})
			end
		end

		-- Particles vs hard boundary
		for _, body in ipairs(particles) do
			local hit = Collide.checkHardBoundary(body.x, body.y, body.radius or 0, boundaryRadius)
			if hit then
				table.insert(contacts, {
					kind = "particleHardBoundary",
					a = body,
					point = hit.point,
					normal = hit.normal,
				})
			end
		end
	end

	return contacts
end

-- Wrapper: gravity + integrate + collide in one call.
function Sim.step(sim, dt, worlds, config)
	Sim.integrate(sim, dt, config)
	return Sim.collide(sim, worlds)
end

return Sim
