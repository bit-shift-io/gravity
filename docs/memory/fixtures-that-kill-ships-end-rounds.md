---
name: fixtures-that-kill-ships-end-rounds
description: Integration fixtures that kill a ship (e.g. parking it far out of bounds) trigger round end and respawn unless endDelay is overridden
metadata:
  type: convention
---

**Why:** the round rules step ends the round when at most one ship is alive, then respawns and refuels both ships after `round.endDelay + round.cardDuration`. A scenario that parks ship 2 at y = -1,000,000 (hard-boundary kill) gets its ship 1 teleported mid-test.
**How to apply:** when a test needs a ship dead but the scenario to continue, pass a config override with `round.endDelay = math.huge` to `startMatch`. A missing `cardDuration` is treated as 0. Levels with fewer than 2 ships never end a round.
