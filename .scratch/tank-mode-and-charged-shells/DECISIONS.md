# Decisions

### Q1: Land vs crash on world contact
**Decision:** Keep the crash check on speed only. Raise the limit from 40 to 150 px/s. Drop the angle check.
- **Why:** Crashing was too easy. The ship auto-rights on landing.
- **Implication:** `Lander.check` becomes a single speed test. The snap-upright step already exists.
- **Alternatives considered:** Every contact becomes tank — rejected, reckless approaches still need a cost.

### Q2: Asteroids
**Decision:** Ship–asteroid contact always crashes. Riding is removed.
- **Why:** Tank mode on a spinning, moving host adds complexity for little play value.
- **Implication:** Delete riding code: host following, rider mass, rider death, refuel multiplier.
- **Alternatives considered:** Tank on asteroids; keep riding without a turret.

### Q3: Turret range and start angle
**Decision:** Clamped to ±`turretLimit` from the surface normal (default 80°, configurable). Starts straight up on every landing.
- **Why:** The barrel never lies flat or points into the ground.
- **Alternatives considered:** 180° horizon-to-horizon; full 360°.

### Q4: Firing mode
**Decision:** Charge-and-release in flight (from the nose) and in tank mode (from the turret).
- **Alternatives considered:** Tank-only firing; keep old cannon in flight.

### Q5: Projectiles in flight
**Decision:** One per player. While it lives, fire presses detonate it. The detonating press is consumed — no charge starts until release and re-press.
- **Why:** A tap has one meaning at any moment.
- **Alternatives considered:** Several in flight, detonate oldest.

### Q6: Blast effect
**Decision:** Kills every ship in `blastRadius`, shooter included. Pushes asteroids outward. Does not destroy asteroids.
- **Implication:** A direct armed hit and a remote detonation run the same blast code.

### Q7: Self-hit protection
**Decision:** Keep the 0.15 s arm delay. Unarmed projectiles bounce off ships. Detonate presses while unarmed are ignored (and consumed).
- **Alternatives considered:** No arm delay; arm delay but detonation always allowed.

### Q8: Charge indicator
**Decision:** A short horizontal bar under the ship, screen-aligned, filling left to right.
- **Alternatives considered:** Ring around ship; HUD bar.

### Q9: Morph and lift-off
**Decision:** Morph animates (default 0.25 s) both ways. Lift-off is always straight up the surface normal. Tank refuels.
- **Why:** Lift-off direction stays predictable, independent of turret aim.

## Assumptions
- Charge speeds: tap = 150 px/s, full = 700 px/s, linear over 3 s. Old fixed speed was 500.
- Launch speed is added to the firer's body velocity, as today. A tank's body velocity is zero.
- A charge in progress carries over lift-off and landing. It fires from whichever muzzle is current at release.
- Controls switch the instant the ship lands. You can aim and charge during the morph.
- A projectile touching a world or asteroid explodes, armed or not. Only ships get the unarmed bounce.
- Leaving the soft boundary despawns a projectile silently — no blast.
- The projectile lifetime and weapon cooldown are removed. The one-projectile rule replaces the cooldown.
- The blast visual is an expanding line ring in the crash-debris style. Pending v1 vector-effects work may restyle it.

## Trade-offs
- Edge detection lives in the weapon component (`prevFire`), not in `app/input.lua`. Integration tests stay keyboard-free at the cost of one extra field.
- Morph progress is derived at render time from `lander.changedAt` and `ctx.time`. No game-side animation state to tick or test.

## CONTEXT.md entries
- **Tank mode** (replaces Landed) — ship state after landing on a world. Fixed to the surface, refuelling, aims a turret, can fire.
- **Turret** — tank's barrel. Aim is relative to the surface normal, clamped to a configured limit.
- **Charge** — held-fire build-up that sets launch speed, from minimum on a tap to maximum after 3 s.
- **Blast** — circular explosion of a projectile. Kills ships in radius, pushes asteroids.
- **Remote detonation** — a fire press that blasts the player's armed projectile in flight.
- **Morph** — cosmetic triangle ↔ dome animation on landing and lift-off.
- Updated: Ship, Projectile, Asteroid, Landing, Crash. Removed: Landed, Riding.
