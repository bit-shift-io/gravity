# GRAV//TY

Local vector-style space duel for 2–6 players (1–4 human, the rest AI) with polygon worlds and gravity. Built with LÖVE (11.5 and 12) and LuaJIT.

See `docs/ARCHITECTURE.md` for the architecture and `docs/CONTEXT.md` for the glossary.

## Steam assets

Store and library images are generated from the real renderer; `tools/steam_assets/manifest.lua` lists every asset. The tooling is dev-only.

- `love . steam=build` renders every manifest asset into `steam-assets/` (gitignored) and exits. A bad manifest entry aborts the run and names the entry.
- `love . steam=scout seed=N` plays a seeded match to pick moments for screenshots. It never writes files. Keys: `space` pause, `.` step, `1`-`4` speed, `wasd`/arrows pan, `-`/`=` zoom, `c` follow camera, `p` print the manifest entry, `h` hide help, `r` restart, `esc` quit.

The community icon must be converted to JPG outside the tool. Verify the required sizes in Steamworks before uploading.

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
