---
name: particles-skip-pairwise-gravity
description: Exhaust particles are passive bodies; Gravity.pairwise must skip them both ways or cost grows O(n^2)
metadata:
  type: convention
---

**Why:** `Gravity.pairwise` loops every body for every receiver. Hundreds of exhaust particles make that quadratic, and their pull is negligible.

- Particle bodies carry `passive = true`. They still sample the static and boundary fields in `Sim.integrate`.
- Filter passive bodies out before the receiver loop, not inside it.
- Any future cosmetic body kind should be passive too.
