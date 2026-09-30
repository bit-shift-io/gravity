# High Priority

1. Asteroid splitting - asteroids over a certain volume should split into 3 on collision with the world, another asteroid, a ship or a projectile.
This should work by adding a line between the origin and the impact point, then from the origin rotate 120 degrees, generate another radial line outwards to the boundary. Then again another line 120 degrees from origin to the boundary. This should create 3 new shapes. EAch new shape is a new asteroid. Each asteroid will inherit the old velocity, but be nudged based on their offset from the old parents centre. This will create a "Shotgun blast" type of effect.
This should help the case where asteroids graze a world but currently just disapear.

# Medium Priority

1. A keyboard button such as "r" to reset the game to its initial state - this just helps development.

2. Rounds-and-matches - refer to .scratch/grav-ty-v1/10-rounds-and-match.md

3. Procedural levels - refer to .scratch/grav-ty-v1/11-procedural-levels.md

# Low Priority

1. Asteroid death effect - asteroids that are small and are killed by an impact need an animation similar to the player killed animation - fade out + expanding line.

2. Player thrust exhaust effects - when the player thrusts, we want to see some particles emitted from the exhaust point. Likely not from a single point but a small line segment at the back of the ship, maybe 50% of the length of the back line of the ship triangle.
These particles fly back and are affected by gravity. These should then fade out over a short period after maybe 2 seconds.

3. Morph animation - refer to .scratch/tank-mode-and-charged-shells/slices/03-morph-animation.md

4. Support for more than 2 players, if there are gamepads attached we can have number of gamepads + up to 2 players on keyboard.

5. Menus - .scratch/grav-ty-v1/12-menus-settings-gamepads.md
