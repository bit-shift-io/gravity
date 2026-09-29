Status: done
Complexity: high

# Blast on contact

## What to build
- A projectile explodes when it touches a world or asteroid (armed or not) or an armed ship. Unarmed projectiles still bounce off ships.
- A blast kills every ship within `projectile.blastRadius`, shooter included.
- The blast draws as an expanding, fading line ring at the blast point, in the crash-debris style.

## Files to create/modify
- src/game/blast.lua — new: `Blast.detonate(ctx, projectile, body)` marks the projectile dead, kills ships in radius, pushes a `{ kind = "blast", x, y, radius, time }` event
- src/game/systems/projectile_system.lua — world/asteroid/armed-ship contacts call `Blast.detonate`
- src/game/systems/ship_system.lua — delete `killShipFromProjectile`; ship death now comes from the blast
- src/game/systems/asteroid_system.lua — stop absorbing `projectileAsteroid`; the projectile system owns it
- src/game/config.lua — `projectile.blastRadius`
- src/app/render/effects.lua — draw `"blast"` events
- tests/unit/blast_test.lua (register), tests/integration/shooting_test.lua

## Test approach
- Unit: ships inside the radius die with crash events; ships outside survive; the shooter dies if inside.
- Integration: armed hit on a ship kills a second ship standing nearby. A shot into a world next to a tank kills the tank.
- Integration: an unarmed projectile still bounces off its shooter.

## Acceptance criteria
- [ ] One blast per projectile, even when it touches several things in the same step.
- [ ] Blast kills are recorded as crash events, so the existing debris shows.
- [ ] Blast ring visible for its duration.

## Blocked by
01

## Gotchas
- Several contacts can name one projectile in the same step. Check `projectile.dead` before detonating.
- Contact handlers run ship → projectile → asteroid. A ship that lands this step and is caught in a blast must end dead. Dead wins over landed.
- `events` retention (`EVENT_RETENTION` in ship_system) must outlast the ring duration.
- `docs/CONTEXT.md` already defines Blast.
