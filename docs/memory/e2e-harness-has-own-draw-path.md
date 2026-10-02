---
name: e2e-harness-has-own-draw-path
description: The e2e game harness draws the match itself and never calls MatchState.draw; new overlays must be added there too
metadata:
  type: convention
---

**Why:** `tests/support/game_harness.lua` has a hand-rolled `game:draw()`. An overlay added only to `MatchState.draw` never appears in e2e captures, so the test passes without drawing it.
**How to apply:** when adding a screen-space overlay or HUD element in `src/app/`, also call it in the harness draw path, after `Hud.draw`, in the same order as `match_state.lua`.

`ScoreCard.draw` and `MatchOver.draw` are wired into both.
