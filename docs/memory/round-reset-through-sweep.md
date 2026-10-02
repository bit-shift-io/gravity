---
name: round-reset-through-sweep
description: Between rounds, ships, projectiles, asteroids and particles are removed by marking dead and letting the step-7 sweep run
metadata:
  type: project
---

Round reset must not clear pools or the body store directly. Mark every record and its body dead, spawn the new ships in the same step, and let the despawn sweep remove the old ones.

**Why:** `Pools.sweep` must run before `Bodies.sweep` so no record points at a freed body id. Dead ships also stay in the pool until the sweep, so the round-end check counts `dead == false`.

**How to apply:**
- Also reset `ctx.asteroidSpawnTimer` and clear `ctx.events`, or old crash animations replay.
- Respawn picks two distinct candidates with `ctx.rng`, never `math.random`.
- Fixture levels have `spawnPoints` but no candidate list; fall back to `spawnPoints`.
