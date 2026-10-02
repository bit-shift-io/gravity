---
name: post-pipeline-canvas-rules
description: Rules for the post-effects canvas pipeline: size, resize, ordering, and what bypasses it
metadata:
  type: convention
---

**Why:** The game rectangle changes with window size, and several tools draw the match themselves.

- Canvases are sized to the game rectangle (`Screen.fit`), not the window. Rebuild on size change, never per frame.
- Order is scene → glow → CRT. HUD and debug overlay are inside the scene canvas.
- Letterbox bars are never processed. Clear the window black before drawing the result.
- Canvas and shader creation go through `src/app/compat.lua`. Avoid stencils.
- `tests/support/capture.lua` draws via `game:draw()` and bypasses the pipeline. Keep the pipeline in `love.draw` so it never nests canvases.
- Shaders have no unit tests. Unit-test pure logic (mode cycling, canvas size) and eyeball the rest on LÖVE 11.5 and 12.
