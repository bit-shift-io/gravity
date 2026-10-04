---
name: new-pooled-kind-reshuffles-seeded-draws
description: registering a pooled AI kind changes every seeded personality draw
metadata:
  type: convention
---

**Why:** `AI.draw` indexes into the sorted pool, so adding a kind changes which personality a given seed draws.

**How to apply:** Tests that depend on a fixed seed's personality should bind `binding.behavior` explicitly. Register meta kinds (Schizo, Chaos) so Schizo's switch pool can exclude them.
