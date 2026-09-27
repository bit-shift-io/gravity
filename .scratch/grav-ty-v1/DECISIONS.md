# Decisions — GRAV//TY v1

### Q1: Platform
**Decision:** LÖVE + Lua (LuaJIT). Copy fido-and-kitch's three-tier test framework.
- **Why:** The developer already runs a LÖVE project with a working test harness.
- **Alternatives considered:** Browser TypeScript/Canvas; native Rust/C++; Godot/Unity — not chosen.

### Q2: World motion
**Decision:** Static worlds in v1. Moving, orbiting, rotating worlds later.
- **Why:** Static worlds let the field bake once. Per-frame field recomputation is too slow in Lua.
- **Implication:** Field baking sits behind one module so it can be replaced (ADR 0002).

### Q3: Dynamic gravity
**Decision:** Hybrid. Worlds baked into the grid; dynamic bodies attract pairwise as point masses.
- **Why:** No self-pull, no grid blur, trivially cheap at under 50 bodies.
- **Alternatives considered:** Stamping bodies into the grid — self-pull and blur. See ADR 0002.

### Q4: Match structure
**Decision:** 1 hit point. Best of 5 rounds (first to 3). Respawn with full fuel each round.
- **Alternatives considered:** Health/shields, lives with mid-round respawn — deferred.
- **Assumption:** "Best of 5" means first to 3 wins.

### Q5: Screen edges
**Decision:** Soft boundary. Bodies may go a margin off-screen; ships past it are lost to space.
- **Why:** Keeps gravity continuous; makes fuel-out drift a real threat.
- **Alternatives considered:** Wrap-around — gravity discontinuity at the seam. Lethal hard edge — too harsh.

### Q6: Controls
**Decision:** Rotate (free), thrust (burns fuel), fire (unlimited ammo, cooldown). Hardcore setting makes rotation burn fuel.
- **Why:** A fuel-less ship can still aim and fight.
- **Implication:** Keyboard for both players in v1 (P1 WASD+fire, P2 arrows+fire). Gamepads in the menus slice.

### Q7: Collision matrix
**Decision:**
- Ship–terrain / ship–asteroid: land if the landing check passes, else crash.
- Ship–ship: elastic bounce. Ship–unarmed projectile: bounce. Ship–armed projectile: ship destroyed, shooter included.
- Projectile–terrain / projectile–asteroid: projectile destroyed, **no momentum transfer**. Projectile–projectile: pass through.
- Asteroid–terrain: asteroid destroyed. Asteroid–asteroid: bounce.
- **Why no nudge:** The user ruled that projectiles must not push asteroids.

### Q8: Landing
**Decision:** Land when relative speed < threshold and nose within ±angle of the surface normal. Landed ships refuel and cannot rotate or fire. Thrust lifts off. Any surface is landable.
- **Why no rotate/fire while landed:** Refuelling is a vulnerable commitment, not a turret.
- **Alternatives considered:** Dedicated landing pads — rejected.

### Q9: Landing on asteroids
**Decision:** Asteroids are landable. The ship rides at a fixed local offset. Speed check uses the surface point's velocity (linear + spin). Refuel is faster on asteroids. Riding ship dies with its asteroid. Ship mass joins the asteroid's while riding.
- **Why faster refuel:** Rewards the harder landing.

### Q10: Asteroid spawning
**Decision:** At most 1–2 alive, per-level config. Spawn just off-screen aimed inward with spread. Random convex 6–10 vertex polygons, mass from area. Slow spin. Never spawned on a line straight at a ship's immediate radius.

### Q11–12: Levels
**Decision:** Procedurally generated, 1–3 worlds. Radial-noise blobs with occasional concave notches. Min gap between worlds and from edges. Density randomised per world. One layout per match from one seed. Ships start landed, far apart, full fuel.
- **Why:** User wants simple varied levels without authoring.
- **Implication:** Level format stays a plain table; tests pass literal tables.
- **Alternatives considered:** Hand-authored Lua data levels — rejected.

### Q13: Visuals
**Decision:** 1280×720 virtual, letterboxed. Thin lines on black, no fills. P1 cyan, P2 magenta. No bloom in v1. F1 field overlay, F2 grid + collision shapes.

### Q14: LÖVE version
**Decision:** Run on both 11.5 and 12.
- **Why:** The two developers use different versions.
- **Implication:** Compat shim in `src/app/compat.lua`; see `docs/memory/love-11-and-12-compat.md`.

### Q15–16: Architecture
**Decision:** Composed pools — typed pools + plain-data components + shared sim body store. See ADR 0001 and `docs/ARCHITECTURE.md`.
- **Alternatives considered:** OOP (fido-and-kitch), full ECS, plain typed pools.

### Q17: Runtime composition
**Decision:** Leave room for record/body `effects` and pool transfer; build neither in v1.
- **Why:** No v1 feature needs them. Examples collected: pickups, EMP, black-hole capture, tethers, ship → wreck, projectile → mine.

### D1 (planner default): Physics
**Decision:** Semi-implicit Euler at 1/60 s. Inverse-square gravity with softening: `a = G·m·r / (|r|² + ε²)^1.5`.
- **Why:** Stable enough for orbits at this timestep; deterministic.
- **Alternatives considered:** Velocity Verlet — revisit if orbits drift visibly.

### D2 (planner default): Grid
**Decision:** 16 px cells. Grid covers screen plus soft-boundary margin. Bilinear sampling.
- **Why:** 80×45 on-screen cells bake in well under a second in LuaJIT.

### D3 (planner default): Collision shapes
**Decision:** Circle broadphase. Polygon narrowphase against worlds and asteroids. Ship–ship and ship–projectile use circles. Projectiles use swept segments against polygons.
- **Why:** Landing needs a true surface normal; everything else can be approximate. Swept segments stop tunnelling.

### D4 (planner default): Body ids
**Decision:** Generation-checked ids. Stale id → `nil`.
- **Why:** Records reference bodies by id; a reused slot must not alias.

## Assumptions
- Two players share one keyboard in v1.
- Under 50 live bodies at any time.
- Sim units are virtual pixels and seconds; no real-world units.

## Trade-offs
- Composed pools trade arbitrary runtime composition for explicit frame order and plain-Lua testability.
- Baked field trades future moving worlds for zero per-frame static-gravity cost.
- Circle collision between dynamic bodies trades accuracy for simplicity; landing stays exact.

## CONTEXT.md entries added
World, Body, Gravity field, Static field, Pool, Record, Component, Ship, Projectile, Asteroid, Landing, Landed, Riding, Crash, Lost to space, Soft boundary, Round, Match, Seed, Hardcore, Contact, Effect (reserved), Pool transfer (reserved).
