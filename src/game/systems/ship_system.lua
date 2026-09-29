-- Ship pool system (docs/ARCHITECTURE.md "Systems and frame order"): the
-- only place ship records are spawned or driven each frame. Calls the
-- thruster component explicitly and in a visible order -- rotation is
-- applied directly here (it costs no fuel, so there's no component seam
-- for it yet) and thrust goes through src/game/components/thruster.lua,
-- which burns fuel via src/game/components/fuel.lua. `weapon` is a real
-- `{kind="cannon", cooldown=0}` component as of this slice (07), dispatched
-- through src/game/components/weapon.lua; `lander` has been real state
-- since slice 05 (docs/ARCHITECTURE.md ship record example: `{ state =
-- "flying", host = nil }`). The body also carries `kind = "ship"` and
-- `radius` (config.ship.collisionRadius) so src/sim/step.lua's contact
-- detection can tell a ship body from a projectile body and treat it as a
-- circle for ship-vs-ship and projectile-vs-ship contacts.
local Bodies = require("src.sim.bodies")
local Thruster = require("src.game.components.thruster")
local Lander = require("src.game.components.lander")
local Turret = require("src.game.components.turret")
local Weapon = require("src.game.components.weapon")
local Collide = require("src.sim.collide")
local Vec2 = require("src.core.vec2")

local ShipSystem = {}

-- The ship's un-rotated nose vector, matching src/game/components/
-- thruster.lua's NOSE and src/game/components/lander.lua's NOSE -- straight
-- up the screen at angle 0.
local NOSE = { x = 0, y = -1 }

-- Spawns a ship for `player` at `spawnPoint` (from the level's
-- level.spawnPoints, src/game/levels/fixture_two_worlds.lua), floating with
-- zero velocity until gravity and player input move it. Returns the new
-- ship record.
function ShipSystem.spawn(ctx, player, spawnPoint)
	local shipConfig = ctx.config.ship

	local body = {
		x = spawnPoint.x,
		y = spawnPoint.y,
		vx = 0,
		vy = 0,
		angle = 0,
		angularVelocity = 0,
		mass = shipConfig.mass,
		kind = "ship",
		radius = shipConfig.collisionRadius,
	}
	local bodyId = Bodies.add(ctx.sim.bodies, body)

	local ship = {
		id = bodyId,
		body = bodyId,
		player = player,
		dead = false,
		fuel = {
			amount = shipConfig.fuel.capacity,
			capacity = shipConfig.fuel.capacity,
			burnRate = shipConfig.fuel.burnRate,
		},
		thruster = { accel = shipConfig.thrustAccel },
		lander = { state = "flying", host = nil },
		turret = { angle = 0 },
		weapon = { kind = "shell", charging = false, charge = 0, prevFire = false },
	}

	table.insert(ctx.pools.ships, ship)
	return ship
end

