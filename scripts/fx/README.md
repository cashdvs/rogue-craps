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
| Stand-in mask (tests/captures) | `art/fx/twin_face/twin_face_mask_standin.png` |

`toon_noir.gdshader` is **not** edited (Godot Dev). The twin file is a full
variant that `#include`s the mask include. A future shared include extract from
toon_noir would be a Godot Dev change.

### Uniforms (3D Artist)

| Uniform | Type | Role |
|---|---|---|
| `twin_mask` | texture | UV1, same 1024 5×5 layout as the face atlas. **R** = hard glyph inlay, **G** = soft halo (~1.3×), B/A spare. No vertex colour. |
| `settled` | float 0..1 | Driven by `TwinFaceGlow` (fade-in ~0.12 s). 0 while rolling. |
| `twin_glow` | colour | Lit emission — **Palette.EMBER** `#E8622A`. Never violet/cyan. |
| `twin_strength` | float | Emission strength, default **1.35** (> 1.2). |
| `twin_unlit` | colour | Unlit inlay albedo `#6A2E1C`. |
| `up_threshold` | float | World-up smoothstep centre (default 0.92). |
| `up_soft` | float | Smoothstep width (default 0.08). |

Per-fragment: `world_n = normalize(MODEL * NORMAL)`; gate =
`settled * smoothstep(up_threshold - up_soft, up_threshold, world_n.y)`.

### Hookup for 3D Artist (Powder Keg body)

1. Put the real mask PNG on **UV1** (same layout as `powder_keg_d3_faces.png`;
   mark in the **3's cell**, index 2). Ship it next to the face atlas; replace
   the stand-in.
2. Point the keg **body** material slot (`powder_keg_body` → `powder_keg_d6`)
   at `res://shaders/3d/toon_noir_twin.gdshader` (keep the ink outline
   `next_pass`). Keep `use_overlay` + the face atlas as today; ink stays in the
   albedo overlay, not in the mask.
3. Assign `twin_mask` to your PNG. Defaults for glow/unlit/strength are fine.
4. At runtime, add `TwinFaceGlow`, `bind_material(body_mat)`, then
   `bind_events(table.events)` (or `bind_die(die_visual)` until TableEvents
   lands). Face normals come from the mesh (stave normals must face outward).

### Tests / capture

```bash
godot --headless --path . --script res://tests/test_fx_twin_face_mask.gd
# strip: rolling dark / 3-up landed lit / other-face dark
xvfb-run -a godot --path . --rendering-driver vulkan --script res://tools/capture_twin_mask.gd -- --out=/workspace/dice/captures/twin_mask/
```
