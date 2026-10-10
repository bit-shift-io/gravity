---
name: match-events-stay-in-ctx
description: ctx.events keeps events for a retention window across steps; consumers must dedupe by event identity
metadata:
  type: convention
---

`ctx.events` is not cleared each step. `ship_system.lua` prunes entries older than `EVENT_RETENTION`, and the round reset clears the list.

**Why:** The camera reads recent crashes from it (`Match` camera focus), so events must outlive the step that raised them.
**How to apply:** Anything that turns events into one-off output (audio, trailer sound cues, highlight scoring) must track events it has seen by table identity, as `Audio.update` does with its `played` set. When starting mid-match (a trailer shot's `from`), mark the events already present as seen.
