Status: done
Complexity: high

# Landing, crashing, refuelling on worlds

## What to build
- Ship contact with a world emits a contact with point and surface normal.
- Slow + aligned contact lands the ship: it snaps flush, stops, refuels, and cannot rotate or fire. Thrust lifts off.
- Fast or misaligned contact crashes the ship: it is destroyed and drawn as a burst of line debris.

## Files to create/modify
- src/sim/collide.lua — ship polygon vs world polygon edges; contact `{a, b, point, normal, relVel}`
- src/sim/step.lua — collide after integrate; return contacts
- src/game/components/lander.lua — `check(ship, contact, config)` → "land" | "crash"; `tick` refuels; `liftOff`
- src/game/components/landable.lua — surface velocity at a point (zero for worlds), `refuelMultiplier`
- src/game/systems/ship_system.lua — `handleContacts`; block rotate/fire while landed
- src/game/config.lua — landing max speed, max angle, refuel rate
- src/app/render/effects.lua — crash debris, refuel indicator
- tests/unit/{collide,lander}_test.lua
- tests/integration/landing_test.lua

## Test approach
- Unit: triangle touching a flat edge returns that edge's outward normal; contact inside a concave notch reports the notch edge; `Lander.check` lands at 0.9× max speed and 0.9× max angle, crashes at 1.1× either.
- Integration: ship dropped slowly nose-up onto a world lands, refuels to full over the configured time, then lifts off on thrust; ship dropped fast crashes and its record is swept.

## Acceptance criteria
- [ ] Landing succeeds only when both speed and angle pass.
- [ ] Landed ships ignore gravity, cannot rotate, cannot fire, and refuel.
- [ ] Thrust while landed lifts off with normal thrust.
- [ ] Crashes destroy the ship and show debris.

## Blocked by
04

## Gotchas
- The sim only reports contacts. Land vs crash is decided in `Lander.check`, never in `sim/`.
- Landed ships must not be re-collided next step (resting contact). Mark the body `pinned` so integrate and collide skip it.
- The angle check compares the ship's nose vector with the surface normal, not with gravity direction.
- `landable` must already handle a moving host (asteroids in 09) even though worlds return zero surface velocity.
