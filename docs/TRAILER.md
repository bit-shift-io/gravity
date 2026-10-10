# Trailer tool

Dev-only tooling in `tools/trailer/` that renders the Steam trailer from the real game. The game never reads it. Terms (trailer manifest, shot) are in `docs/CONTEXT.md`. It shares its frame drawing with the Steam asset tool (`docs/STEAM_ASSETS.md`).

Run everything from the repo root with LÖVE. `ffmpeg` must be on your PATH. If `love` is not on your PATH on macOS, use `/Applications/love.app/Contents/MacOS/love`.

## Commands

### Render the clips

```sh
love . trailer=clips
love . trailer=clips shot=cold_open
```

Checks the manifest, then renders each shot to `trailer/clips/<name>.mp4` and exits. `shot=NAME` renders only that shot. `trailer/` is git-ignored.

Clips are 1920x1080, 60 fps, H.264 (`yuv420p`, so QuickTime plays them), with an AAC sound-effects track (48 kHz stereo) the length of the video. There is no music.

These print `trailer build failed: ...` and exit with code 1:

- `ffmpeg` is not on the PATH (`trailer build failed: ffmpeg not found`)
- the manifest is invalid. The message names the shot.
- `shot=NAME` names no shot
- a shot fails while rendering

Each clip is built from `<name>.video.mp4` (the video) and `<name>.wav` (the sound mix). They are muxed into `<name>.mp4.part`, which is renamed when the clip finishes, and the intermediate files are deleted. A failing shot leaves no partial MP4. Clips already finished in the same run are kept.

### Build the trailer

```sh
love . trailer=build
```

Checks the manifest, then renders its `sequence` into one `trailer/trailer.mp4` and exits. Same format as the clips (1920x1080, 60 fps, H.264 `yuv420p`, AAC 48 kHz stereo). The video and sound-effects tracks are the same length.

- Shots play in `sequence` order, back to back. Every frame streams into one ffmpeg process. Clips are not rendered and joined, so cuts land on exact frames with nothing dropped or doubled.
- Cuts are hard. A shot's `fadeIn` fades it up from black over its first seconds, and `fadeOut` fades it down to black over its last. A fade covers the shot's own frames and does not lengthen it. To fade through black between two shots, give the first a `fadeOut` and the second a `fadeIn`.
- The black is laid over the finished frame, after glow and CRT, so the CRT vignette does not change during a fade.
- One sound-effects track covers the whole trailer, with the music bed under it if the manifest has one (see The manifest). Each shot's cues (see Sound effects) start at that shot's start time. Fades do not change the sound.

It fails the same way as `trailer=clips`, and also when the manifest has no `sequence`. The build writes `trailer/trailer.video.mp4` and `trailer/trailer.wav`, muxes them into `trailer/trailer.mp4.part`, and renames that when the build finishes. The intermediate files are always deleted, and a failed build leaves no partial file (a `trailer.mp4` from an earlier build is kept).

## The draft trailer

`tools/trailer/manifest.lua` holds the first-draft trailer: 66 s in six beats, with the music bed (`res/msc/synthwave_the_mountain.mp3`, volume 0.3, 1 s fade-out). `love . trailer=build` renders it to `trailer/trailer.mp4` (about 100 s of wall time).

| Time | Beat | Items in `sequence` |
|---|---|---|
| 0–4 s | cold open, no text | `cold_open` (fades in from black) |
| 4–17 s | gravity | `gravity_launch`, `gravity_orbit` (caption `GRAVITY IS THE WEAPON`) |
| 17–35 s | arsenal | `arsenal_asteroids`, `arsenal_tanks`, `arsenal_airburst`, `arsenal_detonate` |
| 35–50 s | chaos | `chaos_blob` (caption `UP TO 6 PLAYERS / ONE SCREEN`), `chaos_snake`, `chaos_blob_2` |
| 50–57 s | couch pitch | `couch_kill`, `couch_card` (score card, caption `HUMANS OR AI / 1-6 LOCAL`, fades out) |
| 57–66 s | end card | `{ card = "logo", seconds = 9, sub = "WISHLIST ON STEAM" }`, held until the music ends |

The game font (Kernel Panic NBP) has no `·` or `–` glyph, so the captions use `/` and `-` instead.

