# Feel layer (`scripts/fx/`)

Listeners and materials that react to the table's gameplay signals
(`table.events`) without touching scoring code (AGENTS.md §5). Table / scoring
code only **emits**; this folder owns how those moments look and sound. Glow on
dice only — never flame (`bonfire_map_events_juice.md` §3).

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
# also: test_fx_trigger_rows.gd, test_fx_trigger_safety.gd (same suite, split for size)
# capture (needs a display + PR #102's batch-3 models checked out): tools/capture_trigger_fx.gd, see its header
```
## Twin Face glow mask (`twin_face_glow.gd`)

Lights the Ember pair-of-dice glyph under the Powder Keg's **3** only when that
stave faces world up **and** the die has settled. Dark while rolling; the
opposite 3 stave that shares the atlas cell stays dark.

| Piece | Path |
|---|---|
| Shader include (mask math) | `shaders/3d/twin_face_mask.gdshaderinc` |
| Body shader (toon_noir variant) | `shaders/3d/toon_noir_twin.gdshader` |
| Driver script | `scripts/fx/twin_face_glow.gd` |
| Stand-in mask (tests) | `art/fx/twin_face/twin_face_mask_standin.png` |

`toon_noir.gdshader` is **not** edited (Godot Dev). Final AD values: C+ Ember
(Oct 19 2026). 3D Artist ships the real mask/atlas in their follow-up after #102.

### Uniforms (final)

| Uniform | Type | Default | Role |
|---|---|---|---|
| `twin_mask` | texture | — | UV1, 1024 5×5. **R** = hard glyph inlay, **G** = soft halo (~1.3×, 0 inside glyph), B/A spare. Import **non-colour** / linear + mipmaps (`hint_default_black`, no `source_color`). |
| `settled` | float 0..1 | `0.0` | Driven by `TwinFaceGlow` (fade-in ~0.12 s). 0 while rolling. |
| `twin_glow` | colour | `#E8622A` Ember | Lit emission. Never violet/cyan. On the keg material, 3D Artist may set **`#D9480F`** (pre-compensated for the Hearth lamp); leave the shader default as Ember. |
| `twin_strength` | float | **1.6** | Core emission: `glow * strength * R * gate`. |
| `twin_halo_strength` | float | **1.6** | Halo emission: `glow * halo_strength * G * gate` (albedo untouched). |
| `twin_unlit` | colour | `#403440` | Unlit inlay albedo (renders ~`#692B16` under the Hearth lamp). Final atlas also paints this. |
| `up_lo` | float | **0.80** | World-up ramp start. |
| `up_hi` | float | **0.92** | World-up ramp end. |

Per-fragment: `world_n = normalize(MODEL * NORMAL)`;  
`gate = settled * smoothstep(up_lo, up_hi, world_n.y)`.  
Lit core: albedo lerps to near-black (`0.02`) by `R * gate` so the lamp does not wash the emission.

### Hookup for 3D Artist (Powder Keg body)

