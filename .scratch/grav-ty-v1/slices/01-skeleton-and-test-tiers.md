Status: pending
Complexity: medium

# Project skeleton and test tiers

## What to build
- `./run.sh` opens a 1280×720 virtual-resolution window, letterboxed, showing "GRAV//TY" in vector-style text on black.
- The three test tiers run and pass with one smoke test each.
- Fixed-timestep loop in `app` calling an empty `Match.step(ctx)`.

## Files to create/modify
- main.lua, conf.lua, run.sh, .gitignore, .luarc.json
- test-unit.sh, test-integration.sh, test-e2e.sh, test-all.sh
- src/app/main.lua — LÖVE callbacks, fixed-timestep accumulator
- src/app/compat.lua — version detection; empty wrappers to start
- src/app/screen.lua — virtual resolution, letterbox transform
- src/game/match.lua — `Match.new(level, config)`, empty `Match.step(ctx)`
- src/game/config.lua — tuning table (empty sections)
- tests/unit/run.lua, tests/integration/run.lua, tests/e2e/run.lua
- tests/support/{love_mock,fake_input,frame_stepper,game_harness,capture}.lua
- tests/README.md
- tests/unit/runner_smoke_test.lua, tests/integration/harness_smoke_test.lua, tests/e2e/harness_smoke_test.lua

## Test approach
- Unit: runner discovers and runs a trivial test; `Screen.fit(w,h)` returns correct scale and offsets for wider and taller windows.
- Integration: `GameHarness.startMatch(level)` boots under the mock; `FrameStepper.step(game, 60)` advances `ctx.time` by 1 s.
- E2E: real window boots; `Capture.capture('title')` writes a PNG.

## Acceptance criteria
- [ ] `./run.sh` shows the title on LÖVE 11.5.
- [ ] `./test-all.sh` passes; e2e skipped with a message when `CI` is set.
- [ ] `require('src.game.match')` works under plain `luajit` with no `love` global.

## Blocked by
None — can start immediately.

## Gotchas
- Port from `/Users/fabian/Projects/fido-and-kitch/tests/`. See `docs/memory/test-framework-from-fido-and-kitch.md` for what to strip.
- fido-and-kitch `conf.lua` targets LÖVE 12. Keep `t.graphics = t.graphics or {}` so 11.5 still works.
- `GameHarness.startMatch` takes a level table, not a file path.
