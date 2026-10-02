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
		particlesPerStep = 1,
		-- Share of the rear edge (centred) particles are born on.
		edgeFraction = 0.5,
		-- px/s along the rear normal, relative to the ship.
		exhaustSpeed = 120,
		-- Max px/s of random sideways velocity, either direction.
		spreadSpeed = 20,
		radius = 1,
		color = { r = 1, g = 0.8, b = 0.2 },
		-- Particle lifetime tuning: hold full alpha for holdTime, then fade
		-- linearly over fadeTime before removal.
		holdTime = 2,
		fadeTime = 0.5,
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
		-- Half the barrel's thickness in px; the barrel merges into the dome outline.
		barrelHalfWidth = 1.5,
		-- Dome local-space vertices (flush base at y=8).
		dome = {
			{ x = -8, y = 8 },
			{ x = 8, y = 8 },
			{ x = 8, y = -1 },
			{ x = 4, y = -5 },
			{ x = -4, y = -5 },
			{ x = -8, y = -1 },
		},
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
		density = 0.8,
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
		density = 0.8,
	},
	-- Spawn point selection (src/game/spawn_points.lua). edgeSamples is how
	-- many evenly spaced candidate points sit on each world edge. A candidate
	-- needs open space above it: clearSteps rows of probes up to clearHeight
	-- px along the normal, each spread clearHalfWidth px either side.
	spawn = {
		edgeSamples = 3,
		clearHeight = 40,
		clearHalfWidth = 15,
		clearSteps = 4,
	},
	-- Procedural blob level generation (src/game/level_gen.lua). Play area is
	-- the 1280x720 virtual screen centred on the origin; edgeMargin (px) keeps
	-- every world vertex that far inside it. Each world is a radial-noise blob:
	-- vertexCount points evenly spaced in angle, each at baseRadius x (1 +/-
	-- noiseAmplitude), so a blob's extent is at most
	-- radius.max x (1 + noiseAmplitude). minGap (px) is the least
	-- polygon-to-polygon distance between worlds. placementRetries bounds the
	-- attempts to place one world before the world count is reduced.
	-- maxAlive is the asteroid cap drawn per level, density the per-world
	-- mass-per-area draw. A blob is notched with chance notchChance: notchVertices
	-- adjacent vertices are each pulled the fraction notchDepth of the way to the
	-- centre (1 = onto it), retried up to notchRetries times when the result
	-- isn't a simple polygon, else the blob stays un-notched.
	levelGen = {
		playWidth = 1280,
		playHeight = 720,
		edgeMargin = 60,
		worldCount = { min = 1, max = 3 },
		radius = { min = 70, max = 130 },
		vertexCount = { min = 12, max = 20 },
		noiseAmplitude = 0.3,
		minGap = 80,
		placementRetries = 30,
		density = { min = 0.4, max = 1.2 },
		maxAlive = { min = 1, max = 2 },
		notchChance = 0.5,
		notchVertices = { min = 2, max = 4 },
		notchDepth = { min = 0.35, max = 0.7 },
		notchRetries = 5,
		-- Snake worlds: with chance snakeChance a world is a polyline of
		-- snakeSegments segments (each segmentLength px long) widened to armWidth
		-- px. Each turn is +/-90 degrees with chance turn90Chance, else +/- a
		-- turnAngle draw (radians). Outer corners are mitred, the miter capped at
		-- miterLimit x half the arm width; vertices are then jittered by up to
		-- vertexJitter px per axis. A non-simple snake is redrawn up to
		-- snakeRetries times.
		snakeChance = 0.4,
		snakeSegments = { min = 2, max = 4 },
		segmentLength = { min = 120, max = 220 },
		armWidth = { min = 40, max = 70 },
		turn90Chance = 0.7,
		turnAngle = { min = math.rad(30), max = math.rad(150) },
		miterLimit = 2,
		vertexJitter = 4,
		snakeRetries = 10,
	},
	match = {},
	-- Round cycle (src/game/systems/round_system.lua). endDelay is the seconds
	-- between the round result locking and the next round's respawn;
	-- winsToWin is the round wins that take the match (used by a later slice).
	round = {
		endDelay = 3,
		-- Seconds the score card shows after the end delay; respawn follows.
		cardDuration = 4,
		winsToWin = 3,
	},
	-- Camera zoom tuning (src/app/camera.lua). bufferRadius is the additional
	-- margin around each player that the camera ensures stays visible (px).
	-- zoomSpeed is the interpolation speed for smooth zoom transitions (units/s).
	camera = {
		-- Seconds the camera keeps framing a dead ship's death spot. Matches
		-- the crash debris animation (src/app/render/effects.lua).
		deathAnimationDuration = 0.6,
		bufferRadius = 30,
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
	-- Post-processing (src/app/post). defaultMode is the launch mode: "off",
	-- "glow" or "glowCrt". `P` cycles it for the session.
	post = {
		defaultMode = "glowCrt",
		-- Glow: pixels with a channel above threshold (0..1) are blurred at
		-- half resolution and added back scaled by strength. radius is the
		-- blur reach in virtual px (scales with the game rectangle); passes
		-- is how many horizontal+vertical blur rounds run.
		glow = {
			strength = 0.8,
			threshold = 0.35,
			radius = 14,
			passes = 2,
		},
		-- CRT (glowCrt mode): curvature is the barrel strength (0 = flat,
		-- keep it small so edge cues stay readable); cornerRadius is in
		-- fractions of half the screen height; vignette is edge darkening
		-- (0..1).
		crt = {
			curvature = 0.1,
			cornerRadius = 0.12,
			vignette = 0.4,
			-- Scanlines: intensity is darkening at line troughs (0..1); pitch
			-- is screen pixels per period (constant across window sizes).
			scanlineIntensity = 0.18,
			scanlinePitch = 3,
			-- Film grain: animated noise per screen pixel, visible inside the
			-- mask. grain is the amplitude (0..1, subtle at 0.06).
			grain = 0.06,
		},
	},
}

return Config
