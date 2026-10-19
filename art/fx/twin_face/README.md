# Twin Face mask (stand-in)

`twin_face_mask_standin.png` — **stand-in only** for FX tests. 3D Artist ships
the real 1024×5×5 UV1 mask (`powder_keg_twin_mask.png`: R = hard glyph, G =
soft halo ≈1.3×, 0 inside silhouette) and updated faces atlas with the Powder
Keg follow-up after batch-3.

Final defaults (AD C+ Ember): `twin_unlit` `#403440`, `twin_strength` /
`twin_halo_strength` `1.6`, up ramp `smoothstep(0.80, 0.92, n.y)`.

See `scripts/fx/README.md` for the full uniform table and material hookup.
