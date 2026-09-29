Status: pending
Complexity: medium

# Triangle ↔ dome morph

## What to build
- On landing the triangle's vertices slide into the dome over `tank.morphDuration` (default 0.25 s). The barrel grows out as it finishes.
- On lift-off the dome morphs back to the triangle over the same duration.
- Controls are live throughout. The morph is visual only.

## Files to create/modify
- src/game/components/lander.lua — set `lander.changedAt = ctx.time` on every state change
- src/game/systems/ship_system.lua — pass `ctx` where the landing state is set
- src/game/config.lua — `tank.morphDuration`
- src/app/render/ships.lua — pure `ShipsRender.morphShape(t)` returning 6 local vertices; lerp by `(ctx.time - changedAt) / morphDuration`
- tests/unit/ship_morph_test.lua (register in tests/unit/run.lua)

## Test approach
- Unit: `morphShape(0)` equals the triangle (padded to 6 vertices), `morphShape(1)` equals the dome, and `morphShape(0.5)` is the midpoint.
- Unit: `changedAt` updates on land and on lift-off.
- e2e capture at mid-morph.

## Acceptance criteria
- [ ] Landing and lift-off both animate. Neither snaps.
- [ ] A ship that spawns flying draws as a plain triangle (no morph from `changedAt = nil`).
- [ ] Turret aim and fire respond during the morph.

## Blocked by
02

## Gotchas
- The triangle has 3 vertices, the dome 6. Pad the triangle by repeating vertices so each dome vertex has a partner. Pick pairings that don't cross (base corners → base corners, nose → both top chamfer points).
- `morphShape` must not need `love`, so the unit tier can call it. Keep `love.*` in `draw` only.
- `ctx.time` resets are a v1 rounds concern. Treat a negative elapsed time as finished.
