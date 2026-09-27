Status: pending
Complexity: low

# Vector effects polish

## What to build
- Thrust flame line flickers while thrusting.
- Explosion debris lines drift, fade, and are pulled by gravity.
- Landed ships show a pulsing refuel indicator; asteroid landings show the faster rate.

## Files to create/modify
- src/app/render/effects.lua
- src/game/systems/debris_system.lua — debris records with `lifetime`, sampled field, no mass
- src/game/config.lua — debris count, lifetime, speed
- tests/unit/debris_system_test.lua
- tests/e2e/effects_test.lua

## Test approach
- Unit: debris expires after its lifetime; debris exerts no gravity.
- E2E: filmstrip capture of a crash and a refuel.

## Acceptance criteria
- [ ] Thrust, crash, and refuel each have a visible vector effect.
- [ ] Debris never affects gameplay.

## Blocked by
07

## Gotchas
- Debris is massless and never collides; keep it out of pairwise gravity to hold the body count down.
