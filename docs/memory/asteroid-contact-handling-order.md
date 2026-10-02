---
name: asteroid-contact-handling-order
description: Asteroid splitting depends on contact handler order in Match.step; blast push must run before the split
metadata:
  type: project
---

`Match.step` hands one contact list to `ShipSystem`, `ProjectileSystem`, then `AsteroidSystem`.

- Projectile hit: `Blast.detonate` pushes live asteroids first, then `AsteroidSystem` splits. Fragments inherit the pushed velocity.
- Reordering would split first; the dead parent would then miss the push.
- An asteroid can appear in several contacts in one step. Skip it once dead.
