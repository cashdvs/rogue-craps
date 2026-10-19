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
| `table_started` (#91) | resets the TABLE CLEARED guard (`reset()`) | none |
| *(called by TriggerFx)* `mod_trigger(id, die, anchor, ctx) -> float` | `sfx.play_mod_trigger(id, ctx.tier ?? -1, ctx.intensity ?? 1.0, -1, flavor)` (flavor = `ctx.flavor` only if it is one of #98's: verdict, midnight, tithe, keg, lantern; else `&""`) once per trigger at its FX start; returns seconds until the audio hit (-1 = silent). Also hands the hook `sfx.crowd` (BonfireJuice's) and `sfx.trigger_speed_mode` (0/1/2). Stagger, voice cap, cluster, Bellows-once and crowd nudge are the hook's job. | -1 if `play_mod_trigger` is missing |

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

## TriggerFx (special-die / face-mod trigger FX)

`trigger_fx.gd` is a child of the 3D table. Spec: `trigger_fx_spec.md` v0.2, a **team doc outside this
repo** at `/workspace/dice/art/concept/special_dice/trigger_fx_spec.md` (not in the tree).
Files: `trigger_fx.gd` (grammar, cap, events), `trigger_fx_pool.gd` (the pooled bursts and their
cards), `trigger_fx_pieces.gd` (ring pulse, row pieces, sparks, icon), `trigger_fx_links.gd` (the
Mirror / Coin glint and the Gilded coin flight), `trigger_fx_defs.gd` (rows, beats, ids),
`trigger_shapes.gd`, `trigger_icon.gd`, `trigger_chip.gd`.
Entry point: `trigger_fx(&"mirror_copy", die, ctx := {}) -> float` (seconds to the key hit).

- **Grammar** (12 fps on twos): anticipation squash → key hit: a ring **pulse** tinted per row (grows
  and fades in 0.25 s), the row's own piece, sparks out and down, the icon pops → the row's beat →
  settle (the icon holds 0.5 s, then fades). Every row fits its tier budget (minor ≤ 5 f, major ≤ 6 f,
  signature ≤ 7 f). Motion goes on the die's `faces` node in world axes and is restored exactly when
  it finishes. If anything else moves `faces` mid-effect (the table's face remap), or on
  `dice_thrown` / `table_started`, or if the die is freed, the effect lets go **without** restoring. **Never tints the die body**: no die material is touched and every glow on a die
  is open in the middle. No fire, no lights, sparks never rise above the die.
- **Rows** (`trigger_fx_defs.gd`, `ROWS` / `BEATS`; `ALIASES` maps face-mod ids, Systems Dev's DiceIds
  die ids / face keys / old spellings (#107, mirrored with a TODO until this branch has main) and the
  legacy cue ids to rows; `FLAVOR_OF` gives verdict_20 / midnight / tithe / lantern / keg their flavour):
  | row | piece | beat | ring pulse | icon |
  |---|---|---|---|---|
  | `mirror_copy` | glass `glint_streak` arcs from the source die (sideways, never up), on arrival two small `spark_dot_soft` motes at the die's top-right corner (never over the face), glass `frame_square` flash | hop-flip (face turn) | pale glass #F2EEE2 | `icon_mirror_copy` |
  | `gilded_payout` | gold `radial_glow_soft` + `shine_bar` on the pip tick, then the brass coin (face/tilt/edge frames) hops to the Ember counter (`coin_landed`) | bob | gold | `icon_gilded_payout` |
  | `coin_heads_copy` (Ferryman heads; tithe / tithe_10 → `gilded_payout`) | toss, one flip, lands on the hit (f4), the glint from the highest die arrives as two motes as its face turns (f5); 0.50 s | spin-flip | pale glass | `icon_coin_heads_copy` |
  | `coin_tails_copy` | the same, glint from the lowest die (`ctx.source`) | spin-flip | pale glass | `icon_coin_tails_copy` |
  | `coin_alone_heads` | a short single flip, no glint (minor) | short spin-flip | pale glass | `icon_coin_alone_heads` |
  | `wild_face` (also lantern / lantern_8) | bone `spark_diamond` sparkle + ember glow on the hit (minor) | snap quarter-turn | bone | `icon_wild_face` |
  | `hellfire_face` (also midnight, midnight_12, verdict_20) | bone `needles_radial` out and back, Hellfire-red `frame_square` (`frame_hex` for flavour verdict / midnight), ember-core glow; `chip_x1_5` | jolt (1 f kick, no rattle) | bone + ember | `icon_hellfire_face` |
  Other rows use a generic pop (`icon_generic`). Icon discs are a flat 32 px at 720p (× viewport height / 720); the art's rim studs carry the tier.
- **Art** (Art Director's sheet, `/workspace/dice/art/vfx/trigger_fx/` README; only the files used are
  copied to `assets/vfx/trigger_fx/`, imported lossless with mipmaps): `icons/icon_<row>.png` (README
  option A: baked disc + studs + glyph), `shapes/<id>.png` (white soft shapes, tinted) and
  `shapes/<id>_fill.png` + `_outline.png` (the tinted fill is composited over the fixed oxblood outline
  into one cached card), plus fixed sprites (`coin_brass_*`, `chip_x1_5/x2/x3`). Adding a row's icon
  is dropping `icon_<row>.png` in; any missing file falls back to the code stand-in.
- **Driven by** `table.events.triggers_resolved` (#91: starts each burst at its `start_s`), else
  `mod_triggered` (5 or 7 args). Sound goes through `TableAudio.mod_trigger` and the flash is retimed
  to its return value.
- **Cap**: 4 visible bursts, the rest queued, starts 0.08 s apart, biggest tier first; pool of 8 (6 on
  mobile), pre-warmed. 2× halves the time; Instant shows static icons; reduced motion = glow + icon.

```bash
godot --headless --path . --script res://tests/test_fx_trigger.gd
# capture (needs a display + PR #102's batch-3 models checked out): tools/capture_trigger_fx.gd, see its header
```