**Re-scout after game changes.** Every shot replays a seeded all-AI match. Any change to the sim, the AI or level generation (even adding a pooled kind, see `docs/memory/new-pooled-kind-reshuffles-seeded-draws.md`) can change what those seeds play, so the shots no longer show what their names say. After such a change, render the clips and look at them again, and re-scout any that broke (Finding highlights, Scouting shots).

**Swap a shot.**

1. Find a candidate: `luajit tools/trailer/find_highlights.lua seeds=1-200 players=6 jobs=12` (or a smaller seed range, other `players=`, or `window=` for longer shots), or mark one in `love . trailer=scout seed=N`.
2. Paste the entry into `shots`, rename it, and set `hud`, `glow`, `crt` and a `camera`. The sim camera is usually zoomed out too far for a trailer, so most shots use a fixed or keyframed camera on the action.
3. Render it alone with `love . trailer=clips shot=NAME` and look at frames (for example `ffmpeg -i trailer/clips/NAME.mp4 -vf "select='not(mod(n\,30))',scale=640:-1,tile=4x4" -frames:v 1 -fps_mode vfr sheet.png`).
4. Put its name in `sequence` in place of the old one. Keep the beat's length: a shot runs `(to - from) / speed / 60` seconds, `to - from` must be a multiple of `speed`, and `length = 66` must still equal the sequence total, or the check fails. To lengthen a shot, move `from` or `to` and check the new steps stay busy and do not cross a round reset (the scene jumps there).

