Status: pending
Complexity: high

# Procedural level generation

## What to build
- `LevelGen.generate(seed, config)` returns a level table of 1–3 worlds: radial-noise blobs, sometimes with a concave notch, spaced apart and clear of the edges, with randomised density.
- Ships start landed on the surface points farthest apart, nose along the normal, full fuel.
- One seed per match. The seed shows on the score card; `./run.sh seed=1234` fixes it.

## Files to create/modify
- src/game/level_gen.lua
- src/game/spawn_points.lua — choose far-apart landable surface points with outward normals
- src/game/systems/ship_system.lua — spawn landed
- src/game/match.lua — generate from seed at match start; rematch reuses seed
- src/app/main.lua — parse `seed=` arg
- src/app/states/score_card_state.lua — show seed
- src/game/config.lua — world count range, radius range, noise, notch chance, min gap, edge margin, density range
- tests/unit/{level_gen,spawn_points}_test.lua
- tests/integration/generated_match_test.lua

## Test approach
- Unit: over 200 seeds every level validates (simple polygons, no overlap, gap and margin respected, 1–3 worlds); the same seed produces an identical table; spawn points lie on world edges with outward normals.
- Integration: a match on a generated level starts with both ships landed and stable for 2 s with no input.

## Acceptance criteria
- [ ] Generated levels always validate.
- [ ] Same seed → identical level.
- [ ] Ships start landed, far apart.
- [ ] Fixed seed via command line.

## Blocked by
05, 10

## Gotchas
- Placement retries must be bounded. After N failures reduce world count, never loop forever.
- A notch deep enough to self-intersect must be rejected by `Poly.isSimple`, not by luck.
- Spawn points inside a narrow notch can trap a ship. Require clearance above the spawn point.
