---
name: ai-fill-overwrites-scripted-intents
description: Match.step runs AI.fill, so fixtures that script ctx.intents on AI-bound slots get overwritten
metadata:
  type: convention
---

**Why:** A test that sets `ctx.intents[slot]` by hand on an AI slot is silently overridden every step, so the scripted fire or thrust never happens and the assertion fails for no obvious reason.

**How to apply:** When a fixture passes a roster to `GameHarness.startMatch` or `Match.new` and scripts intents, bind those slots to keyboard layouts (`wasd`, `arrows`, `ijkl`), not `{ kind = "ai" }`. To test the input layer on its own, call `Input.updateIntents(ctx, ctx.roster)` directly instead of stepping the match.

`AI.fill(ctx)` runs in step 1 of `Match.step` and writes intents for every AI slot (a neutral intent when the ship is dead). Human slots are left alone.
