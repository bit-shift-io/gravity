# Glossary

Domain terms for GRAV//TY. Code, docs, and conversation use these words with these meanings only.

## World
- **Definition:** A static polygonal body in space (convex or concave) that exerts gravity and can be landed on.
- **Boundary:** Not a sphere. No holes. Does not move in v1. Not stored in the body store.

## Body
- **Definition:** A dynamic physics record in the sim body store: position, velocity, angle, mass, shape.
- **Boundary:** Every ship, projectile, and asteroid has exactly one body. Worlds are not bodies.

## Gravity field
- **Definition:** The per-cell gravity vector grid covering the play area plus the soft-boundary margin.
- **Boundary:** Holds only the baked static field from worlds. Dynamic bodies add their pull pairwise, not through the grid.

## Static field
- **Definition:** The part of the gravity field produced by worlds, computed once at level load.
- **Boundary:** Never changes during a match.

## Pool
- **Definition:** A typed array of records of one kind: `ships`, `projectiles`, `asteroids`.
- **Boundary:** Owns record lifetime and update order. Does not own physics.

## Record
- **Definition:** A plain table in a pool, holding a body id and component sub-tables.
- **Boundary:** No methods, no metatables.

## Component
- **Definition:** A plain-data sub-table on a record plus a module of pure functions over it.
- **Boundary:** Never updates or draws itself. The owning pool system calls it.

## Ship
- **Definition:** A player-controlled triangular craft with fuel, thruster, lander, and weapon components.
- **Boundary:** One hit point. Two ships per match in v1.

## Projectile
- **Definition:** A shot fired from a ship's nose, affected by gravity, with a lifetime.
- **Boundary:** **Unarmed** until its arm delay elapses — bounces off ships. **Armed** afterwards — destroys any ship it hits, including its shooter.

## Asteroid
- **Definition:** A drifting convex rock that spawns off-screen, spins slowly, exerts gravity, and can be landed on.
- **Boundary:** Not a world. Destroyed on world contact. At most 1–2 alive.

## Landing
- **Definition:** Touching a world or asteroid slowly enough, with the nose aligned to the surface normal.
- **Boundary:** Speed is measured relative to the surface point touched. Failing either check is a crash.

## Landed
- **Definition:** Ship state after landing: fixed to the surface, refuelling, unable to rotate or fire.
- **Boundary:** Ends only on thrust (lift-off) or destruction.

## Riding
- **Definition:** Being landed on an asteroid; the ship moves and rotates with it.
- **Boundary:** If the asteroid is destroyed, the riding ship is destroyed too.

## Crash
- **Definition:** Ship contact with a world or asteroid that fails the landing check. Destroys the ship.

## Lost to space
- **Definition:** A ship that drifts past the soft-boundary margin is destroyed.

## Soft boundary
- **Definition:** A margin beyond the screen edge where bodies may travel; ships there show an edge arrow.
- **Boundary:** Ships past it are lost to space; projectiles and asteroids past it despawn.

## Round
- **Definition:** Play from spawn until at most one ship remains. Both dying in the same step is a draw.

## Match
- **Definition:** Best of 5 rounds — first to 3 round wins. One level layout for the whole match.

## Seed
- **Definition:** The number that determines a match's generated level and asteroid spawns.
- **Boundary:** Shown on the score card. Can be fixed to replay a layout.

## Hardcore
- **Definition:** A match setting where rotating burns fuel.

## Contact
- **Definition:** A collision event emitted by the sim for one step, consumed by pool systems.
- **Boundary:** The sim reports contacts; it never decides outcomes (land, crash, bounce).

## Effect (reserved)
- **Definition:** A timed modifier attached to a record or body at runtime, e.g. shield or EMP.
- **Boundary:** Not built in v1. See `docs/ARCHITECTURE.md`.

## Pool transfer (reserved)
- **Definition:** Moving a record between pools while keeping its body, e.g. ship → wreck.
- **Boundary:** Not built in v1.
