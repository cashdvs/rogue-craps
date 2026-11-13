# Powder Keg Twin Face mask — addendum (12 Nov 2026)

Addendum to the Nov 12 stave-numeral `SPEC.md`. This folder is the
hand-off for the Twin Face carve on the **3s**. The game repo was not
edited. Built against the atlas landed in
[PR #267](https://github.com/cashdvs/rogue-craps/pull/267) (`fd511d8`).

## Deliverables

| File | Role |
|---|---|
| `powder_keg_twin_mask.png` | Drop-in mask. 1024×1024 RGBA. md5 `5f64e0e9cb67bc58972d9e9a369de4c6`. |
| `twin_48_x4.png` | Required proof: landed atlas 3, plain vs unlit carve, 48 px die size, nearest ×4. |
| `twin_48.png` | Same pair at native 48 px. |
| `twin_cell2_debug.png` | Mid-band callout plus R / G visualiser. Not a hookup asset. |
| `make_twin_mask.py` | Regenerator. Read-only against the repo. |

## Format match

Matches `shaders/3d/twin_face_mask.gdshaderinc` and
`scripts/fx/README.md` (Twin Face section). Same contract as
`art/fx/twin_face/twin_face_mask_standin.png`, except G follows the
**written** spec (the stand-in currently leaves G high inside R; this
mask does not).

| Property | This mask | Source |
|---|---|---|
| Size / colour | 1024×1024 RGBA | include + stand-in |
| UV | UV1, same 5×5 face atlas as the keg overlay | include |
| Cell | Marks in **cell 2 only** (value 3, U 0.4–0.6, V 0.0–0.2). All other cells RGB 0. | README hookup step 1 |
| R | Hard-edged glyph, binary at bake (161 opaque texels) | include: “binary at bake” |
| G | Soft halo ~1.3× outside the outer silhouette; **0 inside R and inside pip / hollow holes** (137 texels > 8) | include: “~1.3×; 0 inside silhouette” |
| B | 0 | spare |
| A | 255 everywhere (same as the stand-in) | stand-in |
| Import | Non-colour / linear, lossless, mipmaps; `hint_default_black`, no `source_color` | include + stand-in `.import` |

Recommended `.import` params (do not write this into the game repo from
this pass). Copy next to the shipped png as
`art/fx/twin_face/powder_keg_twin_mask.png.import`, same as the stand-in:

```
compress/mode=0
mipmaps/generate=true
mipmaps/limit=-1
detect_3d/compress_to=0
; no process/hdr_as_srgb, no source_color
; vram_texture=false
```

## Motif and placement

Official Twin Face mark is a **pair-of-dice** (hollow rounded square
overlapping a pip die; `glyph_twin_face.svg` / the stand-in). The
stand-in’s ~34×34 pair will not fit around the new 3.

The shipped cue is an Ember `#E8622A` albedo tint on the lid-end atlas
cell 23 (both barrel ends share that cell). Cell 24, the hoops, is not
tinted. Emission is 0. The numeral gutter in cell 2 is clean: no stave
ticks. That gutter is 17 texels and cannot carry a readable mark. The
numeral 3 still sits in the hoop-free mid-stave of cell 2, atlas box
**(492, 87)–(532, 118)**.

This mask **splits** the pair: a hollow rounded square above the 3
(rest-pose top) and a solid rounded square with a 1-pip hole below it.
Each hard glyph is **10.55 atlas px** (~2.65 px at 48 px die size),
centred at atlas **(540.86, 102.40)** and **(483.14, 102.40)**. Halo
radius is 1.58 px (1.3×), then punched so R and G stay off:

- the cell 2 numeral gutter, kept clean (no stave ticks; the 17-texel gutter cannot carry a readable mark). The cue is an Ember `#E8622A` albedo tint on atlas cell 23 (both barrel ends). Cell 24 hoops stay untinted. Emission is 0
- every overlay-ink texel (stave seams and grooves), dilated 1 px
- the four hoop bands from `batch3_layout.json` (±1 px)

Verified: 0 R/G texels on overlay alpha, 0 in any hoop band, 0 G inside
R, 0 signal outside cell 2.

Orientation matches the numeral atlas: glyph “up” is atlas +X, which
reads upright in rest pose (barrel along world X). Opposite 3s share
this cell; the shader already darkens the down stave with
`gate = settled * smoothstep(up_lo=0.80, up_hi=0.92, world_n.y)`.

## Art (this pass)

- No occult symbols. Pair-of-dice is the established Twin Face identity.
- Brass / cream only in the proofs: hard inlay `#E8DCC0`, halo `#C9A24A`,
  body mustard `#C9A030`. No violet, cyan, or Danger red.
- **Proofs are unlit albedo only. No ember glow is composited.**
- The mask itself is data (R/G weights), not a coloured texture.

## Hookup (Godot Dev)

Already in repo on `main` and on PR #267: `toon_noir_twin.gdshader`,
`twin_face_mask.gdshaderinc`, `scripts/fx/twin_face_glow.gd`.

1. Ship this file as `res://art/fx/twin_face/powder_keg_twin_mask.png`
   (replace the stand-in on the keg body). Import non-colour + mipmaps.
2. Point `powder_keg_body` at `res://shaders/3d/toon_noir_twin.gdshader`.
   Keep ink outline `next_pass`. Keep `use_overlay` + the PR #267 face
   atlas. **Ink stays in albedo, not in the mask.**
3. Assign `twin_mask`. Runtime: `TwinFaceGlow.bind_material(body_mat)`.

`tools/capture_twin_mask.gd --final` still looks for
`/workspace/dice/art/source/twin_mark_mock/final/powder_keg_twin_mask.png`
and `powder_keg_faces.png`. This hand-off lives here instead; either
point the capture script at this folder or copy the mask (and the
landed `powder_keg_d6_faces.png`) when doing a final strip.

Optional later: paint the unlit cream/brass inlay into the faces
overlay as well, still clear of the 3, if the carve should remain
visible when glow strengths are 0. Not done in this pass.

## Glow vs this pass (please read)

Art rules for this carve were **no glow** and **no violet**. The
existing Twin Face FX (AD C+ Ember, 19 Oct 2026) still emits
`twin_glow` Ember `#E8622A` at `twin_strength` / `twin_halo_strength`
1.6 when settled and up, and uses `twin_unlit` `#403440` (renders
~`#692B16` under the Hearth lamp — slightly mauve).

The mask is glow-agnostic (weights only). Godot Dev can:

- keep the current Ember hookup, or
- set `twin_strength` and `twin_halo_strength` to **0** and point
  `twin_unlit` at a palette-safe dark brass **`#3A2E24`** (or cream)
  instead of `#403440`.

Do not bake Ember, violet, cyan, or red into the mask.

## Risks

- **48 px tightness.** The 17-texel gutter in cell 2 cannot carry a
  readable mark, so it stays clean (no stave ticks). The cue is an
  Ember `#E8622A` albedo tint on the lid-end atlas cell 23 (both barrel
  ends). Cell 24 hoops are untinted and emission is 0. A 34 px
  overlapping pair will not fit.
- **Halo is clipped** on the stave-seam sides, so G is a 1.3× fringe
  along the barrel and almost none toward the grooves. Expected.
- **Shared cell.** Both 3 staves sample this mask; lighting is gated
  by the up-normal, not by a second atlas cell.
- **Stand-in G mismatch.** Tests written against the stand-in’s
  G-inside-R behaviour should still pass (they sample presence / gate,
  not interior G), but a pixel-equal assert would fail.
- No Godot headless mesh proof in this folder: the 48 px pair is a
  flat rest-pose composite of the landed atlas + this mask. Parent
  path `/workspace/shots/keg_numerals_pr267/` was not on this mount;
  the atlas was taken from PR #267
  (`art/models/dice/textures/powder_keg_d6_faces.png` at `fd511d8`).
