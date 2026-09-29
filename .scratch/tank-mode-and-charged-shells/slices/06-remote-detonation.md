Status: done
Complexity: medium

# One projectile per player and remote detonation

## What to build
- Each player has at most one projectile alive. It no longer expires on a timer.
- While it lives, a fire press detonates it if armed, and is ignored if unarmed. Either way the press starts no charge.
- The next press after the projectile is gone starts a charge as normal.

## Files to create/modify
- src/game/components/weapon.lua — `weapon.shell` holds the live projectile's body id; press routes to detonate vs charge; `consumed` flag until release
- src/game/systems/projectile_system.lua — drop `Lifetime.tick`; expose lookup by body id
- src/game/blast.lua — reused for remote detonation
- src/game/config.lua — drop `projectile.lifetime`
- src/game/components/lifetime.lua, tests/unit/lifetime_test.lua — delete if nothing else uses them
- tests/unit/weapon_test.lua, tests/integration/remote_detonation_test.lua (register)

## Test approach
- Unit: press with an armed live shell detonates, and holding afterwards never charges; press with an unarmed shell does nothing; press after the shell despawns starts a charge.
- Integration: a projectile fired upward survives 10 s in open space; remote detonation next to the enemy kills it.
- Integration: a projectile leaving the soft boundary frees the slot without a blast.

## Acceptance criteria
- [ ] Never more than one live projectile per player.
- [ ] Detonate works only once armed.
- [ ] The detonating press never also starts a charge.
- [ ] No projectile lifetime remains.

## Blocked by
04, 05

## Gotchas
- Resolve `weapon.shell` via `Bodies.get`. A stale id returns nil, which means the slot is free. Never cache the record.
- A detonation and a same-frame contact must not blast twice. `Blast.detonate` already guards on `dead`.
- Pending v1 rounds work clears projectiles on respawn. The stale-id rule above makes that safe.
- `docs/CONTEXT.md` already defines Remote detonation.
