-- All tuning numbers live here (docs/ARCHITECTURE.md "Rules"). Sections are
-- empty until the slice that needs them fills them in -- nothing here is
-- speculative, the sections themselves just name where each future number
-- goes so systems can `require` this module now and start reading fields
-- as they land.
local Config = {
	-- Ship tuning (src/game/systems/ship_system.lua, src/game/components/
	-- thruster.lua). rotationSpeed is in radians/sec; thrustAccel in
	-- px/s^2, applied along the ship's nose while thrust intent is held and
	-- fuel remains. fuel.capacity/burnRate are in the same "tank" units --
	-- a full tank empties after capacity / burnRate seconds of continuous
	-- thrust.
	ship = {
		rotationSpeed = 3.5,
		thrustAccel = 280,
		-- Pairwise dynamic gravity's mass source for ships (src/sim/gravity.lua
		-- Gravity.pairwise, docs/adr/0002-hybrid-gravity-field.md "Dynamic
		-- gravity"). Mass never affects thrust or integration directly --
		-- Thruster.apply (src/game/components/thruster.lua) adds
		-- thrustAccel straight to velocity, not a force divided by mass --
		-- so this value only tunes how hard a ship pulls on other bodies.
		-- At `gravity.G` = 100 below, a mass of 1 makes that pull
		-- imperceptible (well under 0.01 px/s^2 even at point-blank range);
		-- 40000 -- roughly the same order of magnitude as a fixture world's
		-- baked mass (density x area) -- gives ships a pull that stays
		-- faint at arena-scale separation but becomes clearly visible
		-- ("ships visibly tug on each other when close") within a couple of
		-- ship-lengths. A starting tuning value; revisit by playtest feel.
		mass = 2000,
		fuel = {
			capacity = 10,
			burnRate = 1,
		},
		-- Ship-vs-ship collision (slice 07): treated as a circle of this
		-- radius for contact detection (src/sim/collide.lua Collide.circleContact),
		-- roughly matching Collide.SHIP_SHAPE's extent (its nose reaches 10px,
		-- its base half-width 7px) without reusing the triangle hull itself.
		-- restitution = 1 is a perfectly elastic bounce (docs' "Ships bounce
		-- elastically off each other").
		collisionRadius = 9,
		restitution = 1,
	},
	-- Thruster effect tuning (src/game/components/thruster_effect.lua, src/game/systems/particle_system.lua).
	thrusterEffect = {
		spawnDelay = 0.5,
		mass = 0.001,
		radius = 1,
		color = { r = 1, g = 0.8, b = 0.2 },
	},
	-- Landing tuning (src/game/components/lander.lua, src/game/systems/
	-- ship_system.lua). maxSpeed is in px/s, measured relative to the
	-- surface point touched (docs/CONTEXT.md "Landing"); any angle lands.
	-- refuelRate is in the same fuel "tank" units as ship.fuel, per second
	-- while landed.
	landing = {
		maxSpeed = 400,
		refuelRate = 5,
	},
	-- Tank mode tuning (src/game/components/turret.lua, src/game/systems/
	-- ship_system.lua). turretLimit is in radians from the surface normal;
	-- turretSpeed is radians/sec; barrelLength is in px from the ship's center.
	tank = {
		turretLimit = math.rad(80),
		turretSpeed = 1,
		barrelLength = 12,
	},
	-- Weapon tuning (src/game/components/weapon.lua, src/game/systems/
	-- ship_system.lua). Fires charge linearly from minSpeed (px/s) at tap to
	-- maxSpeed over chargeTime seconds.
	weapon = {
		minSpeed = 200,
		maxSpeed = 400,
		chargeTime = 3,
	},
	-- Projectile tuning (src/game/systems/projectile_system.lua, src/game/blast.lua).
	-- armDelay (s) is how long a shot stays "unarmed" (bounces off any ship it
	-- touches, this slice's own shooter included) before becoming "armed"
	-- (destroys any ship it touches). Projectiles no longer expire on a timer
	-- (slice 06) -- they live until contact or boundary check marks them dead.
	-- blastRadius (px) is how far the blast kills and visible ring extends
	-- when the projectile detonates. pushRadius (px) is how far the blast
	-- pushes asteroids outward. pushStrength is the impulse magnitude at the
	-- blast centre (px/s * kg), divided by asteroid mass and falling off
	-- linearly to zero at pushRadius. mass is deliberately tiny (this slice's
	-- Gotcha) so a projectile's own pull on ships stays negligible even in a
	-- dense volley -- do not raise it to "fix" flight distortion; that's what
	-- a small mass is already for. radius/restitution feed Collide.circleContact
	-- the same way ship.collisionRadius/restitution do for ship-vs-ship.
	projectile = {
		armDelay = 0.15,
		blastRadius = 30,
		pushRadius = 100,
		pushStrength = 500000,
		mass = 0.001,
		radius = 3,
		restitution = 1,
	},
	-- Asteroid tuning (src/game/asteroid_shape.lua, src/game/systems/
	-- asteroid_system.lua, slice 09). minRadius/maxRadius/pointCount feed
	-- the convex-hull polygon generator (candidate points are drawn within
	-- [minRadius, maxRadius] of a local origin before hulling, so the
	-- hull's own extent lands somewhere in roughly that range, never
	-- exactly). density feeds mass = density x area, the same convention
	-- config.world.density already uses. spinRange is the "slowly spinning"
	-- angularVelocity draw (rad/s). speedRange/aimSpread describe the
	-- inward-aimed spawn velocity: a speed in speedRange (px/s) along a
	-- direction toward the screen centre, jittered by up to aimSpread
	-- radians either way. spawnMargin is how far outside the 1280x720
	-- screen an asteroid spawns (px) -- kept to a small, sane scale
	-- deliberately (this slice's own Gotcha: an oversized config number can
	-- be actively harmful if it feeds a grid/allocation elsewhere, per the
	-- Field.bake margin lesson; this number only offsets a spawn position,
	-- but the same caution applies to any new tuning value). spawnDelay is
	-- the seconds between spawn attempts (the level's own
	-- `asteroids.maxAlive`, not a config value, caps how many can be alive
	-- at once). safetyRadius/maxSpawnAttempts gate the "spawn line never
	-- passes within a ship's safety radius" check, with a bounded retry
	-- count (Guard Against Hangs)..
	asteroid = {
		minRadius = 20,
		maxRadius = 55,
		pointCount = 10,
		density = 0.6,
		spinRange = { min = -0.3, max = 0.3 },
		speedRange = { min = 10, max = 90 },
		aimSpread = 0.4,
		spawnMargin = 60,
		spawnDelay = 4,
		safetyRadius = 150,
		maxSpawnAttempts = 8,
		-- Split tuning (src/game/systems/asteroid_system.lua): an asteroid
		-- whose polygon area (px^2) exceeds splitAreaThreshold splits into 3
		-- fragments on world contact; at or below it, it is destroyed.
		-- splitNudgeSpeed (px/s) is the extra outward speed each fragment gets
		-- along parent centre -> fragment centroid.
		splitAreaThreshold = 3000,
		splitNudgeSpeed = 60,
	},
	gravityField = {},
	world = {
		-- Default mass-per-area for a world that doesn't set its own
		-- density or an explicit mass (src/game/level.lua Level.validate).
		density = 0.6,
	},
	match = {},
	-- Camera zoom tuning (src/app/camera.lua). bufferRadius is the additional
	-- margin around each player that the camera ensures stays visible (px).
	-- zoomSpeed is the interpolation speed for smooth zoom transitions (units/s).
	camera = {
		-- Seconds the camera keeps framing a dead ship's death spot. Matches
		-- the crash debris animation (src/app/render/effects.lua).
		deathAnimationDuration = 0.6,
		bufferRadius = 100,
		zoomSpeed = 2.0,
	},
	-- Softened inverse-square law shared by the baked static field
	-- (src/sim/field.lua) and later pairwise dynamic gravity (src/sim/gravity.lua,
	-- docs/adr/0002-hybrid-gravity-field.md).
	gravity = {
		G = 100,
		softening = 20,
	},
	-- The static gravity field grid (src/sim/field.lua).
	field = {
		cellSize = 16,
	},
}

return Config
