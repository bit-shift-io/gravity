# Steam assets tool

Dev-only tooling in `tools/steam_assets/` that renders every image in the Steam store upload set from the real game. The game never reads it. Terms (Steam asset, manifest entry, scout mode) are in `docs/CONTEXT.md`.

Run everything from the repo root with LÖVE. If `love` is not on your PATH on macOS, use `/Applications/love.app/Contents/MacOS/love`.

## Commands

### Render the assets

```sh
love . steam=build
```

Checks the manifest, renders every entry, then writes `steam-assets/<name>.png` and exits. Everything renders before the first file is written, so a failing entry leaves no partial output. A manifest or render error prints `steam build failed: ...` and exits with code 1. `steam-assets/` is git-ignored.

### Scout frames

```sh
love . steam=scout seed=4242
love . steam=scout entry=screenshot_02
love . steam=scout entry=screenshot_02 seed=12
```

Opens an interactive match for picking a frame. It never writes files.

- `seed=N` runs seed N with a four-AI roster (two hard, two easy).
- `entry=NAME` runs a manifest entry's own seed and roster, so the frame matches what `steam=build` renders for it. Use this for entries with other rosters, such as the six-player screenshots.
- Both together: the entry's roster with your seed.

| Key | Action |
|---|---|
| Space | pause / resume |
| `.` | pause and advance one step |
| 1–4 | speed x1, x4, x16, x64 |
| r | restart from step 0 |
| WASD / arrows | pan the camera |
| `-` / `=` | zoom out / in |
| c | return to the sim's own camera |
| p | print a manifest entry for the current frame to the terminal |
| h | hide or show the help text |
| Esc | quit |

Scout steps exactly one `Match.step` per step, so a printed `step` reproduces the frame. Pan and zoom change only what scout draws, never the simulation.

## Changing an image

1. Scout with the entry's seed, or `entry=<name>`.
2. Run at x16 or x64, pause near a moment you like, then step with `.` to the exact frame.
3. Pan and zoom to frame it. Press `c` if you want the sim's own camera.
4. Press `p`. The terminal prints a manifest entry.
5. Copy `seed`, `step` and (if you want a fixed view) `camera` into the entry in `tools/steam_assets/manifest.lua`. The printed entry also has the full roster written out; keep the manifest's own `roster` unless you want the literal one.
6. Run `love . steam=build` and look at the PNG.

Many entries share seed 4242 and one step, so the capsules and library images show the same frame. Changing `step` on one entry changes only that entry. Change the step on all of them to move the shared frame.

## The manifest

`tools/steam_assets/manifest.lua` returns a list of entries. `manifest_check.lua` validates it before anything renders. Names must be unique.

| Field | Meaning |
|---|---|
| `name` | output file name, without `.png` |
| `width`, `height` | pixel size (positive integers) |
| `seed` | level seed |
| `step` | steps the match runs before the capture (60 = 1 second) |
| `roster` | slots, 2–6, each `{ color, binding = { kind = "ai", level = ... } }` |
| `camera` | optional `{ x, y, zoom }`; omitted means the sim's own camera |
| `hud` | draw the HUD (default true) |
| `glow`, `crt` | post effects; set on every non-logo entry so output does not depend on the saved in-game look |
| `overlay` | `"logo"` to draw the title over the scene |
| `logoAnchor` | `top`, `left`, `centre`, `right`, `bottom`, and the corner variants (`top-left`, ...) |
| `logoSize` | logo width as a fraction of the image width, above 0 and at most 1 |
| `logoOffsetX`, `logoOffsetY` | nudge the logo right / down, in output pixels |
| `transparent` | logo alone on an alpha-0 canvas (needs `overlay = "logo"`, max 1280x720) |
| `icon` | G// monogram on a rounded square (must be square) |
| `glyphScale` | monogram size fraction, icons only |

All world outlines render at 2x line thickness, whatever the saved in-game setting (`Scene.build`).

### Moving the map and the title

Both are positioned in output pixels, but the camera is in world units.

- **Move the map right by N px:** subtract `N / (uiScale * zoom)` from `camera.x`. Moving it down is the same on `camera.y`. `uiScale` is `min(width / 1280, height / 720)`.
- **Move the title:** use `logoOffsetX` / `logoOffsetY` in output pixels.
- **Zoom** pivots on the camera point, which sits at the image centre. Zooming in moves the red boundary further out of the left edge.

To keep two images of different shapes looking alike (as with capsule_header, capsule_small and capsule_main), match the visible world width: `zoom = width / (visibleWorldWidth * uiScale)` (capsule_header shows about 1620 world units), then keep the same camera `x`, `y`, `logoSize` and the same left margin as a share of the width.

## What each kind of entry renders

- **Screenshots and capsules:** stars, world, HUD (if on), the logo overlay (if set), then glow, then CRT.
- **Library hero:** the scene with no overlay. Steam places the library logo over it.
- **`logo`:** the title alone on a transparent canvas. No glow or CRT, because they fill the background.
- **Icons (`icon_*`):** the monogram on a near-black square, then glow and CRT, then the corners are cut to alpha 0 (radius 18% of the side, anti-aliased). The 32px client icon is the one most likely to need `crt = false`.

## Tests

`tests/unit/steam_manifest_test.lua` and `tests/unit/steam_icon_test.lua` cover the manifest, framing, flags, icons and the printed-entry format. They run in the normal unit tier (`sh test-unit.sh`). Rendering needs LÖVE and is checked by running `steam=build`.
