# ADR 0002: Hybrid gravity — baked static grid plus pairwise dynamic bodies

**Status:** Accepted
**Date:** 2026-09-27

## Context

- Worlds are arbitrary polygons, convex or concave. Their gravity is not a simple point-mass pull.
- Ships, projectiles, and asteroids must also exert gravity.
- The intuitive model is one grid holding everything: rasterise all masses, look up gravity per cell.
- Brute-force field summation over an 80×45 grid is about 13M operations. That is too slow per frame in Lua.

## Decision

- **Static field:** worlds are rasterised into mass cells at level load. The field at every grid cell is summed once from those mass cells and baked. Bodies sample it with bilinear interpolation.
- **Dynamic gravity:** dynamic bodies attract each other directly as point masses, summed pairwise each step.
- **Debug overlay** draws the combined field (static grid + dynamic bodies) evaluated at each cell centre.
- Gravity law: inverse-square with a softening term, one global `G`.

## Alternatives Considered

- **Stamp dynamic bodies into the grid each frame** — matches the mental model, but a body samples its own well and pulls on itself. It also blurs close encounters to grid resolution.
- **Recompute the full field every frame** — too slow in Lua without an FFT or multigrid solver.

## Consequences

- Static worlds cost nothing per frame.
- Dynamic gravity is O(n²) in bodies. That is fine below about 50 bodies.
- No self-pull and no grid blur between dynamic bodies.
- Black holes and white holes are dynamic bodies with large positive or negative mass. They need no field changes.
- **Moving or rotating worlds (a future goal) break the bake.** They will need a per-shape field stamp that translates and rotates, a coarser per-frame grid, or a faster solver. Keep field baking behind one module so it can be replaced.
