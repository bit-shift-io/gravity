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
	-- Player limits and the one shared colour palette (src/game/roster.lua,
	-- src/app/render/player_colors.lua). A slot's `color` indexes the palette.
	-- Hardcore match setting (src/game/components/thruster.lua): rotating a
	-- flying ship burns rotationBurnRate fuel units per second.
	hardcore = {
		rotationBurnRate = 1,
	},
	players = {
		-- Stick magnitude below this reads as centred (src/app/bindings.lua).
		gamepadDeadzone = 0.3,
		min = 2,
		minHumans = 1,
		max = 6,
		maxHumans = 4,
		palette = {
			{ 0.3, 0.8, 1, 1 },
			{ 1, 0.6, 0.3, 1 },
			{ 0.5, 1, 0.4, 1 },
			{ 1, 0.4, 0.7, 1 },
			{ 1, 0.9, 0.3, 1 },
			{ 0.7, 0.5, 1, 1 },
		},
	},
	-- Roster setup screen (src/app/states/setup_state.lua). seedMaxDigits caps
	-- the typed seed so it stays a safe integer (15 digits < 2^53).
	setup = {
		seedMaxDigits = 15,
	},
	-- AI players (src/game/ai/). A level is just numbers, shared by every behaviour:
	-- aimError is the max random aim offset in radians redrawn each think;
	-- reactionDelay is the seconds between thinks (the intent is held between
	-- them). fireTolerance (rad) is how close the aim must be to start a
	-- charge; fullChargeDistance (px) is the target distance that gets a full
	-- charge, nearer targets get proportionally less.
	-- Shot prediction (src/game/ai/skills/aim.lua): each think tries aimAngles
	-- launch angles spread over +/- aimSpread rad around the direct angle, then
	-- aimRefine halvings around the closest miss, at each of aimCharges evenly
	-- spaced charges (full first). A level's predictionHorizon is the seconds
	-- of flight it can foresee; no hit inside it falls back to direct aim.
	-- Flight (src/game/ai/skills/flight.lua): landing brakes while the
	-- coasting touchdown would be faster than landSpeed (px/s), thrusting only
	-- once the nose is within thrustTolerance (rad) of retrograde, and burns
	-- as late as brakeShare of full thrust allows.
	-- Hopper (src/game/ai/hopper.lua): hops only with at least hopFuel in the
	-- tank, keeps flying clear of a threat only while above landFuel (kept for
	-- braking), and tilts its hop up to dodgeTilt (rad) off the surface normal.
	-- A level's dangerHorizon is the seconds ahead it senses threats; hopTime
	-- is the least seconds of thrust in a hop.
	-- Flying to a point (Flight.flyTo): travels at up to cruiseSpeed (px/s),
	-- closing the velocity error over flightTau seconds, and burns only when
	-- that asks for at least thrustShare of full thrust. A blocked path tries
	-- up to `detours` turns of detourStep (rad) either side, and a path is
	-- clear only flightClearance (px) from every world. A level's
	-- flightHorizon is the seconds of its own thrusting path it foresees.
	-- Hunter (src/game/ai/hunter.lua): flies to standoff (px) from its
	-- target and attacks within attackRange (px) while no impact is nearer
	-- than attackClearance seconds; evades evadeDistance (px) across a
	-- threat's path; lands to refuel below refuelFuel (plus hardcoreReserve
	-- in a hardcore match) and lifts off again at takeoffFuel.
	ai = {
		fireTolerance = 0.08,
		fullChargeDistance = 700,
		aimAngles = 13,
		aimSpread = math.rad(60),
		aimRefine = 7,
		aimCharges = 3,
		landSpeed = 150,
		thrustTolerance = 0.3,
		brakeShare = 0.6,
		hopFuel = 6,
		landFuel = 1.5,
		dodgeTilt = 0.6,
		cruiseSpeed = 200,
		flightTau = 0.4,
		thrustShare = 0.4,
		detourStep = math.rad(30),
		detours = 5,
		flightClearance = 20,
		standoff = 220,
		attackRange = 450,
		attackClearance = 1,
		evadeDistance = 200,
		refuelFuel = 3,
		hardcoreReserve = 2,
		takeoffFuel = 9,
		-- Airburst (src/game/ai/skills/airburst.lua): an armed own shell
		-- that has drifted missMargin px past its closest approach to the
		-- nearest enemy is detonated as a miss.
		missMargin = 20,
		-- Stuck rule (src/game/ai/skills/stuck.lua): after stuckDelay
		-- seconds without firing a personality relaxes its standards.
		stuckDelay = 5,
		-- Chaos (src/game/ai/chaos.lua): every chaosInterval seconds it
		-- injects a random action with probability chaosRate, held for
		-- chaosHold seconds.
		chaosInterval = 1,
		chaosRate = 0.3,
		chaosHold = 0.4,
		-- Sniper (src/game/ai/sniper.lua, skills/vantage.lua): at most
		-- vantageSolves shot solves per vantage pick (each ~3 ms). It
		-- relocates after relocateDelay seconds without a solved shot, flying
		-- to vantageApproach px up the vantage's normal, and descends onto it
		-- once within vantageArrive px of that point and slower than
		-- vantageSpeed px/s.
		vantageSolves = 4,
		-- Artillery's concealed pick (src/game/ai/artillery.lua) solves up to
		-- concealedSolves candidates: most hidden points have no lob, so
		-- the nearest-to-range few rarely do.
		concealedSolves = 16,
		relocateDelay = 3,
		vantageApproach = 60,
		vantageArrive = 30,
		vantageSpeed = 40,
		-- Skirmisher (src/game/ai/skirmisher.lua): circles its quarry
		-- between orbitMin and orbitMax px, flying for the point orbitLead
		-- rad further round, and turns back where that point lies inside a
		-- world or within orbitClearance px of one. It fires at an enemy
		-- between two blast radii and orbitMax px away, charging at most
		-- skirmishCharge seconds a shot, and never starts or lets go of one
		-- that would strike a world within skirmishSafety seconds.
		orbitMin = 150,
		orbitMax = 300,
		orbitLead = math.rad(40),
		orbitClearance = 50,
		skirmishCharge = 0.75,
		skirmishSafety = 0.25,
		-- Ambusher (src/game/ai/ambusher.lua): waits landed out of sight
		-- and strikes at an enemy that comes within ambushRange px. It hides
		-- on a concealed position about ambushHideRange px from an enemy.
		ambushRange = 350,
		ambushHideRange = 650,
		-- Kamikaze (src/game/ai/kamikaze.lua): flies for a point
		-- kamikazeStandoff px straight above its target, at no more than
		-- kamikazeSpeed px/s once within kamikazeApproach px, and fires a
		-- tapped, slowest shot once within kamikazeRange px and moving at
		-- no more than kamikazeSpeed relative to the target.
		kamikazeStandoff = 120,
		kamikazeApproach = 250,
		kamikazeSpeed = 80,
		kamikazeRange = 160,
		-- Tuned with seeded matches on generated levels
		-- (tests/integration/ai_personalities_test.lua): hard wins about 60%
		-- of rounds against easy flying the same personality, and in mixed
		-- six-AI matches. A longer hopTime makes hard worse, not better --
		-- every hop is time in the air, where asteroids do most of the killing.
		levels = {
			easy = {
				aimError = 0.35,
				reactionDelay = 0.35,
				predictionHorizon = 0.7,
				dangerHorizon = 0.5,
				hopTime = 0.25,
				flightHorizon = 1,
				vantageRange = 300,
			},
			hard = {
				aimError = 0.03,
				reactionDelay = 0.04,
				predictionHorizon = 3,
				dangerHorizon = 1.2,
				hopTime = 0.25,
				flightHorizon = 1.5,
				vantageRange = 450,
			},
		},
	},
	-- Round cycle (src/game/systems/round_system.lua). endDelay is the seconds
	-- between the round result locking and the next round's respawn;
	-- winsToWin is the round wins that take the match (used by a later slice).
	round = {
		endDelay = 3,
		-- Seconds the score card shows after the end delay; respawn follows.
		cardDuration = 4,
		winsToWin = 3,
		-- Sim seconds (at the normal dt) after the last human dies before the
		-- round ends as a draw and replays, if the AIs have not finished each
		-- other by then. Never starts in an all-AI match.
		humansDeadTimeout = 30,
		-- Match.steps per frame while the roster has a human and none is
		-- alive (RoundSystem.stepsPerFrame). Each step keeps the normal dt,
		-- so the outcome matches normal speed, just sooner in real time.
		fastForwardSteps = 4,
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
	-- Softened power-law gravity shared by the baked static field
	-- (src/sim/field.lua) and later pairwise dynamic gravity (src/sim/gravity.lua,
	-- docs/adr/0002-hybrid-gravity-field.md).
	gravity = {
		-- falloff is the distance exponent: 2 = inverse-square, 1 = linear
		-- (1/r) so pull stays meaningful far from a world. G is tuned so the
		-- pull equals the old inverse-square value (G=100) at ~100px; it is
		-- weaker close in and stronger far out. Tune by playtest.
		falloff = 1,
		G = 1,
		softening = 20,
	},
	-- The static gravity field grid (src/sim/field.lua).
	field = {
		cellSize = 16,
		-- Peak boundary anti-gravity (px/s^2) at the hard boundary; it ramps
		-- linearly from 0 at the play-area edge. Was a fixed 30.
		boundaryStrength = 60,
	},
	-- Post-processing (src/app/post). defaultMode is the launch mode: "off",
	-- "glow" or "glowCrt". Changed on the settings screen.
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
