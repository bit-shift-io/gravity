Status: done
Complexity: medium

# Speed-only landing; asteroids always crash

## What to build
- A world touch under `landing.maxSpeed` (now 150 px/s) lands at any angle. The ship snaps upright along the surface normal.
- Faster touches crash, as today.
- Any ship–asteroid contact crashes. Riding is deleted.

## Files to create/modify
- src/game/config.lua — `landing.maxSpeed = 150`; drop `landing.maxAngle`, `asteroid.refuelMultiplier`
- src/game/components/lander.lua — `check` tests speed only; delete `startRiding`, `followHost`, riding branch of `liftOff`; `isGrounded` checks `"landed"` only
- src/game/components/landable.lua — drop `refuelMultiplier` (keep `surfaceVelocityAt` only if still used; else delete module)
- src/game/systems/ship_system.lua — `shipAsteroid` → crash; delete `followRiders`
- src/game/systems/asteroid_system.lua — delete rider-kill on asteroid death; drop `riders = {}` on spawn
- src/sim/bodies.lua — delete `riders` handling in `effectiveMass`
- src/sim/step.lua, src/game/match.lua — remove `followRiders` call and riding comments
- tests/unit/{lander,landable}_test.lua, tests/integration/{landing,asteroid_landing,asteroid_collisions}_test.lua

## Test approach
- Unit: `Lander.check` returns "land" for a 140 px/s touch with the nose 90° off-normal; "crash" at 160 px/s.
- Integration: a ship dropped sideways onto a world at moderate speed ends landed and upright.
- Integration: a slow ship touching an asteroid dies with a crash event. Replace `asteroid_landing_test.lua` with this.

## Acceptance criteria
- [ ] Angle no longer affects landing.
- [ ] Landed ship's nose faces the surface normal.
- [ ] Ship–asteroid contact always crashes.
- [ ] No `riding`, `riders`, `followHost` or `refuelMultiplier` left in `src/`.
- [ ] `sh test-all.sh` passes.

## Blocked by
None — can start immediately.

## Gotchas
- `docs/CONTEXT.md` already reflects this slice (Landing, Crash, Asteroid; Riding removed). Do not re-add them.
- The snap uses the nearest hull vertex to the contact point. At a 90° approach that vertex is a base corner, not the nose — check the ship doesn't end up embedded.
- `Bodies.effectiveMass` still feeds asteroid–asteroid bounce. Keep the function; just drop the rider term.
