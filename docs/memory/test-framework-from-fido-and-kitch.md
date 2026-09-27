---
name: test-framework-from-fido-and-kitch
description: The three-tier test framework is ported from ~/Projects/fido-and-kitch/tests; copy from there, strip Tiled/bump parts
metadata:
  type: reference
---

The test framework is ported from the sibling project at `/Users/fabian/Projects/fido-and-kitch`.

**How to apply:**
- Source files: `tests/unit/run.lua`, `tests/integration/run.lua`, `tests/e2e/run.lua`, `tests/support/{love_mock,fake_input,frame_stepper,game_harness,capture}.lua`, and `test-{unit,integration,e2e,all}.sh`.
- Keep: the tier split, `test()`/`assert*` runner surface, `FakeInput`, `FrameStepper`, `Capture`, e2e flags `--paced` / `--filmstrip[=N]`, `CI` skip of e2e.
- Strip: Tiled map loading, `bump` physics, `sti`, `hump` class usage, headless entity bootstrap. GRAV//TY has none of these.
- `GameHarness.startMatch(levelTable, opts)` replaces fido-and-kitch's `startGame(mapPath)`. Tests pass literal level tables, not files.
- Unit tests for `src/core`, `src/sim`, `src/game` need no `love` mock at all (see `docs/ARCHITECTURE.md`).
