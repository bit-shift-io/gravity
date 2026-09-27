Status: done
Complexity: medium

# Dynamic bodies pull on each other

## What to build
- Every dynamic body attracts every other as a softened point mass, added to its static-field acceleration.
- Ships visibly tug on each other when close.
- The key-1 overlay shows the combined field: static grid + dynamic bodies at each cell centre.

## Files to create/modify
- src/sim/gravity.lua — `Gravity.pairwise(bodies, G, eps)` accumulates accel on each body
- src/sim/step.lua — static sample + pairwise before integrate
- src/app/render/debug_overlay.lua — combined field evaluation
- src/game/config.lua — ship mass
- tests/unit/gravity_pairwise_test.lua

## Test approach
- Unit: two equal bodies accelerate toward each other with equal and opposite accel; a body gets zero self-contribution; a pinned (landed) body exerts gravity but receives none.
- Unit: a negative-mass body repels (proves the future white-hole path).

## Acceptance criteria
- [ ] Two drifting ships curve toward each other.
- [ ] Overlay arrows bend around a ship as it moves.
- [ ] Negative mass repels in unit tests.

## Blocked by
04

## Gotchas
- Accumulate all accelerations before integrating any body, or results depend on iteration order.
