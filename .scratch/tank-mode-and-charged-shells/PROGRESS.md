## Slice 01 — speed-only-landing-no-riding
- Built: Speed-only landing (150 px/s, any angle, snaps upright and flush), and every ship–asteroid contact crashes. Riding is fully removed.
- Files touched:
  - Source: `src/game/config.lua`, `src/game/components/lander.lua`, `src/game/systems/ship_system.lua`, `src/game/systems/asteroid_system.lua`, `src/sim/bodies.lua`, `src/sim/step.lua`, `src/game/match.lua`
  - Deleted: `src/game/components/landable.lua`, `tests/unit/landable_test.lua`, `tests/integration/asteroid_landing_test.lua`
  - Tests: `tests/unit/lander_test.lua`, `tests/unit/bodies_test.lua`, `tests/integration/landing_test.lua`, `tests/integration/asteroid_collisions_test.lua`
  - New: `tests/integration/asteroid_crash_test.lua`
- New exports/interfaces: `Lander.check(shipBody, contact, config)` returns "land" or "crash" on `contact.relVel` speed alone; `shipBody` argument now unused. `Lander.isGrounded` is true only for "landed". `Landable` no longer exists.
- Conventions confirmed: tests use global `test`, `assertEqual`, `assertNear`, `assertTrue`, `assertFalse`. Integration tests build literal level tables with `GameHarness.startMatch` and step frames with `FrameStepper.step`. New test files registered in `tests/{unit,integration}/run.lua`.
- Surprises: Landing snap now lifts along surface normal by hull-depth (not nearest-vertex nudge) to avoid embedding. `Bodies.effectiveMass` kept as trivial passthrough even though no longer used. ADR 0001 still mentions landing as shared via `lander`/`landable` (stale, outside slice scope).

## Slice 02 — tank-mode-and-turret
- Built: Tank mode component with turret aiming, body state renamed from "landed" to "tank", rendering for dome + barrel, and comprehensive unit and integration tests.
- Files touched:
  - Source: `src/game/components/turret.lua` (created), `src/game/components/lander.lua` (renamed state), `src/game/systems/ship_system.lua` (spawn turret, call Turret.aim/reset), `src/game/config.lua` (added tank config), `src/app/render/ships.lua` (dome + barrel), `src/app/render/effects.lua` (updated refuel indicator)
  - Tests: `tests/unit/turret_test.lua` (created), `tests/unit/lander_test.lua`, `tests/unit/run.lua`, `tests/integration/tank_mode_test.lua` (created), `tests/integration/landing_test.lua`, `tests/integration/shooting_test.lua`, `tests/integration/run.lua`
- New exports/interfaces: `Turret.reset(ship)`, `Turret.aim(ship, ctx, player)`, `Turret.muzzle(ship, ctx)` → (tip, direction) in world space.
- Conventions confirmed: Components are plain-data sub-tables with pure functions called explicitly from systems. Tests use global `test()`, `assertNear()`, `assertTrue()`, `assertFalse()`, `assertEqual()`.
- Surprises: None. TDD approach worked cleanly with minimal code to pass each test.

## Slice 04 — charge-and-release
- Built: Charge-and-release firing system with press/release edges, linear speed interpolation from minSpeed to maxSpeed over chargeTime, visual charge bar indicator, tank and flying mode support with proper origin/direction computation.
- Files touched:
  - Source: `src/game/config.lua` (added weapon table), `src/game/components/weapon.lua` (replaced tick/tryFire with update, charge state machine), `src/game/systems/projectile_system.lua` (updated spawn signature), `src/game/systems/ship_system.lua` (call Weapon.update for both modes), `src/app/render/hud.lua` (added drawChargeBar), `docs/ARCHITECTURE.md` (updated ship record example)
  - Tests: `tests/unit/weapon_test.lua` (rewrote for charge system), `tests/integration/shooting_test.lua` (updated for new firing mechanics)
- New exports/interfaces: `Weapon.update(ship, ctx, origin, direction)` handles charge accumulation and release-triggered spawn. `ProjectileSystem.spawn(ctx, ship, origin, direction, speed)` updated to accept caller-computed origin and speed.
- Conventions confirmed: Config numbers all in `src/game/config.lua`. Edge detection via component state (`prevFire`), not framework input. Charge carries over landing/lift-off because weapon component stays on ship record.
- Surprises: None. Charge successfully carries over landing/lift-off because weapon component remains on ship record across state transitions.

