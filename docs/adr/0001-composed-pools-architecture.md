# ADR 0001: Composed pools architecture

**Status:** Accepted
**Date:** 2026-09-27

## Context

- GRAV//TY's core mechanic is all-pairs: every dynamic body pulls on every other, and collides with every other.
- The sibling project fido-and-kitch is object-oriented: entity classes carrying self-updating component objects that call `love.*` directly.
- That style hid frame order inside per-entity component lists and needed a `love.*` mock and a headless bootstrap to test.
- The game needs reuse across types: ships land on both worlds and asteroids; weapons will be swappable.

## Decision

Use **composed pools**, a hybrid of typed pools (as in bit-shift-io/planck-time-trials) and data components:

- Typed pools (`ships`, `projectiles`, `asteroids`) own record lifetimes and frame order.
- Components are plain-data sub-tables plus pure-function modules. Pool systems call them explicitly.
- A shared sim body store owns all physics. Gravity and collision iterate bodies, not pools.
- Only `src/app/` touches `love.*`.

The full convention is in `docs/ARCHITECTURE.md`.

## Alternatives Considered

- **Object-oriented (fido-and-kitch style)** — all-pairs gravity has no natural home; frame order hidden; headless testing needs a mock.
- **Full ECS (tiny-ecs, Concord)** — maximum composition, but high indirection and library lifecycle concepts. Its performance benefits do not appear at under 50 live entities, or in Lua where components are hash tables anyway.
- **Plain typed pools** — explicit and testable, but reuse across types degrades into duplication or ad-hoc helpers.

## Consequences

- Frame order is one readable list in `Match.step`.
- `sim` and `game` run headless under plain LuaJIT. Most tests are fast unit tests.
- Landing is written once and shared by worlds and asteroids via `lander` / `landable`.
- No arbitrary runtime composition. Optional components need nil checks in the owning system.
- Records reference bodies by id, so stale ids are a bug class. Mitigated by generation-checked ids and a single despawn sweep.
- Runtime effects and pool transfer are reserved extension points, not built.
