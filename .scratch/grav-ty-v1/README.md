# GRAV//TY v1

## Problem
- No game exists yet. The repo is empty.
- The core idea — duelling ships among polygon worlds whose gravity bends everything — is unproven.
- The architecture must stay testable and open to gravity weapons and moving worlds later.

## Solution
- A single-screen, two-player local duel in LÖVE. Vector lines on black.
- Procedurally generated levels of 1–3 polygon worlds. Their gravity is baked into a grid; ships, projectiles, and asteroids also pull on each other.
- Ships fly on limited fuel, land to refuel, and shoot gravity-bent projectiles. Best of 5 rounds.

## Out of Scope
- Moving, orbiting, or rotating worlds (future goal — see ADR 0002).
- Gravity weapons (black holes, white holes), pickups, effects, pool transfer.
- Health or shields. More than 2 players. Online play. AI opponents.
- Audio. Glow/bloom shader. Destructible terrain. Asteroid splitting.
- Level editor. Hand-authored shipped levels.

## Cross-cutting Constraints
- Follow `docs/ARCHITECTURE.md` (composed pools). No `love.*` outside `src/app/`.
- Runs unmodified on LÖVE 11.5 and 12. Version-sensitive calls go through `src/app/compat.lua`.
- Fixed timestep of 1/60 s. The simulation is deterministic for a given seed and input sequence.
- Virtual resolution 1280×720. All sim units are virtual pixels. Y points down.
- All tuning numbers live in `src/game/config.lua`.
- Nothing is removed from a pool or the body store outside the despawn sweep.
- Tests pass literal level tables, never generated levels, unless the test targets the generator.

## Acceptance Criteria
- [ ] `./run.sh` launches to a title screen on LÖVE 11.5 and 12.
- [ ] Two players on one keyboard play a full best-of-5 match on a generated level and see a winner.
- [ ] Ships, projectiles, and asteroids visibly curve under world gravity and under each other's pull.
- [ ] A ship can land on a world or a slowly spinning asteroid, refuel, and lift off.
- [ ] Running out of fuel leaves a ship drifting; drifting off the soft boundary destroys it.
- [ ] Key 1 shows the combined gravity field; key 2 shows grid lines and collision shapes.
- [ ] The same seed reproduces the same level and asteroid spawns.
- [ ] `./test-all.sh` passes.

## References
- [Architecture](../../docs/ARCHITECTURE.md)
- [ADR 0001: Composed pools](../../docs/adr/0001-composed-pools-architecture.md)
- [ADR 0002: Hybrid gravity field](../../docs/adr/0002-hybrid-gravity-field.md)
- [Glossary](../../docs/CONTEXT.md)
- Test framework source: `/Users/fabian/Projects/fido-and-kitch/tests/`
- Architecture inspiration: https://github.com/bit-shift-io/planck-time-trials
