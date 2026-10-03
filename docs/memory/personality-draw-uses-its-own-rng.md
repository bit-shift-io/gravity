---
name: personality-draw-uses-its-own-rng
description: AI personality draws must use an rng derived from the seed, never ctx.rng
metadata:
  type: convention
---

**Why:** `ctx.rng` drives level generation and asteroid spawns. An extra draw from it shifts every later value, so the same seed would give a different level than before.

**How to apply:** Build a separate `Rng` from the match seed (offset per slot) for personality draws. Keep the pool sorted by name so draw order is stable.
