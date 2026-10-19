# Feel layer (`scripts/fx/`)

Listeners that react to the table's gameplay signals (`table.events`) and play
sounds or VFX. Table / scoring code only **emits**; this folder owns how those
moments look and sound (AGENTS.md §5).

## TableAudio

`table_audio.gd` is a child of the 3D table. On ready it binds to
`table.events` + `table.sfx`. With no `events` node yet it is a no-op, so it
can land before Godot Dev's TableEvents PR without double-playing.

| `table.events` signal | Cue / call | Fallback (stand-in SfxManagers in tests) |
|---|---|---|
| `dice_thrown(flick_speed_px_s)` | `sfx.play_throw(speed)` | `dice_shake` if `play_throw` is missing |
| `die_impact(kind, speed_mps, material, die_id)` | `sfx.play_impact(...)` | silent (no stand-in) |
| `hot_hand(count)` | `hot_hand` (bone clacks; no fire) | `win_big` |
| `no_score` | `no_score` | `chip_refuse` |
| `table_cleared` | `table_cleared` (once per table) | `win_big` |

### One-owner rule

For these five moments, **only TableAudio** talks to `SfxManager`. Table code
emits `table.events.*` and never calls `sfx.play` / `play_throw` / `play_impact`
for throw, impact, hot_hand, no_score, or table_cleared. Whichever PR adds
`table.events` must delete those direct calls in the same change.

### Add a cue or fallback

1. Agree the signal + payload with Godot Dev (emitters stay in their code).
2. Add the signal name → handler in `HOOKS`, write the handler, and map a
   missing-cue fallback in `FALLBACK` if tests need one.
3. Cover it in `tests/test_fx_table_audio.gd`.

```bash
godot --headless --path . --script res://tests/test_fx_table_audio.gd
# or the full suite:
./run_tests.sh
```
