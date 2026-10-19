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
