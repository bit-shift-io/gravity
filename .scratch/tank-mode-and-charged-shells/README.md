# Tank Mode and Charged Shells

## Problem
- Landing is too punishing: a slow or slightly tilted touch crashes the ship.
- A landed ship is a sitting target. It cannot aim or fire.
- Shots are fixed-speed rapid fire. There is no skill in choosing power or timing.

## Solution
- Any world touch under a generous speed limit lands the ship. It auto-rights and morphs into a domed **tank**.
- In tank mode, left/right swings a **turret**. Thrust lifts off straight up from the surface.
- Fire is **charge-and-release** in both modes. One **projectile** per player flies until it hits something or is **remote-detonated**, then **blasts** in a circle.

## Out of Scope
- Driving the tank along the surface.
- Landing on asteroids. Ship–asteroid contact is always a crash.
- Multiple projectiles in flight per player.
- Blast damage to worlds or asteroids (asteroids are pushed, never destroyed by a blast).
- Gamepad bindings (pending v1 menus/gamepads work picks these up).

## Cross-cutting Constraints
- Fire intent stays a held boolean from `app`. Press/release edges are derived in `game` from component state, so integration tests drive them by toggling `ctx.intents`.
- Every new tuning number goes in `config.lua`: crash speed, turret limit and speed, charge time, min/max speed, blast radius, push strength, morph duration.
- Morph is cosmetic. Game state switches instantly; only rendering interpolates.

## Acceptance Criteria
- [ ] Touching a world under the speed limit at any angle lands the ship upright. Faster touches crash.
- [ ] Touching an asteroid always crashes.
- [ ] A landed ship morphs over time into a chamfered dome with a turret pointing straight up from the surface.
- [ ] Left/right aim the turret within the configured limit. Thrust lifts off straight up and morphs back.
- [ ] Tank refuels on the surface.
- [ ] Tapping fire launches at minimum speed. Holding charges linearly to maximum over 3 s. A bar under the ship shows charge.
- [ ] A projectile lives until it leaves the soft boundary, hits something after arming, or is remote-detonated.
- [ ] A second fire press detonates an armed projectile. Presses while it is unarmed do nothing.
- [ ] A blast kills every ship in its radius, shooter included, and pushes asteroids outward.

## References
- Glossary: `docs/CONTEXT.md` — Tank mode, Turret, Charge, Projectile, Blast, Remote detonation, Landing, Crash
- [ADR 0001](../../docs/adr/0001-composed-pools-architecture.md) — components are plain data; systems call them
- Prior plan: `.scratch/grav-ty-v1/` slices 05, 07, 09 built the landing, weapon and riding code this feature changes
- Repo memory: `docs/memory/v1-pending-slices-predate-tank-mode.md`
