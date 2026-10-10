# GRAV//TY

Steam store title: **Gravity: Orbital Arena**. The in-game logo stays GRAV//TY; the Steam art adds "ORBITAL ARENA" as a small line beneath it.

Local vector-style space duel for 2–6 players (1–6 human, the rest AI) with polygon worlds and gravity. Built with LÖVE (11.5 and 12) and LuaJIT.

See `docs/ARCHITECTURE.md` for the architecture and `docs/CONTEXT.md` for the glossary.

## Steam assets

Store and library images are generated from the real renderer; `tools/steam_assets/manifest.lua` lists every asset. The tooling is dev-only.

- `love . steam=build` renders every manifest asset into `steam-assets/` (gitignored) and exits. A bad manifest entry aborts the run and names the entry.
- `love . steam=scout seed=N` plays a seeded match to pick moments for screenshots. It never writes files. Keys: `space` pause, `.` step, `1`-`4` speed, `wasd`/arrows pan, `-`/`=` zoom, `c` follow camera, `p` print the manifest entry, `h` hide help, `r` restart, `esc` quit.
- `love . trailer=scout seed=N` (or `shot=NAME`) is the same scout with `i` mark in, `o` mark out, `p` print a pasteable trailer shot entry (see `docs/TRAILER.md`).

The community icon must be converted to JPG outside the tool. Verify the required sizes in Steamworks before uploading.

## Trailer

The Steam trailer is rendered from the real game too; `tools/trailer/manifest.lua` lists its shots and the `sequence` they play in. Dev-only, needs `ffmpeg` on the PATH. See `docs/TRAILER.md`.

- `love . trailer=clips` renders every shot to `trailer/clips/<name>.mp4` (gitignored; 1920x1080, 60 fps, H.264, with the game's sound effects as AAC) and exits. `shot=NAME` renders one shot. A bad manifest, a failing shot or a missing `ffmpeg` prints `trailer build failed: ...` and exits 1.
- `love . trailer=build` renders the manifest's `sequence` into one `trailer/trailer.mp4` with one continuous sound-effects track and the manifest's `music` bed under it (if any; a missing music file warns and the build goes on without it). Cuts are hard; a shot's `fadeIn` / `fadeOut` (seconds) fade it from or to black. `sequence` may also hold cards (`{ card = "TEXT", seconds = 2 }`, or `{ card = "logo", seconds = 4, sub = "..." }` for the end card), and a shot may carry timed `captions`; see `docs/TRAILER.md`.
- `luajit tools/trailer/find_highlights.lua seeds=1-200 players=6` (plain LuaJIT, no LÖVE) runs seeded AI matches and prints the busiest windows per category (multikill, gravity, asteroids, tank, detonation, brawl, roundwin) as pasteable shot entries with world kind and player count. It never writes the manifest; see `docs/TRAILER.md`.
- A shot's `camera` can be a list of keyframes `{ t, x, y, zoom, ease }` for a push-in or pan; see `docs/TRAILER.md`.

## Credits

### Fonts
- **Kernel Panic NBP** by Nate Halley (Nate547 / Total FontGeek), version 1.0, 2013.
  Licensed under [Creative Commons Attribution-ShareAlike 3.0](http://creativecommons.org/licenses/by-sa/3.0/) (CC BY-SA).
  Source: https://www.fontspace.com/kernel-panic-nbp-font-f15955
  Included unmodified at `res/fnt/KernelPanicNbp-LyG3.ttf`.

### Sound effects
- **Sci-Fi Sounds** by [Kenney](https://www.kenney.nl) (www.kenney.nl), version 1.0.
  Licensed under [Creative Commons Zero (CC0)](http://creativecommons.org/publicdomain/zero/1.0/).
  Included unmodified in `res/snd/`: `laserRetro_000.ogg` (firing), `explosionCrunch_000.ogg` (projectile blast),
  `lowFrequency_explosion_001.ogg` (asteroid destroyed), `thrusterFire_003.ogg` (thruster),
  `doorOpen_000.ogg` (menu forward), `doorClose_001.ogg` (menu back).
