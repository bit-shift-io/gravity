---
name: pad-parity
description: Every player-facing action needs a gamepad route; only dev keys and screenshot may stay keyboard-only
metadata:
  type: convention
---

The game targets Steam Deck, where players have a pad and no keyboard. LÖVE cannot detect whether a keyboard is attached.

**Why:** A keyboard-only action strands a Deck player. The keyboard-first default roster once produced two ships nobody could fly.

**How to apply:** When adding a screen, prompt or action, give it a pad button too. Write prompts naming both devices in one static string ("REMATCH: ENTER / A"). Keyboard-only is allowed for P (screenshot; the Deck has its own), R (dev replay), 1/2 (debug overlays) and seed digit typing.
