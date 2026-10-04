# Tests

The suite is split into three tiers, each with its own command:

```sh
./test-unit.sh          # fast headless Lua tests: src/core, src/sim, src/game only, no `love` global at all
./test-integration.sh   # headless harness tests: GameHarness.startMatch drives a match via FrameStepper
./test-e2e.sh           # headed tests: real LÖVE, real window, real rendering, frame capture
./test-balance.sh       # slow AI balance runs (~90s): full seeded matches played to a winner; not in test-all.sh
./test-all.sh           # runs all three in sequence and reports each tier's outcome
```

Every command is dependency-free and exits non-zero if any test fails. Pass a specific test file as an argument to run just that one, e.g.:

```sh
./test-unit.sh tests/unit/runner_smoke_test.lua
```

`./test-all.sh` skips the e2e tier automatically when a `CI` environment variable is set (no display or real LÖVE binary exists in CI), printing an explicit skip message rather than silently omitting it.

## Tiers

- **`tests/unit/`** — pure logic: `src/core`, `src/sim`, `src/game`, and app-layer pure functions like `Screen.fit`. No `love` global at all (see `docs/ARCHITECTURE.md` "Layers").
- **`tests/integration/`** — boots a match with `tests/support/game_harness.lua` from a literal level table (never a file path) and drives it with `tests/support/frame_stepper.lua` at the fixed 1/60s timestep. No real rendering.
- **`tests/balance/`** — same harness as integration, but long seeded matches that check AI balance (e.g. hard beats easy). Run on demand with `./test-balance.sh` when tuning the AI; excluded from `test-all.sh` to keep it fast.
- **`tests/e2e/`** — the same kind of scripted, deterministic scenario as the integration tier, but launched as a real LÖVE process with a real window and real rendering. The only tier where frame capture (`tests/support/capture.lua`) works.

## Shared infrastructure

- **`tests/support/`** — shared across tiers: match bootstrap (`game_harness.lua`), frame stepping (`frame_stepper.lua`), fake input (`fake_input.lua`), the headless `love.*` mock (`love_mock.lua`, for a future slice that needs `love.keyboard`/`love.joystick` headlessly), and the frame capture API (`capture.lua`).
- **`tests/screenshots/`** — capture output from the e2e tier, gitignored. Organised per test file so a run's output is easy to find and clear.

## Writing an e2e test

An e2e test file looks exactly like an integration test — same `test()`/`assert*` surface, same `GameHarness`/`FrameStepper` helpers — with one difference: pass `{ real = true }` to `GameHarness.startMatch`, which skips installing the headless `love.*` mock and boots against the real `love` global the engine already provided. `tests/support/game_harness.lua` then calls `_G.E2E_ON_GAME_STARTED(game)` (set by `tests/e2e/run.lua`) so the runner knows which game object to draw and capture from every frame.

Run a single e2e file directly against real LÖVE while iterating:

```sh
love . e2e=tests/e2e/my_scenario_test.lua
```

`./test-e2e.sh` does this once per file under `tests/e2e/`, discovering the LÖVE binary the same way `run.sh` does (`bin/love.AppImage` if present, else `love` on PATH), and forwards two flags as LÖVE launch arguments:

```sh
./test-e2e.sh --paced                        # one simulated frame per drawn frame, matches real time, actually watchable
./test-e2e.sh --filmstrip                    # capture every 10th simulated frame (default interval)
./test-e2e.sh --filmstrip=5                  # capture every 5th simulated frame instead
```

Both are off unless asked for: default is fast-as-possible with no filmstrip.

## Frame capture (e2e tier only)

Scenario code can request a named capture at any point in a headed test via `Capture.capture(name)`, writing a real rendered image to `tests/screenshots/<test-file>/<name>.png`. A failing assertion automatically captures the frame at the point of failure (named `FAILURE_<test name>.png`) and the failure output names the file.

Calling the capture function from the unit or integration tier raises an explicit error naming the e2e tier as the requirement — it is never a silent no-op.

Captures are debugging artifacts, not visual-regression baselines: they are gitignored and never diffed against a committed reference image.
