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