1. Ship `powder_keg_twin_mask.png` + `powder_keg_faces.png` on **UV1** (mark in the **3's cell**, index 2). Replace the stand-in.
2. Point the keg **body** slot (`powder_keg_body` → `powder_keg_d6`) at `res://shaders/3d/toon_noir_twin.gdshader`. Keep ink outline `next_pass`. Keep `use_overlay` + face atlas; ink stays in albedo, not in the mask.
3. Assign `twin_mask` (non-colour import). Defaults above match AD-approved VALUES.md.
4. Runtime: `TwinFaceGlow` → `bind_material(body_mat)` → `bind_events(table.events)` (or `bind_die` until TableEvents). Stave normals outward.

### Tests / capture

```bash
godot --headless --path . --script res://tests/test_fx_twin_face_mask.gd
# strip (stand-in): rolling dark / landed Ember / other-face dark
xvfb-run -a godot --path . --rendering-driver vulkan --script res://tools/capture_twin_mask.gd -- --out=/workspace/dice/captures/twin_mask/
# final look (local 3D Artist assets, not in repo):
xvfb-run -a godot --path . --rendering-driver vulkan --script res://tools/capture_twin_mask.gd -- --out=/workspace/dice/captures/twin_mask/ --final
```

## DieGlow (`die_glow.gd`)

Glow-only dice juice for BonfireJuice: **no fire on dice** (Cash, Oct 19). It replaces the old
IGNITE / fire-trail scenes. Everything is the die's own emission + rim, one soft round halo card,
and a few tiny spark dots that **fall** sideways (never rise above the die).

| Call | Used by | Look |
|---|---|---|
| `apply(d, tier)` / `clear(d)` | score count-up | tier glow 0..3: amber → orange → gold → near-white (`TIER_COLORS`); pips stay ink |
| `hot_hand_pulse(d, fx_root, reduced)` | `BonfireJuice.hot_hand` | 0.25 s full-ember pulse + 6 spark dots (glow only; sound is TableAudio's `hot_hand`) |
| `ember_trail(d, fx_root, seconds)` | `fly_start` / `fly_stop` | short spark-dot trail (fades in ~0.3 s) behind dice flying back |
| `sparks(parent, at, amount, life)` | tier glow | small falling dots |

The lift / drop "lit" look is not DieGlow: it's `table._set_lit` (the `die_lit` shader). Never
violet or Soul cyan. Tests: `tests/test_fx_no_fire_on_dice.gd` (shapes, colours, peak spark/trail
height ≤ die top).

## Nerve "die turns" accent (VFX)
`scripts/fx/nerve_turn_fx.gd` (NerveTurnFx, one `add_child` in table_3d.gd) listens to
`table.events.die_nudged` and adds a quick warm white-gold (#FFE6A8, 1.5x peak) flick in the nudge
direction, one thin bevel sweep (procedural 64x8 `band` texture, Ember gold #FFE0A0 at 1.0 peak so it never clips on ivory, ~1.3x width) that slides along the camera-side top edge, kept off the pips (min depth >= `PIP_REACH`), and a short glint of motes **beside** the die (never over the face centre,
never rising), reusing the glint_streak / spark_dot_soft art. The face rotation is
TableDie.set_face's own tween. Under 0.3 s. Reduced motion / Instant: the sweep only. Leftover pieces are cleared on re-nudge of the same die, undo, `dice_thrown` and `table_cleared` (`clear(die)`); `hold` + `advance(dt)` step tweens for captures. Sound goes
through TableAudio (`nerve_nudge`, falling back to `chip_place`). Strip:
`tools/capture_nerve_turn.gd`. Tests: `tests/test_nerve_turn_fx.gd`.

## Lighting layers 4-5 (`lighting_layers_fx.gd`)
VFX half of `lighting_layers_spec.md` (lights and Environment, layers 1-3, are Godot Dev's). Hooked by one line in `Table3D._ready()`: `add_child(LightingLayersFx.new())`.
- `ContactShadows`: one unshaded black quad per die at y 0.002, following the die's XZ (+0.01 toward -x/+z), never its rotation. Diameter 1.6 x edge; alpha 0.55 Forward+ / 0.65 Compat-Mobile at rest, x (1 - h/0.25); scale x (1 + 0.6 h/0.25); hidden above 0.25 m, while held (Phase.HELD) and for `pot_dice`. Only reads the die's position: the die material is never touched. It hides the die's old built-in `Blob` node so the two don't stack.
- `LampDust`: GPUParticles3D 48 (Forward+) / CPUParticles3D 16 (else), cylinder r 0.45 m y 0.25-1.20 m, 2-4 mm (3-4 mobile) additive #FFE2B0 at 0.18 / 0.15, cone-masked to 38 deg, never drawn below y 0.08 (shader floor; the drift only rises). Off (not emitting, hidden) under reduced motion, polled from `table.is_reduced_motion()`.

## Ashmouth puffs (`ashmouth_puff_fx.gd`)
Boss-dealer FX for Ashmouth "Smiles": an ash puff out of the firebox door at 0.19 s and a soot puff out of the stovepipe at 1.2 s of the `taunt` clip. **Hookup:** `AshmouthPuffFx` is a child of the Ashmouth dealer root (added by the #166 rebuild). In `_ready` it finds the root's `Model` AnimationPlayer and the `FireboxDoor` / `PipeMouth` sockets (a missing socket just means no puff there) and watches the playhead every frame, so speed changes, seeks and replays fire each beat once.
- **Bursts:** a one-shot copy of the socket emitter, moved under the nearest ancestor's `fx_root` (else `current_scene`), in world space (`local_coords = false`), freed after its lifetime, so a cloud outlives the dealer and never follows him.
- **Ash:** #A8A49C, 14 dots (8 mobile), 0.45 s, spawned over the rail lip in front of the door (rail top from visible `Backboard`/`WallBack` meshes, +0.03 m; `@export ash_lift` 0.47 m fallback) so it reads in game_phone framing.
- **Soot:** #6E6A64, 10 dots (6 mobile), 0.55 s, up and back. The rise is capped so the cloud stays `soot_top_margin` (1.6%, ≥ 8 px on phone) inside the top of the active camera's frame; on game_phone it puffs in place (AD sign-off at 07b9f97).
- **Art rules:** greys only, no fire, no violet/cyan/red; soft 10-12 cm clouds of a procedural radial soft-dot texture that grow 1.5x; every burst under 0.6 s; must read at 48 px.
- **Renderer / motion:** GPUParticles3D on Forward+, CPUParticles3D otherwise. Reduced motion (~1/3 the dots) follows the game setting, read live from the nearest ancestor's `is_reduced_motion()` (Table3D) or `reduced_motion` (Bonfire3D, Dealer3D); the `@export reduced_motion` forces it on.
- Tests: `tests/test_fx_ashmouth_puffs.gd`. Capture: `tools/capture_ashmouth_puffs.gd` (Vulkan Forward+, `phone=844x390`; needs the local Ashmouth assets).
