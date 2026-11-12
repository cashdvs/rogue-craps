# Twin Face mask (stand-in)

`twin_face_mask_standin.png` — **stand-in only** for the older FX tests.
The shipped Powder Keg mask is `powder_keg_twin_mask.png` (1024×5×5 UV1:
R = hard glyph, G = soft halo ≈1.3×, 0 inside the glyph, marks in cell 2
only). `powder_keg_body.tres` points at it. A keg with no Twin carve does
not use this mask.

Final defaults (AD C+ Ember): `twin_unlit` `#403440`, `twin_strength` /
`twin_halo_strength` `1.6`, up ramp `smoothstep(0.80, 0.92, n.y)`.

See `scripts/fx/README.md` for the full uniform table and material hookup.
