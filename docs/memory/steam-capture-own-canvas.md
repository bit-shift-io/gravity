---
name: steam-capture-own-canvas
description: Steam asset capture renders into its own canvas at output size and never nests inside Pipeline.draw
metadata:
  type: convention
---

**Why:** Capture sizes differ from the game rectangle (up to 3840×1240). Nesting inside `Pipeline.draw` would nest canvases and reuse glow canvases sized for the window.
**How to apply:** `tools/steam_assets/` creates canvases through `Compat.newCanvas`, runs glow/CRT itself, and resets the target afterwards. Transparent assets clear to alpha 0, not the background colour.