-- Rotate, thrust, fire (docs/ARCHITECTURE.md "Systems and frame order",
-- step 2). Weapon.update is called every frame for both flying and tank
-- modes; it handles charge state and fires on release. A charge carries
-- over landing and lift-off -- the weapon component persists. The caller
-- provides the origin (nose for flying, turret muzzle for tank) and
-- direction to Weapon.update, which knows nothing about lander state.
--
-- A tank ship (docs/CONTEXT.md "Landed": "fixed to the surface,
-- refuelling, aiming turret, unable to rotate body") skips body rotation
-- and refuels instead via Lander.tick; turret rotation is controlled by
-- Turret.aim; thrust intent lifts it off (Lander.liftOff) and then applies
-- normal thrust the same frame, so lift-off costs no extra frame of
-- stillness. A tank can charge and fire.
function ShipSystem.update(ctx)
	local rotationSpeed = ctx.config.ship.rotationSpeed

	for _, ship in ipairs(ctx.pools.ships) do
		local body = Bodies.get(ctx.sim.bodies, ship.body)
		if body then
			local intent = ctx.intents[ship.player]
			local inTank = Lander.isGrounded(ship)

			if inTank then
				body.angularVelocity = 0
				Turret.aim(ship, ctx, ship.player)
				if intent and intent.thrust then
					Lander.liftOff(ship, ctx)
					Thruster.apply(ship, ctx)
				else
					Lander.tick(ship, ctx)
				end

				-- Tank mode fires from the turret muzzle
				if ship.weapon then
					local origin, direction = Turret.muzzle(ship, ctx)
					Weapon.update(ship, ctx, origin, direction)
				end
			else
				local rotate = intent and intent.rotate or 0
				body.angularVelocity = rotate * rotationSpeed
				Thruster.apply(ship, ctx)

				-- Flying mode fires from the nose
				if ship.weapon then
					local direction = Vec2.rotate(NOSE, body.angle or 0)
					-- Nose position is 10 px from the body center along the direction
					local origin = {
						x = body.x + direction.x * 10,
						y = body.y + direction.y * 10,
					}
					Weapon.update(ship, ctx, origin, direction)
				end
			end
		end
	end
end

-- The ship's un-rotated nose vector, matching src/game/components/
-- thruster.lua's NOSE -- used to snap a landing ship's angle exactly flush
-- with the contact's outward normal (nose pointing away from the surface,
-- like standing upright) rather than leaving it at whatever angle passed
-- the alignment check.
-- math.atan2 exists on LuaJIT/Lua 5.1 but was folded into a two-argument
-- math.atan(y, x) from Lua 5.3 on -- support either so this still works
-- under the plain `lua` fallback test-unit.sh/test-integration.sh use when
-- luajit isn't installed.
local atan2 = math.atan2 or function(y, x)
	return math.atan(y, x)
end

local function angleFacing(direction)
	return atan2(direction.x, -direction.y)
end

-- How far the deepest of `points` sits below the surface plane through
-- `target` with outward `normal` (positive = penetrating). Used to lift a
-- freshly upright-snapped ship exactly flush: at a sideways approach the
-- vertex that touched first is a base corner, and the deepest vertex after
-- re-angling is what would otherwise stay embedded.
local function penetrationDepth(points, target, normal)
	local depth = 0
	for _, p in ipairs(points) do
		local d = -Vec2.dot(Vec2.sub(p, target), normal)
		if d > depth then
			depth = d
		end
	end
	return depth
end

-- Seconds a crash event is kept on ctx.events before being pruned --
-- comfortably longer than src/app/render/effects.lua's own debris-burst
-- duration, so an event never disappears mid-render; ship_system doesn't
-- read that render-side constant (game may never depend on app, docs/
-- ARCHITECTURE.md "Layers"), so the two durations are independent by design.
local EVENT_RETENTION = 2

-- Drops ctx.events entries older than EVENT_RETENTION so a long match's
-- crash history doesn't grow ctx.events forever.
local function pruneEvents(ctx)
	local kept = {}
	for _, event in ipairs(ctx.events) do
		if ctx.time - (event.time or ctx.time) < EVENT_RETENTION then
			table.insert(kept, event)
		end
	end

	for i = #ctx.events, 1, -1 do
		ctx.events[i] = nil
	end
	for i, event in ipairs(kept) do
		ctx.events[i] = event
	end
end

