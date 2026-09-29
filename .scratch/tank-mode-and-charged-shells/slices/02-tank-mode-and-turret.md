Status: in-progress
Complexity: high

# Tank mode and turret aim

## What to build
- Landing puts the ship in tank mode. It draws as a chamfered dome with a turret barrel, switching instantly (morph comes in 03).
- Left/right swing the turret at `tank.turretSpeed`, clamped to ±`tank.turretLimit` (default 80°) from the surface normal. It resets to straight up on each landing.
- Thrust lifts off straight up the normal, as today. The tank refuels while on the surface.

## Files to create/modify
- src/game/components/turret.lua — new: `reset(ship)`, `aim(ship, ctx)` (clamp), `muzzle(ship, body)` → world-space tip point and unit direction
- src/game/components/lander.lua — rename state `"landed"` → `"tank"`; `isGrounded` → `isTank`
- src/game/systems/ship_system.lua — spawn with `turret = { angle = 0 }`; tank branch calls `Turret.aim` instead of zeroing rotation; `Turret.reset` on landing
- src/game/config.lua — `tank = { turretLimit, turretSpeed, barrelLength }`
- src/app/render/ships.lua — dome polygon + barrel line when `lander.state == "tank"`
- src/app/render/effects.lua — refuel ring reads `"tank"`
- tests/unit/turret_test.lua (register in tests/unit/run.lua), tests/integration/tank_mode_test.lua

## Test approach
- Unit: `aim` clamps at ±limit both ways; `reset` zeroes angle; `muzzle` at angle 0 points along the body's nose.
- Integration: land a ship, hold right 2 s → turret at +limit and body angle unchanged; thrust → state `"flying"`, velocity along the normal.
- e2e capture of a landed tank for a visual check.

## Acceptance criteria
- [ ] Tank dome sits flush on the surface, flat base down, top two corners chamfered.
- [ ] Turret starts straight up and stops at the configured limit.
- [ ] Left/right never rotate a tank's body.
- [ ] Lift-off direction ignores turret angle.
- [ ] Tank refuels.

## Blocked by
01

## Gotchas
- Turret angle is stored relative to the body. The body angle already faces the surface normal after the snap, so world aim = body.angle + turret.angle.
- Dome shape is render-only. A tank body is pinned and uses `collisionRadius` for projectile contacts, so keep `Collide.SHIP_SHAPE` untouched.
- Dome shape: 6 local vertices, base at the triangle's base line (y = 8) so it sits where the ship landed. Example: (-8,8) (8,8) (8,-1) (4,-5) (-4,-5) (-8,-1). Tune by eye.
- `docs/CONTEXT.md` already defines Tank mode and Turret.
