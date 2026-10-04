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
local RoundSystem = require("src.game.systems.round_system")
local AI = require("src.game.ai.init")
local Roster = require("src.game.roster")
local SpawnPoints = require("src.game.spawn_points")

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
--
-- `opts.roster` (optional) is the ordered slot list (src/game/roster.lua);
-- it defaults to two human slots. Ships, scores and respawns scale to it.
function Match.new(level, config, seed, opts)
	local roster = (opts and opts.roster) or Roster.default()
	seed = seed or os.time()
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
		seed = seed,
		rng = Rng.new(seed),
		events = {},
		camera = Camera.new(),
		roster = roster,
		round = RoundSystem.new(Roster.count(roster)),
	}
	-- Personalities draw from their own rng derived from the seed, never
	-- ctx.rng, so level generation and asteroid spawns are unchanged.
	ctx.personalities = AI.draw(seed, roster)

	-- One ship per slot, on distinct random spawnCandidates, the same draw
	-- every later round makes (RoundSystem.respawn). A level offers at most
	-- #spawnCandidates ships. Fixture levels without a candidate list use
	-- their spawnPoints; a level with neither (e.g. the empty `{ worlds = {} }`
	-- fixtures) starts with no ships rather than erroring.
	local points = level.spawnCandidates or level.spawnPoints
	if points then
		local slots = Roster.count(roster)
		for player, point in ipairs(SpawnPoints.pick(points, slots, ctx.rng)) do
			ShipSystem.spawn(ctx, player, point)
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
	-- 1. Player intents: the app fills human slots on ctx.intents before
	-- calling Match.step (src/app/input.lua, src/app/states/match_state.lua);
	-- AI.fill writes the AI slots here.
	AI.fill(ctx)

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

	-- 6. Round rules: lock the result, score, and respawn after the end delay.
	RoundSystem.update(ctx)

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
		local targetZoom = Camera.calculateTargetZoom(focus, ctx.config.camera.bufferRadius, 1280, 720)
		Camera.updateZoom(ctx.camera, targetZoom, ctx.config.camera.zoomSpeed, ctx.dt)
	end

	-- 7. Despawn sweep -- the only place records and bodies are removed.
	-- Pools sweep first so no record is left pointing at a body id that
	-- Bodies.sweep has already freed (this slice's Gotcha).
	Pools.sweep(ctx.pools)
	Bodies.sweep(ctx.sim.bodies)
end


-- One frame: Match.step at `dt`, repeated while RoundSystem.stepsPerFrame
-- allows (fast-forward while no human is alive), re-checked after every step
-- so a frame stops at the step that locks the round. dt is never scaled, so
-- the outcome is the same as one step per frame. Returns the steps run.
function Match.advance(ctx, dt)
	local steps = 0
	repeat
		ctx.dt = dt
		ctx.time = ctx.time + dt
		Match.step(ctx)
		steps = steps + 1
	until steps >= RoundSystem.stepsPerFrame(ctx)
	return steps
end

return Match
