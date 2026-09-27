---
name: love-11-and-12-compat
description: The game must run on both LÖVE 11.5 and LÖVE 12; route version-sensitive calls through src/app/compat.lua
metadata:
  type: project
---

GRAV//TY must run unmodified on LÖVE 11.5 (Fabian) and LÖVE 12 (Fabian's brother).

**Why:** Both developers play and test locally on different versions.

**How to apply:**
- Put every version-sensitive call in `src/app/compat.lua`. Branch on `love.getVersion()`.
- Known differences to watch:
  - `love.conf`: LÖVE 12 adds `t.graphics.*` options. Guard with `t.graphics = t.graphics or {}`.
  - Stencils: `love.graphics.stencil` / `setStencilTest` are replaced in 12 by `setStencilMode` / `setStencilState`. Avoid stencils if possible.
  - Canvas/texture creation options and some `love.graphics.newMesh` formats changed.
  - `love.filesystem.getInfo` exists in both; avoid removed 0.10-era calls.
- Prefer the plain API subset: lines, polygons, `setColor`, `setLineWidth`, `push`/`pop`/`translate`/`scale`, a single canvas.
- The e2e tier runs on whatever `love` binary is found. Run it on both versions before merging rendering changes.