**Edit a caption.** Change its `text`, `from` or `to` (seconds from the shot's first frame) in that shot's `captions`. A caption must fit inside its shot. Captions sit at the bottom by default: check a frame that the text clears the action and, on `couch_card`, the score list.

**Edit the end card.** The `logo` card's `sub` is the call to action. Its `seconds` makes up the rest of the 66 s; `fadeOut = 1` matches the music fade.

## The manifest

`tools/trailer/manifest.lua` returns `{ shots = { ... }, sequence = { ... }, length = ..., music = { ... } }`. `manifest_check.lua` validates it before anything renders. Shot names must be unique.

`sequence` is the play order: a list of shot names and cards, such as `{ { card = "SIX SHIPS.", seconds = 2 }, "duel_opening", { card = "logo", seconds = 3 } }` (see Cards, captions and the end card). A shot may appear more than once. A name that matches no shot fails the check (`sequence item 2: no shot named 'x'`). `trailer=clips` ignores `sequence`.

| Top-level field | Meaning |
|---|---|
| `length` | the trailer's length in seconds. Must match the `sequence` total to within one frame, or the check fails (`length is 13s but the sequence runs 12s`). Required when there is `music`; optional otherwise. `trailer=clips` ignores it |
| `music` | optional music bed for `trailer=build`, see below. Ignored by `trailer=clips` |

**Music bed.** `music = { path, volume, fadeOut }` plays the mp3 at `path` (read in place, never copied or changed) from 0:00 under the sound effects. It is trimmed to `length`, so the video and audio end together.

- `path` is required. The file is checked at build time, not by the manifest check: a missing file prints `trailer build warning: music file not found, building with sound effects only: PATH` and the build goes on without music.
- `volume` (default `0.3`, about −10 dB) sets the music level under the effects. It must be greater than 0.
- `fadeOut` (default `1`) fades the music to silence over its last seconds, so the cut at `length` does not click. Set `0` for no fade. It must be 0 or more and no longer than `length`.
- The music is resampled to 48 kHz and mixed with `amix` (`normalize=0`, so neither input is halved). The mix ends with the effects track.

| Field | Meaning |
|---|---|
| `name` | output file name, without `.mp4` |
| `seed` | level seed |
| `roster` | 2–6 slots, each `{ color, binding = { kind = "ai", level = "easy" or "hard" } }` |
| `from`, `to` | step range shown (60 steps = 1 second); `to` must be greater than `from` |
| `speed` | whole steps per video frame (default 1). `to - from` must be a multiple of it |
| `camera` | optional: one fixed `{ x, y, zoom }`, or a list of keyframes (see Camera keyframes); omitted means the sim's own camera |
| `hud` | draw the HUD (default true) |
| `fadeIn`, `fadeOut` | `trailer=build` only: seconds to fade from black at the start, or to black at the end (default none, a hard cut). Each must be 0 or more, and together they must fit in the shot |
| `captions` | optional list of `{ text, from, to, anchor }` (see Cards, captions and the end card) |
| `glow`, `crt` | post effects; set them on every shot so output does not depend on the saved in-game look |

A shot always replays its match from step 0, one `Match.step` per step, so the same manifest always gives the same frames. Frame `k` (from 1) shows the match after step `from + k * speed`. A shot gives `(to - from) / speed` frames, or `(to - from) / speed / 60` seconds, and the last frame shows step `to`.

A camera (fixed or keyframed) changes only what is drawn. The sim keeps its own camera. CRT grain follows the match clock (`step / 60`), so it animates and is still deterministic.

## Cards, captions and the end card

All text uses the game font and is drawn in output pixels inside the scene canvas, so it passes through glow and CRT like the rest of the frame and camera moves never drag it. `trailer=build` only (`trailer=clips` ignores cards and draws captions on the shots).

**Cards** are sequence items that are tables instead of shot names:

- `{ card = "TEXT", seconds = 2 }` draws the text centred on black.
- `{ card = "logo", seconds = 4, sub = "WISHLIST ON STEAM" }` draws the logo end card: the Steam logo (GRAV//TY with the ORBITAL ARENA line, slashes in player 1 and 2 colours) above the optional `sub` line.
- `seconds` is greater than 0 (rounded to whole frames). `fadeIn` / `fadeOut` (seconds) work as on shots; a card that sets neither fades in and out over 0.5 s (less on a card under 1 s: half its length each). Set both to 0 for a hard cut.
- Cards have glow and CRT on, no HUD, and make no sound: the effects track stays silent under them.
- A bad card fails the check as `sequence item N: ...` (empty text, no length, fades longer than the card).

**Captions** go in a shot's `captions` list: `{ text, from, to, anchor }`, `from` and `to` in seconds from the shot's first frame.

- Each caption fades in over 0.3 s after `from` and out over 0.3 s before `to` (`Timeline.CAPTION_FADE`), and is invisible outside `from..to`. A caption shorter than 0.6 s never reaches full brightness.
- Every caption must lie within the shot (`0 <= from < to <= shot length`), have non-empty text, and use a known anchor, or the check fails (`name: caption 1 must lie within the shot (0 to 4s)`).
- `anchor` (default `bottom`) is one of `top`, `center`, `bottom`, `lowerLeft`. Text sits inside a safe area 8% in from the left and right and 16% in from the top and bottom, clear of the HUD's score blocks (corners, or the top row with five or six humans, which stay within 10% of the edge). Text wraps at 75% of the safe width.

## Finding highlights

`luajit tools/trailer/find_highlights.lua seeds=1-200 players=6` (plain LuaJIT, no `love`, run from the repo root) plays seeded all-AI matches and prints the best sliding windows per category as pasteable shot entries. It only suggests: paste an entry into `manifest.lua` yourself and rename it.

Arguments, all optional: `seeds=A-B` (default `1-50`), `players=2..6` (6), `window=` steps (240, 4 s), `count=` results per category (3), `seconds=` simulated per seed (60), `level=easy|hard` for every slot (hard), `jobs=` worker processes (8; `1` stays in-process). A 60 s match takes 2 to 5 s, so the seeds are split over `jobs` child processes.

Matches are built and stepped exactly as the renderer does (`Scene.build{seed, roster, step=0}` then `Scene.step`, never `Match.advance`), so a printed `seed`/`from`/`to` replays the same action. Each entry is preceded by a comment with its score, world kind (`blob`, `snake` or `mixed`), player count and the steps shown. Entries use speed 1, are named `<category>_<seed>_<from>` and pass the manifest check; a window covers steps `from + 1 .. to`.

One window is kept per seed and category (the best), then the top `count` across seeds are printed. Windows never span a round reset, because the scene jumps there.

Scoring is a weighted count of features per step (`tools/trailer/highlights.lua`, `Highlights.CATEGORIES`). Events are counted once each (deduped by identity); tank mode, landing and remote detonation have no events, so they come from ship state.

| Category | Beat | Score |
|---|---|---|
| `multikill` | cold open | 4 per ship death + 1 per shell blast |
| `gravity` | gravity | burning flying ships (ship-seconds) minus 3 per death: fast slinging, few deaths |
| `asteroids` | arsenal | 3 per asteroid split + 1 per asteroid destroyed |
| `tank` | arsenal | 3 per landing (flying ship turning tank, at most one per ship per second; spawning as a tank does not count) + tanks charging a shot (per 0.5 s) |
| `detonation` | arsenal | 4 per remote detonation (an armed shell fired off by its owner's fire press) + 0.5 per blast |
| `brawl` | chaos | 3 per death, 1 per blast, 1 per split, 0.5 per shot fired; also printed as `brawl-blob` and `brawl-snake` |
| `roundwin` | couch pitch | candidates end 210 steps (3.5 s) after a round locks, so the card has just come up; scored 4 per death + 1 per blast in the window |

World kind comes from the level: a blob has at least `levelGen.vertexCount.min` vertices, a snake has 6 to 10.

## Scouting shots

`love . trailer=scout seed=N` (or `shot=NAME`) opens the Steam scout (`docs/STEAM_ASSETS.md`: same pause, step, speed, pan and zoom keys) with three trailer keys:

- `i` marks in and `o` marks out. Each records the step and the current view (the scout's own pan/zoom, or the sim camera after `c`).
- `p` prints a pasteable shot entry: `seed`, `roster`, `from`, `to`, and a two-key `camera`. Out before in, or no marks yet, prints nothing and writes a message to stderr. Rename the placeholder `name = "scout"` on paste.
- `shot=NAME` loads that shot's seed and roster (`seed=N` still overrides the seed) and steps from 0, paused, to the moment the shot's first frame shows (`from + 1`). `r` restarts there.

The printed entry shows what scout showed: marking in at step `s` prints `from = s - 1` (never below 0), because frame 1 shows step `from + 1`. Marking out at step `e` prints `to = e`, the last frame. Entries use the default speed 1.

Camera: the in view becomes the key at `t = 0` and the out view the key at `t = 1`. If neither mark had its own view, no `camera` is printed and the shot follows the sim. If only one did, the other key is the sim camera as it was at that mark.

The Steam scout's own keys and output are unchanged. The shared scout takes optional hooks (extra help lines, key handler, `p` printer, start resolver) that the Steam scout leaves unset.

All world outlines render at 2x line thickness, as for the Steam assets.

## Camera keyframes

`camera` may be a list of keys `{ t, x, y, zoom, ease }` instead of one view:

```lua
camera = {
	{ t = 0, x = 0, y = 0, zoom = 0.5, ease = "inOut" },
	{ t = 1, x = 150, y = -80, zoom = 1.2 },
},
```

- `t` runs 0 to 1 over the shot and must increase from key to key. Frame `k` of `n` draws at `t = (k - 1) / (n - 1)`, so the first frame is exactly the first view and the last frame exactly the last. A one-frame shot uses `t = 0`.
- Before the first key's `t` the camera holds the first view, and after the last key's `t` it holds the last.
- `ease` is `linear`, `in` (slow start), `out` (slow end) or `inOut` (slow both ends, the default). It belongs to the segment that starts at its key, so the last key's `ease` is unused.
- `x` and `y` interpolate linearly. `zoom` interpolates in log space, so a push-in feels even. `zoom` must be above 0.
- A bad `t` (outside 0..1 or not increasing), unknown `ease` or `zoom` of 0 or less fails the manifest check, naming the shot and key.

## Sound effects

While a shot renders, `cues.lua` logs a sound cue for each match event, the same way `Audio.update` (`src/app/audio.lua`) does in game:

- `fire` plays the fire sound. `blast` and `crash` play the blast sound, once per frame even when a blast also kills a ship. `asteroidDeath` and `asteroidSplit` play the asteroid sound.
- Each event sounds once, on the first frame that shows it. Frame `k` plays at `(k - 1) / 60` seconds.
- Events raised before `from` never sound.
- With `speed` above 1, at most one of these sounds starts per frame, as in game fast-forward.
- The thruster loop plays over every frame where any live ship thrusts. Unlike in-game fast-forward, it also plays at `speed` above 1.

`sounds.lua` loads the files named in `Audio.FILES` and converts them to 48 kHz stereo. `mixer.lua` mixes them at the `Audio.VOLUME` gains and clips the result at full scale. File choice and volume come from `audio.lua`, so the mix always matches the game.
