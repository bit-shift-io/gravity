# GRAV//TY Architecture

GRAV//TY uses **composed pools**: typed entity pools, plain-data components, and a shared simulation body store.
See [ADR 0001](adr/0001-composed-pools-architecture.md) for why.
Terms are defined in [CONTEXT.md](CONTEXT.md).

## Layers

Dependencies point down only. A module never requires a module from a layer above it.

| Layer | Path | Owns | May use `love.*` |
|---|---|---|---|
| app | `src/app/` | LÖVE callbacks, screen states, input mapping, rendering, debug overlay, LÖVE 11/12 compat | **Yes — the only layer that may** |
| game | `src/game/` | Pools, systems, components, match and round rules, level generation, tuning config | No |
| sim | `src/sim/` | Body store, gravity field grid, gravity step, integrator, collision, contact events | No |
| core | `src/core/` | vec2 math, polygon utilities, seeded RNG | No |

- `sim` knows nothing about pools, ships, or rules. It moves bodies and reports contacts.
- `game` and below run under plain LuaJIT with no `love` global. Unit tests exercise them without a mock.

## The three kinds of thing

### Body (sim)
- A plain record in the sim body store: position, velocity, angle, angular velocity, mass, shape, flags.
- Every dynamic object has exactly one body. Worlds are static and live in the level, not the body store.
- Referenced by a **body id**. Ids are generation-checked so a stale id resolves to `nil`, never to a reused slot.
- Gravity and collision iterate the body store, never the pools.

### Pool record (game)
- A plain table in a typed pool: `ships`, `projectiles`, `asteroids`.
- Holds a `body` id plus component sub-tables.
- No metatables, no methods, no back-pointers.

### Component (game)
- A plain-data sub-table on a record, e.g. `ship.fuel`, `ship.lander`.
- Paired with a module of pure functions in `src/game/components/<name>.lua`.
- Functions take the record (or the sub-table) plus `ctx`, and return or mutate data.
- A component **never** has an `update` or `draw` that runs itself. The owning pool system calls it.

```lua
-- a ship record
{ id = 7, body = 12, player = 1,
  fuel     = { amount = 1, capacity = 1, burnRate = 0.2 },
  thruster = { accel = 180 },
  lander   = { state = "flying", host = nil },
  turret   = { angle = 0 },
  weapon   = { kind = "shell", charging = false, charge = 0, prevFire = false } }
```

## Systems and frame order

- One system module per pool: `src/game/systems/<pool>_system.lua`.
- A system exposes `update(ctx)` and `handleContacts(ctx, contacts)`.
- A system calls component functions **explicitly, in a visible order**:

```lua
function ShipSystem.update(ctx)
  for _, s in ipairs(ctx.pools.ships) do
    Thruster.apply(s, ctx)   -- burns via Fuel.consume
    Weapon.tick(s, ctx)
    Lander.tick(s, ctx)      -- refuels via Fuel.add
  end
end
```

- The whole frame order lives in one function, `Match.step(ctx)`:
  1. Read player intents (from `ctx.intents`). `app` fills human slots; `AI.fill(ctx)` fills AI slots.
  2. Ship controls: rotate, thrust, fire.
  3. Spawners (asteroids).
  4. `Sim.step`: gravity, integrate, collide → contact list.
  5. Systems handle contacts: land, bounce, destroy.
  6. Round rules.
  7. **Despawn sweep** — the only place records and bodies are removed.
- Nothing is removed mid-iteration. Systems mark records `dead = true`; the sweep removes them.

## `ctx`

- One table passed to every system and component function.
- Holds `dt`, `time`, `pools`, `sim`, `level`, `config`, `intents`, `rng`, `events`.
- No module reads globals for game state.

## Rendering

- `src/app/render/` holds one draw module per pool, plus worlds, HUD, and the debug overlay.
- Draw modules read record and body data. They never mutate it.
- Components never draw themselves.

## Adding things

- **New behaviour shared across types** → a new component module; add the sub-table in each record constructor that needs it; add one call in each owning system.
- **Optional component** → the system nil-checks: `if s.shield then Shield.tick(s, ctx) end`.
- **New entity type** → a new pool, a new system, a new render module, one new line in `Match.step`.
- **New weapon** → a new `weapon.kind` handler. A gravity weapon (black hole) is a body with large positive or negative mass plus `lifetime`.

## Reserved extension points (not built yet)

Record and body shapes must leave room for these without restructuring:

- **`effects` component** — a list of `{ kind, timer, data }` on a record, ticked by one `Effects.tick(record, ctx)` call. Covers pickups and status effects (shield, EMP, spawn protection).
- **Body-level `effects`** — the same list on a sim body, ticked inside `Sim.step`. Covers effects on any body regardless of pool (black-hole capture, tethers, tracers).
- **Pool transfer** — move a record from one pool to another while keeping its sim body. Runs in the despawn sweep. Covers ship → wreck, projectile → mine.

## Rules

- No `love.*` outside `src/app/`.
- No classes or inheritance. Plain tables and function modules.
- No component self-updates. Systems call components.
- No removal outside the despawn sweep.
- All tuning numbers live in `src/game/config.lua`.
- Fixed timestep of 1/60 s. `app` accumulates real time and calls `Match.step` in fixed increments.
