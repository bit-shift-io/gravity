Status: pending
Complexity: high

# Asteroids: spawn, collide, land and ride

## What to build
- Up to the level's max (1–2) asteroids spawn off-screen aimed inward, as random slowly spinning convex polygons with mass from area.
- They curve under gravity and pull on everything. They die on world contact, bounce off each other, and absorb projectiles without being pushed.
- Ships land on asteroids when their speed relative to the touched surface point passes the check. They ride along, refuel faster, and die if the asteroid dies.

## Files to create/modify
- src/game/systems/asteroid_system.lua — spawner (seeded), `update`, `handleContacts`
- src/game/asteroid_shape.lua — convex polygon generator
- src/game/components/landable.lua — surface velocity = v + ω × r; asteroid refuel multiplier
- src/game/components/lander.lua — riding: local offset, follow host, die with host
- src/sim/collide.lua — ship/asteroid polygon contacts, asteroid–world, asteroid–asteroid
- src/sim/bodies.lua — combined mass while riding
- src/game/config.lua — asteroid size classes, density, spin range, spawn delay, spread, refuel multiplier
- src/app/render/asteroids.lua
- tests/unit/{asteroid_shape,landable,asteroid_spawn}_test.lua
- tests/integration/{asteroid_collisions,asteroid_landing}_test.lua

## Test approach
- Unit: generated shapes are convex and simple; spawner never exceeds max; spawn line never passes within the safety radius of a ship; surface velocity at the rim of a spinning static asteroid equals ω × r.
- Integration: a ship matched to a drifting spinning asteroid lands and rides; it refuels faster than on a world; the asteroid hitting a world kills the rider; a projectile hitting an asteroid dies and leaves its velocity unchanged.

## Acceptance criteria
- [ ] Never more than the configured max alive.
- [ ] Landing on asteroids uses surface-point relative speed.
- [ ] Riders move and rotate with the asteroid and die with it.
- [ ] Projectiles never change asteroid momentum.
- [ ] Same seed → same asteroid sequence.

## Blocked by
05, 06, 07

## Gotchas
- Riding ships are pinned to a moving host. Update rider position from the host after integrate, before collide, or riders jitter.
- Rider mass joins the host body for gravity. Remove it on lift-off so gravity stays consistent.
- The spawner draws from `ctx.rng` only, never `math.random`.
