---
name: fragments-cling-under-gravity
description: Split fragments exert gravity on each other and can stay touching for seconds, so sibling immunity may last long; tests must force separation
metadata:
  type: convention
---

**Why:** Asteroids pull on each other, so the outward split nudge (`config.asteroid.splitNudgeSpeed`) may not separate fragments. Sibling immunity (`siblingImmune` on the pool record) only ends once siblings stop touching, so a test that waits for natural drift will hang on immunity.
**How to apply:** When testing that siblings collide later, move their bodies apart by hand and step once to release immunity, then overlap them. Fragments also die on repeated floor contact if they keep a velocity into the world.

Immunity is cleared in `releaseSeparatedSiblings` at the start of `AsteroidSystem.handleContacts`, before the step's own splits create fresh overlapping fragments.
