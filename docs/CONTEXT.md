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

## Player
- **Definition:** One participant in a match, human or AI, identified by its slot index (1–6).
- **Boundary:** `ship.player` is the slot index. At most 6 players per match, any of them human.

## Roster
- **Definition:** The ordered list of slots for a match, each with a colour and a binding.
- **Boundary:** Setup always edits six rows (one per palette colour, empty ones allowed) and persists them. The match roster is the non-empty rows, compacted: 2–6 slots, none empty, at least one human (the rest may be AI).

## Slot
- **Definition:** One seat in the roster: a colour index and a binding.
- **Boundary:** Colours are unique across slots; in setup, cycling a colour swaps it with the row that holds it. A setup row may be empty; in a match its index is the player number.

## Binding
- **Definition:** What drives a slot: a keyboard layout, a gamepad, an AI level, or none (an empty setup row).
- **Boundary:** Keyboard layouts and gamepads cannot bind two slots. AI bindings may repeat.

## Keyboard layout
- **Definition:** One of three fixed key sets: WASD+Q, arrows+Shift, IJKL+O.
- **Boundary:** Rotate, thrust and fire only. Not remappable.

## AI player
- **Definition:** A slot bound to an AI level. It writes the same intents a human would.
- **Boundary:** No HUD fuel bar or pips. Listed on the score card and match-over overlay.

## AI level
- **Definition:** Easy or hard: a set of config numbers (aim error, reaction delay, prediction horizon, dodge quality) applied to any personality.
- **Boundary:** Not different logic per level.

## Personality
- **Definition:** A registered AI behaviour with its own state machine (Hunter, Hopper, Sniper, Artillery, Chaos, Schizo, Skirmisher, Ambusher, Kamikaze), drawn at random per AI slot from the match seed.
- **Boundary:** Not chosen in setup. Not tied to a level: any personality runs at either level. Listed on the score card and match-over overlay.

## Airburst
- **Definition:** An AI remote detonation: an armed own shell is detonated with an enemy ship or asteroid in blast radius, or after a miss.
- **Boundary:** Detonates even if the AI's own ship is in range, provided an enemy is.

## Stuck
- **Definition:** An AI that has not fired for `config.ai.stuckDelay` seconds.
- **Boundary:** Each personality relaxes its standards (aimed or unsolved shot, or hand-over to Artillery) to fire.

## Concealed position
- **Definition:** A surface point with no direct line to the target but a solvable lobbed shot.
- **Boundary:** Used by Artillery. Distinct from a vantage point, which needs a clear shot.

## Fast-forward
- **Definition:** Several sim steps per frame while no human is alive.
- **Boundary:** Same outcome as normal speed. A real-time timeout draws the round.

## Record
- **Definition:** A plain table in a pool, holding a body id and component sub-tables.
- **Boundary:** No methods, no metatables.

## Component
- **Definition:** A plain-data sub-table on a record plus a module of pure functions over it.
- **Boundary:** Never updates or draws itself. The owning pool system calls it.

## Ship
- **Definition:** A player-controlled craft with fuel, thruster, lander, turret, and weapon components. Triangular while flying, a dome in tank mode.
- **Boundary:** One hit point. One ship per player.

## Projectile
- **Definition:** A shell fired by releasing a charge — from the nose in flight, from the turret in tank mode. Affected by gravity.
- **Boundary:** At most one alive per player. No lifetime: it ends by leaving the soft boundary (no blast), by contact, or by remote detonation.
- **Unarmed** until its arm delay elapses — bounces off ships, cannot be remote-detonated. **Armed** afterwards — blasts on any ship contact.
- Blasts on world or asteroid contact whether armed or not.

## Asteroid
- **Definition:** A drifting convex rock that spawns off-screen, spins slowly, and exerts gravity.
- **Boundary:** Not a world. Cannot be landed on — ship contact is a crash. Above the size threshold it splits on any contact; below it, it is destroyed on any contact. Pushed by a blast. Spawning is capped at 1–2 alive; splits may exceed that.

## Split
- **Definition:** A large asteroid replaced by 3 fragments on contact with a world, asteroid, ship, or projectile.
- **Boundary:** Three radial cuts from the centroid, the first toward the impact, 120° apart. Fragments are pushed out along the contact normal. No grace period.

## Fragment
- **Definition:** One of the 3 convex asteroids produced by a split.
- **Boundary:** An ordinary asteroid. Inherits velocity plus an outward nudge from the parent centre. Destroyed on contact once below the size threshold.
- **Sibling immunity:** Fragments of one split ignore each other while they still touch; it ends the first step they are apart, after which they collide normally. Otherwise their overlapping spawn footprints would cascade.

## Landing
- **Definition:** Touching a world slowly enough. Any angle; the ship snaps upright along the surface normal and enters tank mode.
- **Boundary:** Only speed is checked. Too fast is a crash. Asteroids cannot be landed on.

## Tank mode
- **Definition:** Ship state after landing: fixed to the surface, refuelling, aiming a turret, able to charge and fire.
- **Boundary:** Left/right aim the turret; the body never rotates. Ends only on thrust (lift-off, straight up the surface normal) or destruction.

## Turret
- **Definition:** A tank's barrel. Its aim is relative to the surface normal, clamped to a configured limit either side.
- **Boundary:** Points straight up on every landing. Exists only in tank mode.

## Morph
- **Definition:** The cosmetic triangle ↔ dome animation on landing and lift-off.
- **Boundary:** Visual only. Controls switch the instant the ship lands or lifts off.