## Slice 05 — blast-on-contact
- Built: Blast detonation system with radius-based ship kills, crash events, and ring rendering. Projectiles explode on world/asteroid contact or armed ship contact. Unarmed projectiles still bounce.
- Files touched:
  - Source: `src/game/blast.lua` (new), `src/game/config.lua` (added projectile.blastRadius), `src/game/systems/projectile_system.lua` (handles world/asteroid/armed-ship contacts via Blast.detonate), `src/game/systems/ship_system.lua` (removed killShipFromProjectile), `src/game/systems/asteroid_system.lua` (removed projectileAsteroid handling), `src/app/render/effects.lua` (added drawBlast)
  - Tests: `tests/unit/blast_test.lua` (new, 6 tests), `tests/unit/run.lua` (registration), `tests/integration/shooting_test.lua` (updated with `withMinSpeed` call for gravity-curve test, added multi-ship blast and unarmed-bounce tests)
- New exports/interfaces: `Blast.detonate(ctx, projectile, body)` marks projectile dead, kills all ships in radius, creates blast and crash events.
- Conventions confirmed: Multiple contacts per projectile per step handled via `projectile.dead` check. Contact handler order: ship → projectile → asteroid. Event duration must outlast ring visual. Blast events have `{ kind = "blast", x, y, radius, time }`.
- Surprises: Config minSpeed change (150→200) affected gravity-curve test timing; updated test to explicitly use minSpeed(150) and increased frame count to 180 to account for longer round-trip with new ship mass (1000).

## Slice 06 — remote-detonation
- Built: One projectile per player, remote detonation. Each player tracked via `weapon.shell` body id. Fire press detonates armed shells, ignored for unarmed, never starts charge while shell lives. Projectiles no longer expire on timer.
- Files touched:
  - Source: `src/game/components/weapon.lua` (added shell and consumed fields), `src/game/systems/projectile_system.lua` (removed Lifetime.tick, added shell clearing on death), `src/game/systems/ship_system.lua` (init weapon.shell/consumed), `src/game/config.lua` (removed projectile.lifetime)
  - Tests: `tests/unit/weapon_test.lua` (4 new tests), `tests/integration/remote_detonation_test.lua` (new, 3 tests), `tests/unit/run.lua` (removed lifetime_test), `tests/integration/run.lua` (added remote_detonation)
  - Deleted: `src/game/components/lifetime.lua`, `tests/unit/lifetime_test.lua`
- New exports/interfaces: `Weapon.update` routes press to detonate (armed shell exists), ignore (unarmed), or charge (no shell). `ProjectileSystem.spawn` sets `weapon.shell = bodyId`. ProjectileSystem clears shell on any projectile death (contact/stale/boundary).
- Conventions confirmed: Bodies.get returns nil for stale ids (slot detection). Frame order: ShipSystem → ProjectileSystem → Sim → contacts → sweep. Weapon.consumed flag prevents charge start on same press.
- Surprises: None. Lifetime component cleanly removed; no other code depended on it.

## Slice 07 — blast-pushes-asteroids
- Built: Blast detonation now adds outward velocity to asteroids within pushRadius, with impulse falling off linearly by distance and asteroid mass. Asteroids survive all blasts.
- Files touched:
  - Source: `src/game/config.lua` (added pushRadius=80, pushStrength=12000), `src/game/blast.lua` (added asteroid push loop with normalized direction, linear falloff, mass scaling)
  - Tests: `tests/unit/blast_test.lua` (added newAsteroid helper, 4 new tests for push mechanics), `tests/integration/asteroid_collisions_test.lua` (updated pre-existing test to allow push, added 1 new integration test)
- New exports/interfaces: `Config.projectile.pushRadius` and `pushStrength`. `Blast.detonate` enhanced (no signature change, behavior expands).
- Conventions confirmed: Test helpers (newCtx, newAsteroid) consistent with existing patterns. Vec2.normalize safely returns zero vector for zero-length input (zero-distance case).
- Surprises: None. Pre-existing test "projectiles never change asteroid momentum" correctly updated per gotcha (that v1 criterion now false).
