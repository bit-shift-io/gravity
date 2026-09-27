Status: pending
Complexity: high

# Weapons, projectiles, and ship collisions

## What to build
- Fire spawns a projectile from the nose with ship velocity + muzzle speed. Cooldown between shots; lifetime expiry.
- Unarmed projectiles bounce off ships; after the arm delay they destroy any ship hit, shooter included.
- Ships bounce elastically off each other. Projectiles die on terrain and pass through each other.

## Files to create/modify
- src/game/components/weapon.lua — `tick`, `tryFire(ship, ctx)` dispatching on `weapon.kind` ("cannon")
- src/game/components/lifetime.lua — `tick`, marks dead on expiry
- src/game/systems/projectile_system.lua — `spawn`, `update`, `handleContacts`
- src/game/systems/ship_system.lua — ship–ship bounce, armed-hit death
- src/sim/collide.lua — circle–circle contacts; swept segment vs world polygons for projectiles
- src/game/config.lua — muzzle speed, cooldown, lifetime, arm delay, projectile mass, restitution
- src/app/render/projectiles.lua
- tests/unit/{weapon,lifetime,swept_collide}_test.lua
- tests/integration/{shooting,ship_bounce}_test.lua

## Test approach
- Unit: cooldown blocks a second shot; `kind` dispatch errors clearly on unknown kinds; fast projectile crossing a thin world edge in one step is caught by the swept test.
- Integration: point-blank shot bounces off the target (unarmed); a shot that travels past the arm delay kills the target; a shot curved back by gravity kills its shooter; two ships colliding bounce and both survive.

## Acceptance criteria
- [ ] Projectiles curve under static and dynamic gravity.
- [ ] Arm delay governs bounce vs kill for every ship, shooter included.
- [ ] Ship–ship contact bounces, never kills.
- [ ] Landed ships cannot fire.

## Blocked by
05, 06

## Gotchas
- Projectiles have mass and pull on everything (06). Keep it small in config or dense volleys distort flight.
- Resolve ship–ship bounce once per pair per step, not once from each side.
