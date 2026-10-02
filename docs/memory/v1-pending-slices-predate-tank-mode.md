---
name: v1-pending-slices-predate-tank-mode
description: The remaining v1 slices (rounds, procedural levels, menus/gamepads, vector effects) were planned before tank mode and charged shells
metadata:
  type: project
---

The unfinished v1 slices — rounds and match, procedural levels, menus/settings/gamepads, vector effects — were written before tank mode replaced landing, riding was removed, and firing became charge-and-release.

**Why:** Their briefs still use the old words and mechanics ("start landed", asteroid-landing refuel indicators, fixed-rate fire).

**How to apply:**
- Read "landed" as tank mode (`docs/CONTEXT.md`). Ships that start on the surface start as tanks with the turret straight up.
- Drop anything about riding asteroids or asteroid refuel rates.
- Gamepad bindings need a turret-aim axis and a hold-to-charge fire button.
- Vector-effects debris may restyle the blast ring, not only the crash burst.
- Round reset must clear each player's live-projectile slot. A stale body id already reads as "free".
- The rounds-and-match brief has been re-planned for tank mode. Rounds are done in-world on `ctx`, with no separate score-card or match-over states.
