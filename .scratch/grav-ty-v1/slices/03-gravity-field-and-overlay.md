Status: done
Complexity: high

# Baked gravity field and debug overlay

## What to build
- At match start, worlds are rasterised into 16 px mass cells and the static field is baked for every grid cell.
- `Field.sample(field, x, y)` returns a bilinearly interpolated acceleration vector.
- F1 toggles an overlay: one arrow per cell (direction; length and colour by magnitude). F2 toggles grid lines and world collision outlines.

## Files to create/modify
- src/sim/field.lua — `Field.bake(level, config)`, `Field.sample`, grid covers screen + soft-boundary margin
- src/sim/gravity.lua — `Gravity.pointMass(dx, dy, m, G, eps)` softened inverse-square
- src/game/config.lua — `gravity.G`, `gravity.softening`, `field.cellSize`, `boundary.margin`
- src/game/match.lua — bake on `Match.new`, store in `ctx.sim.field`
- src/app/render/debug_overlay.lua
- src/app/input.lua — debug toggles only
- tests/unit/gravity_test.lua, tests/unit/field_test.lua
- tests/e2e/field_overlay_test.lua

## Test approach
- Unit: single square world — sampled field points toward its centroid from all four sides; magnitude falls off with distance; sampling between cell centres interpolates smoothly (no step at cell edges); samples outside the grid clamp to the edge cell.
- Unit: two worlds — the point midway between equal worlds has near-zero field.
- Unit: bake of the fixture level completes under a time budget (e.g. 500 ms under LuaJIT).
- E2E: capture with F1 on.

## Acceptance criteria
- [ ] Field arrows visibly point into worlds, including into concave bays.
- [ ] Bilinear sampling has no discontinuity across cell edges.
- [ ] Baking lives entirely behind `Field.bake` so it can be replaced for moving worlds later.

## Blocked by
02

## Gotchas
- Cells inside a world still get a field value; nothing samples there in play, but the overlay should skip or dim them.
- A mass cell must not include itself in its own cell's field sum (divide-by-softening only). Softening handles it, but test it.
- Mass per cell = world mass × (cell area inside world ÷ world area). Use cell-centre inclusion for v1; supersampling is a later refinement.
