Status: pending
Complexity: low

# Soft boundary and lost to space

## What to build
- Bodies may travel into a margin beyond the screen edge.
- A ship in the margin shows an arrow at the screen edge in its colour. Past the margin it is lost to space.
- Projectiles and asteroids past the margin despawn silently.

## Files to create/modify
- src/game/systems/boundary_system.lua — marks out-of-margin records dead
- src/game/match.lua — add boundary step before the sweep
- src/app/render/hud.lua — edge arrows
- tests/unit/boundary_test.lua
- tests/integration/lost_to_space_test.lua

## Test approach
- Unit: point just inside margin survives; just outside is marked dead with cause "lost".
- Integration: a ship drifting off-screen with no fuel is destroyed once past the margin.

## Acceptance criteria
- [ ] Off-screen ships show an edge arrow.
- [ ] Ships past the margin are destroyed.
- [ ] Off-margin projectiles do not accumulate.

## Blocked by
04
