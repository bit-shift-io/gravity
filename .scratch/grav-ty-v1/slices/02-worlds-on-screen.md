Status: pending
Complexity: medium

# Worlds on screen from a level table

## What to build
- A level is a plain table: worlds (polygon vertex lists, density or mass override), spawn points, asteroid settings.
- The match renders each world as a closed white outline.
- A built-in fixture level with one convex and one concave world is the default until generation lands.

## Files to create/modify
- src/core/vec2.lua — add, sub, scale, dot, cross, length, normalize, rotate, perp
- src/core/poly.lua — area, centroid, pointInPolygon, segmentIntersect, isSimple, edge outward normals, winding normalisation
- src/game/level.lua — `Level.validate(t)`, derive world mass from density × area
- src/game/levels/fixture_two_worlds.lua
- src/app/render/worlds.lua
- src/app/states/match_state.lua
- tests/unit/vec2_test.lua, tests/unit/poly_test.lua, tests/unit/level_test.lua
- tests/e2e/worlds_render_test.lua

## Test approach
- Unit: polygon area/centroid for square, triangle, concave L-shape; pointInPolygon inside a concave notch returns false; outward normals point away from centroid on convex shapes; `Level.validate` rejects self-intersecting polygons.
- E2E: capture of the fixture level.

## Acceptance criteria
- [ ] Fixture level draws both worlds as outlines.
- [ ] Mass derives from density × area unless `mass` is set.
- [ ] Polygons are normalised to one winding so outward normals are consistent.

## Blocked by
01

## Gotchas
- Y points down. A counter-clockwise polygon on paper is clockwise in screen coordinates. Pick one winding in `Poly.normalize` and test normals against it.