## Charge
- **Definition:** Holding fire to build launch speed, from a minimum on a tap to a maximum after 3 s. Release fires.
- **Boundary:** Works in flight and tank mode. Cannot start while the player's projectile is alive.

## Remote detonation
- **Definition:** A fire press that blasts the player's own armed projectile where it is.
- **Boundary:** Ignored while the projectile is unarmed. The press never also starts a charge.

## Blast
- **Definition:** A projectile's circular explosion. Kills every ship in its radius, shooter included, and pushes asteroids outward.
- **Boundary:** Does not damage worlds. Pushes asteroids; the projectile's contact also splits a large one. One per projectile.

## Crash
- **Definition:** Ship contact with a world that fails the landing speed check, or any ship contact with an asteroid. Destroys the ship.

## Lost to space
- **Definition:** A ship that drifts past the soft-boundary margin is destroyed.

## Hard boundary
- **Definition:** A circle beyond the anti-gravity zone where ships are killed and projectiles explode.
- **Boundary:** Asteroids pass through and despawn off-camera. Replaces soft boundary in v2+.

## Anti-gravity zone
- **Definition:** The region between the play area edge and hard boundary where negative gravity repels ships and projectiles.
- **Boundary:** Defined by boundary distance (50% play area width). Asteroids unaffected.

## Boundary anti-gravity field
- **Definition:** A baked static field applying repulsive force in the anti-gravity zone.
- **Boundary:** Only affects ships and projectiles, not asteroids. Computed once at level load.

## Soft boundary (deprecated)
- **Definition:** A margin beyond the screen edge where bodies may travel; ships there show an edge arrow.
- **Boundary:** Replaced by hard boundary. Ships past it are lost to space; projectiles and asteroids past it despawn. Removed in v2+.

## Round
- **Definition:** Play from spawn until at most one ship is alive, then a timed hold and a respawn. Both dying in the same step is a draw.
- **Boundary:** A draw scores no point and replays the round. Later rounds respawn ships at new random spawn points.

## Score card
- **Definition:** The overlay after a round showing the result (win or draw) and score pips.
- **Boundary:** Drawn over the live scene, not a separate state. Skipped on the round that ends the match.

## Match
- **Definition:** Best of 5 rounds — first to 3 round wins. One level layout for the whole match.
- **Boundary:** Draws never end it. Ends on a match-over overlay offering a rematch.

## Rematch
- **Definition:** A fresh match with the score zeroed. The match-over rematch (Enter / Space / pad A) rolls a new seed and so a new level.
- **Boundary:** Keeps the roster. The R dev key replays the same level and seed.

## Seed
- **Definition:** The number that determines a match's generated level and asteroid spawns.
- **Boundary:** Logged to the console at match start. Typed in setup (blank is random) or fixed with `seed=N`.

## Blob world
- **Definition:** A generated world shaped from radial noise around a centre, sometimes with a concave notch.
- **Boundary:** Always a simple polygon. One of two generated world kinds.

## Snake world
- **Definition:** A generated world built from a random turning polyline widened into a polygon, giving L, U, and S shapes.
- **Boundary:** Always a simple polygon. Vertices are lightly jittered.

## Spawn point
- **Definition:** A surface point with an outward normal where a ship starts in tank mode, drawn at random (distinct) from the cleared candidates every round.
- **Boundary:** Needs clear space above it. A point with no normal means a floating start.

## Contact
- **Definition:** A collision event emitted by the sim for one step, consumed by pool systems.
- **Boundary:** The sim reports contacts; it never decides outcomes (land, crash, bounce).

## Effect (reserved)
- **Definition:** A timed modifier attached to a record or body at runtime, e.g. shield or EMP.
- **Boundary:** Not built in v1. See `docs/ARCHITECTURE.md`.

## Pool transfer (reserved)
- **Definition:** Moving a record between pools while keeping its body, e.g. ship → wreck.
- **Boundary:** Not built in v1.

## Exhaust particle
- **Definition:** A short-lived visual body emitted from a thrusting ship's rear edge. Holds full alpha for 2 s, fades over 0.5 s.
- **Boundary:** Passive. Destroyed by world, asteroid, or hard boundary contact. Ignores ships and projectiles. Never affects play.

## Passive body
- **Definition:** A body that feels the static and boundary fields but neither exerts nor receives pairwise gravity.
- **Boundary:** Only exhaust particles in v2.

## Post mode
- **Definition:** Which post effects are active: off, glow, or glow + CRT. Chosen on the settings screen.
- **Boundary:** Saved in `settings.txt`. Affects rendering only, never the sim.

## Game rectangle
- **Definition:** The letterboxed virtual-resolution area of the window that the match draws into.
- **Boundary:** Post effects act on it alone. Letterbox bars outside it stay black.

## Settings screen
- **Definition:** Menu state with the SOUND, POST FX and FULLSCREEN rows, opened from the title and pause menus. Values persist in `settings.txt`.
- **Boundary:** Not the setup screen, which edits the roster and seed.

## Steam asset
- **Definition:** One image in the Steam store upload set, defined by a manifest entry.
- **Boundary:** Output only. Never read by the game.

## Manifest entry
- **Definition:** A table in `tools/steam_assets/manifest.lua` naming an asset, its pixel size, seed, roster, step, camera, flags and overlay.
- **Boundary:** Not a level or a roster. Flags omitted inherit the saved in-game look.

## Scout mode
- **Definition:** An interactive match that prints a manifest entry for the current frame.
- **Boundary:** Never writes images. Not part of normal play.
