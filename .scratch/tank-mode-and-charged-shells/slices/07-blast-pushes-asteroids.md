Status: pending
Complexity: medium

# Blast pushes asteroids

## What to build
- A blast adds outward velocity to every asteroid within `projectile.pushRadius`.
- Push falls off linearly from `projectile.pushStrength` at the centre to zero at the radius, divided by asteroid mass.
- Asteroids are never destroyed by a blast.

## Files to create/modify
- src/game/blast.lua — push step inside `Blast.detonate`
- src/game/config.lua — `projectile.pushRadius`, `projectile.pushStrength`
- tests/unit/blast_test.lua, tests/integration/asteroid_collisions_test.lua

## Test approach
- Unit: an asteroid at half radius gains half the impulse, directed away from the blast; one outside is untouched.
- Unit: a heavier asteroid moves less for the same blast.
- Integration: remote-detonate beside a drifting asteroid and assert its path bends away.

## Acceptance criteria
- [ ] Asteroids in range move away from the blast point.
- [ ] Asteroids survive blasts.
- [ ] Ships are not pushed (they are either dead or out of range).

## Blocked by
05

## Gotchas
- An asteroid centred exactly on the blast point has no direction. Skip it or pick a fixed direction; never divide by zero.
- The old v1 criterion "projectiles never change asteroid momentum" is now false. Update any test that asserts it.
