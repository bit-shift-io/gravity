Status: done
Complexity: high

# Charge-and-release firing

## What to build
- A fire press starts a charge. Releasing fires at a speed that rises linearly from `weapon.minSpeed` (150) to `weapon.maxSpeed` (700) over `weapon.chargeTime` (3 s), capped at max.
- Fires from the nose in flight and from the turret tip in tank mode. Both modes can charge. A charge carries over landing and lift-off.
- A screen-aligned bar under the ship fills with charge and hides when not charging.

## Files to create/modify
- src/game/components/weapon.lua — record becomes `{ kind = "shell", charging, charge, prevFire }`; `Weapon.update(ship, ctx)` derives press/release edges; replaces `tick`/`tryFire` and the cooldown
- src/game/systems/projectile_system.lua — `spawn(ctx, ship, origin, direction, speed)`; muzzle origin comes from the caller
- src/game/systems/ship_system.lua — call `Weapon.update` for both modes; pass nose or `Turret.muzzle` origin
- src/game/config.lua — `weapon = { minSpeed, maxSpeed, chargeTime }`; drop `projectile.muzzleSpeed`, `projectile.cooldown`
- src/app/render/hud.lua or effects.lua — charge bar under each charging ship
- tests/unit/weapon_test.lua, tests/integration/shooting_test.lua
- docs/ARCHITECTURE.md — update the example ship record's `weapon` field

## Test approach
- Unit: one-frame tap fires at minSpeed; 1.5 s hold fires at the midpoint; 5 s hold fires at maxSpeed; nothing fires while held.
- Integration: a tank with turret at +limit fires along the turret direction; a flying ship fires along its nose, carrying its own velocity.
- Integration: charge in the air, land mid-charge, release → fires from the turret.

## Acceptance criteria
- [ ] Tap, partial and full charge produce min, lerped and max speeds.
- [ ] Release is the only moment a projectile spawns.
- [ ] Indicator bar is visible only while charging and reads full at 3 s.
- [ ] No cooldown remains.

## Blocked by
02

## Gotchas
- Edges come from `weapon.prevFire`, updated every frame even when nothing fires. `app/input.lua` keeps sending a held boolean.
- A ship that dies mid-charge must not fire on the next frame's "release".
- Projectile lifetime still applies until slice 06. Don't remove it here.
- `docs/CONTEXT.md` already defines Charge.
