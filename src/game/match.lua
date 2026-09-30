-- Match: best of 5 rounds, one level layout for the whole match (see
-- docs/CONTEXT.md). Match.step(ctx) is where the whole frame order will
-- eventually live -- see docs/ARCHITECTURE.md "Systems and frame order".
-- Plain tables and function modules only; no classes (docs/ARCHITECTURE.md
-- "Rules").
local Field = require("src.sim.field")
local Bodies = require("src.sim.bodies")
local Sim = require("src.sim.step")
local Pools = require("src.game.pools")
local Rng = require("src.core.rng")
local Camera = require("src.app.camera")
local ShipSystem = require("src.game.systems.ship_system")
local ProjectileSystem = require("src.game.systems.projectile_system")
local AsteroidSystem = require("src.game.systems.asteroid_system")
local ParticleSystem = require("src.game.systems.particle_system")

local Match = {}

-- Builds the one ctx table passed to every system and component function
-- for this match. `level` is a literal level table (never a generated level
-- in tests, unless the test targets the generator), already validated by
-- the caller (src/game/level.lua Level.validate) so its worlds have final
-- vertices and mass; `config` is the tuning table from src/game/config.lua.
--
-- The static gravity field is baked once here, into ctx.sim.field, rather
-- than lazily on first use -- it never changes for the rest of the match
-- (docs/CONTEXT.md "Static field"), so there's no reason to defer it.
--
-- `seed` (optional) is the number that determines this match's generated
-- level and asteroid spawns (docs/CONTEXT.md "Seed"). ctx.rng is built from
-- it here via src/core/rng.lua so every draw the asteroid spawner makes is
-- reproducible; a caller that doesn't care passes nothing and gets a
-- per-run default (os.time() -- plain Lua stdlib, not `love.*`, so this is
-- fine even in src/game/, which must stay love-free but not
-- side-effect-free).
function Match.new(level, config, seed)
	local worldField, boundaryField = Field.bake(level, config)
	local ctx = {
		dt = 0,
		time = 0,
		pools = Pools.new(),
		sim = {
			field = worldField,
			boundaryField = boundaryField,
			bodies = Bodies.new(),
		},
		level = level,
		config = config,
		intents = {},
		rng = Rng.new(seed or os.time()),
		events = {},
		camera = Camera.new(),
	}

	-- Two ships spawn floating at the level's fixture spawn points, one per
	-- player (docs/CONTEXT.md "Ship"; slice 04 "Two ships spawn floating at
	-- fixture spawn points"). A level with no spawnPoints (e.g. the empty
	-- `{ worlds = {} }` fixtures earlier unit tests use) simply starts with
	-- no ships rather than erroring.
	if level.spawnPoints then
		for player, spawnPoint in ipairs(level.spawnPoints) do
			ShipSystem.spawn(ctx, player, spawnPoint)
		end
	end

	return ctx
end

-- The whole frame order (docs/ARCHITECTURE.md "Systems and frame order").
-- Step 6 is a deliberately empty stub for this slice -- round rules arrive
-- in slice 10; step 3 (asteroid spawners) is slice 09's, not this one's.
-- Step 5 now handles ship-vs-world (land/crash), ship-vs-ship (bounce), and
-- armed-projectile-vs-ship (destroy) contacts, plus projectile-vs-world and
-- unarmed-projectile-vs-ship contacts via ProjectileSystem.handleContacts;
-- asteroid contact handling is future work (slice 09).
function Match.step(ctx)
	-- 1. Player intents already live on ctx.intents -- app fills them in
	-- before calling Match.step (src/app/input.lua, src/app/states/
	-- match_state.lua), so there is nothing to read here.

	-- 2. Ship controls: rotate, thrust, fire (fire dispatches through
	-- src/game/components/weapon.lua's Weapon.tryFire, called from
	-- ShipSystem.update).
	ShipSystem.update(ctx)

	-- Projectiles' own per-frame tick (lifetime/age/armed), ahead of
	-- Sim.step so a projectile fired this very frame already has a
	-- correct armed flag by the time contacts are detected below (this
	-- slice's chosen spot for it, documented in the slice handoff -- not
	-- step 3's spawner slot, which is asteroids' (slice 09), and a shot is
	-- a direct result of step 2's controls, not a spawner).
	ProjectileSystem.update(ctx)

	-- 3. Spawners (asteroids). AsteroidSystem.update is time/delay-gated
	-- internally (config.asteroid.spawnDelay) and never spawns past
	-- ctx.level.asteroids.maxAlive.
	AsteroidSystem.update(ctx)

	-- Particle system.
	ParticleSystem.update(ctx)

	-- 4. Sim.integrate: gravity + integrate only (slice 09 split Sim.step
	-- into Sim.integrate/Sim.collide -- see src/sim/step.lua's header).
	Sim.integrate(ctx.sim, ctx.dt, ctx.config)

	-- Sim.collide: contact detection -> contact list.
	local contacts = Sim.collide(ctx.sim, ctx.level.worlds)

	-- 5. Systems handle contacts: land, bounce, destroy. Both systems read
	-- the same contact list -- ShipSystem for ship-vs-world/ship-vs-ship/
	-- ship-vs-asteroid/armed-projectile-vs-ship, ProjectileSystem for
	-- projectile-vs-world/unarmed-projectile-vs-ship, AsteroidSystem for
	-- asteroid-vs-world/asteroid-vs-asteroid/projectile-vs-asteroid -- so an
	-- "armed" flag is only ever computed once (ProjectileSystem.update,
	-- above) and just read by all.
	ShipSystem.handleContacts(ctx, contacts)
	ProjectileSystem.handleContacts(ctx, contacts)
	AsteroidSystem.handleContacts(ctx, contacts)
	ParticleSystem.handleContacts(ctx, contacts)

	-- 6. Round rules. Empty stub -- slice 10.

	-- Update camera zoom to fit every player with buffer margin. A dead ship
	-- stays in frame at its death spot until its crash animation finishes.
	local focus = {}
	for _, ship in ipairs(ctx.pools.ships) do
		local body = Bodies.get(ctx.sim.bodies, ship.body)
		if body then
			table.insert(focus, { x = body.x, y = body.y })
		end
	end
	local deathDuration = ctx.config.camera.deathAnimationDuration
	for _, event in ipairs(ctx.events) do
		if event.kind == "crash" and ctx.time - (event.time or ctx.time) < deathDuration then
			table.insert(focus, { x = event.x, y = event.y })
		end
	end
	if #focus >= 1 then
		local targetZoom = Camera.calculateTargetZoom(
			focus[1],
			focus[2] or focus[1],
			ctx.config.camera.bufferRadius,
			1280,
			720
		)
		Camera.updateZoom(ctx.camera, targetZoom, ctx.config.camera.zoomSpeed, ctx.dt)
	end

	-- 7. Despawn sweep -- the only place records and bodies are removed.
	-- Pools sweep first so no record is left pointing at a body id that
	-- Bodies.sweep has already freed (this slice's Gotcha).
	Pools.sweep(ctx.pools)
	Bodies.sweep(ctx.sim.bodies)
end

return Match