-- Resolves a "shipShip" contact (docs "Ships bounce elastically off each
-- other"): a mass-weighted elastic impulse along the collision normal
-- (config.ship.restitution, 1 = perfectly elastic), plus a positional
-- separation push so the two circles don't stay overlapped and re-trigger
-- the same contact next frame. `contacts` already reports each ship-ship
-- pair once (src/sim/step.lua's `i, j = i+1` loop), so this runs once per
-- pair per step, never once from each side (this slice's Gotcha) --
-- src/sim/step.lua already excludes a pinned (landed) ship from this
-- contact kind entirely, so both bodies here are always free to move.
local function resolveShipBounce(bodyA, bodyB, normal, config)
	local relVel = { x = bodyA.vx - bodyB.vx, y = bodyA.vy - bodyB.vy }
	local approachSpeed = Vec2.dot(relVel, normal)

	if approachSpeed < 0 then
		local restitution = config.ship.restitution or 1
		local m1, m2 = bodyA.mass, bodyB.mass
		local impulseMagnitude = -(1 + restitution) * approachSpeed / (1 / m1 + 1 / m2)
		local impulse = Vec2.scale(normal, impulseMagnitude)

		bodyA.vx = bodyA.vx + impulse.x / m1
		bodyA.vy = bodyA.vy + impulse.y / m1
		bodyB.vx = bodyB.vx - impulse.x / m2
		bodyB.vy = bodyB.vy - impulse.y / m2
	end

	local dx = bodyA.x - bodyB.x
	local dy = bodyA.y - bodyB.y
	local dist = math.sqrt(dx * dx + dy * dy)
	local minDist = (bodyA.radius or 0) + (bodyB.radius or 0)
	local depth = minDist - dist
	if depth > 0 then
		bodyA.x = bodyA.x + normal.x * (depth / 2)
		bodyA.y = bodyA.y + normal.y * (depth / 2)
		bodyB.x = bodyB.x - normal.x * (depth / 2)
		bodyB.y = bodyB.y - normal.y * (depth / 2)
	end
end


-- Systems handle contacts: land, bounce (docs/ARCHITECTURE.md
-- "Systems and frame order", step 5). Contacts are typed by `contact.kind`
-- (src/sim/step.lua) so this only acts on the kinds that are its job:
-- "shipWorld" (land/crash, unchanged since slice 05), "shipShip" (bounce,
-- new this slice), and "shipAsteroid" (crash, this slice). Armed
-- "projectileShip" contacts and their resulting ship deaths are now handled by
-- src/game/blast.lua's Blast.detonate instead; the bounce half of an unarmed
-- "projectileShip" contact is src/game/systems/projectile_system.lua's
-- ProjectileSystem.handleContacts' job. The sim only reports contacts; land vs
-- crash is decided here via Lander.check, never in src/sim/ (this slice's
-- Gotcha, carried over from 05).
function ShipSystem.handleContacts(ctx, contacts)
	pruneEvents(ctx)

	for _, contact in ipairs(contacts) do
		if contact.kind == "shipWorld" then
			for _, ship in ipairs(ctx.pools.ships) do
				local body = Bodies.get(ctx.sim.bodies, ship.body)
				if body and body == contact.a and not ship.dead then
					local outcome = Lander.check(body, contact, ctx.config)
					if outcome == "land" then
						-- Snap upright along the surface normal, then lift
						-- the body along the normal by however deep the
						-- re-angled hull still sits below the surface.
						body.angle = angleFacing(contact.normal)

						local shipPoints = Collide.transform(Collide.SHIP_SHAPE, body.x, body.y, body.angle)
						local depth = penetrationDepth(shipPoints, contact.point, contact.normal)
						body.x = body.x + contact.normal.x * depth
						body.y = body.y + contact.normal.y * depth

						body.vx = 0
						body.vy = 0
						body.angularVelocity = 0
						-- Mark pinned so Sim.step skips integrate/collide for
						-- it next frame (this slice's Gotcha: "tank ships
						-- must not be re-collided").
						body.pinned = true

						ship.lander.state = "tank"
						ship.lander.host = contact.b
						Turret.reset(ship)
					else
						ship.dead = true
						Bodies.markDead(ctx.sim.bodies, ship.body)
						table.insert(ctx.events, {
							kind = "crash",
							x = body.x,
							y = body.y,
							angle = body.angle,
							time = ctx.time,
						})
					end
				end
			end
		elseif contact.kind == "shipAsteroid" then
			-- Asteroids cannot be landed on (docs/CONTEXT.md "Crash").
			for _, ship in ipairs(ctx.pools.ships) do
				local body = Bodies.get(ctx.sim.bodies, ship.body)
				if body and body == contact.a and not ship.dead then
					ship.dead = true
					Bodies.markDead(ctx.sim.bodies, ship.body)
					table.insert(ctx.events, {
						kind = "crash",
						x = body.x,
						y = body.y,
						angle = body.angle,
						time = ctx.time,
					})
				end
			end
		elseif contact.kind == "shipShip" then
			resolveShipBounce(contact.a, contact.b, contact.normal, ctx.config)
		end
	end
end

return ShipSystem
