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
