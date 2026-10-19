# Feel layer (`scripts/fx/`)

Listeners and materials that react to table gameplay signals without touching
scoring code (AGENTS.md §5). Glow on dice only — never flame
(`bonfire_map_events_juice.md` §3).

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
| `twin_glow` | colour | `#E8622A` Ember | Lit emission. Never violet/cyan. |
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
