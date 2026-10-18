# Boot splash: Godot integration notes

`scenes/studio_splash.tscn` is the project's main scene. It plays the Tiny Anvil Games
studio splash once per boot and then opens the scene named in `project.godot`:

```ini
[boot]
next_scene="res://scenes/table_3d.tscn"   ; the title/main scene, a one-line change
```

`SplashState` (autoload, `scripts/splash/splash_state.gd`) records that the splash already ran,
so changing back to the title/main scene never replays it.

## Swapping art (no code changes)
- Each layer is its own `Sprite2D` and loads its texture straight from this folder:
  `anvil.png`, `hammer.png`, `spark.png`, `spark_particle.png`,
  `wordmark_main_cream.png` (TINY ANVIL, with the wipe shader), and `wordmark_games_cream.png` (GAMES).
  Overwrite a PNG with the same name to swap it.
- Pivots, rest poses, every track, the camera nudge and shake, the burst particle settings, SFX cue
  times, skip rules and the reduced-motion variant are all read at runtime from
  **`splash_timings.json`** (the source of truth for `splash_motion.md`). If a texture's size or
  pivot changes, update `pivot_px` there. No script edits are needed.
- Supported track props: `position`, `position:x`, `position:y`, `scale` (a multiplier on the 0.5
  base scale), `rotation` (degrees), `modulate_a`, `modulate_rgb`, and `reveal` (the wipe). Easing uses
  Godot `TRANS_*` / `EASE_*` names.
- Imports: every layer is a standalone texture (not atlas-packed) with mipmaps, drawn with
  linear-mipmap filtering because the 2x art is shown at 0.5x.
- Extras that aren't in the spec, as exports on the root node: `impact_glow` (a warm glow under the strike, on)
  and `impact_flash` (a light full-screen flash, off).

## Sound cue slots (Sound Designer)
The splash never touches the audio buses or SfxManager. At each cue it emits
`cue(event: StringName)` and plays a stream if one exists:
1. one from the root node's `cue_streams` dictionary (Inspector), else
2. `res://audio/sfx/<event>.wav` if that file exists, else it stays silent.

| event | t (s) | reduced motion |
|---|---|---|
| `studio_splash` | 0.00 | 0.00 (one pre-mixed sting, if you'd rather ship a single file) |
| `splash_anvil_thud` | 0.40 | none |
| `splash_hammer_swish` | 0.52 | none |
| `splash_clang` | 0.60 (impact frame) | 0.45 at -6 dB |
| `splash_sizzle` | 0.61 | none |
| `splash_whoosh` | 0.86 | 0.58 at -6 dB |
| `splash_games_tick` | 1.15 | none |
| `splash_twinkle` | 1.55 | none |

The times come from the `sfx` list in `splash_timings.json`; add an entry there to get a new
`splash_<id>` cue. Players use the `SFX` bus if it exists, else `Master`. On skip, the splash's own
players fade to -60 dB over the 0.2 s skip fade.

## Skip and reduced motion
- Input is ignored for the first 0.15 s. After that, any key, mouse button, touch or joypad button
  fades everything to the charcoal background over 0.2 s and moves on. Mouse motion doesn't count.
- Reduced motion (2.3 s, no hammer, burst, camera or wipe) plays when the root node's `reduced_motion`
  export or `SplashState.reduced_motion` is true. A settings screen should set the latter before boot.

## Tests and captures
- `tests/test_studio_splash.gd`: loads the scene, advances to `boot/next_scene` after 2.5 s,
  fires the cues, never replays, ignores early input, skips on a key or click (not motion), and plays the reduced-motion variant.
- `tools/capture_splash.sh [out_dir]` renders mp4, gif and key frames (needs xvfb-run and ffmpeg).
