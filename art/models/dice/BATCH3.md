# Special dice, batch 3: the non-d6 polyhedrals

Caltrop d4, Lantern d8, Tithe d10, Midnight d12, Verdict d20, Ferryman's Coin (coin), Powder Keg d3 (a d6 body printed
1-1-2-2-3-3), Knucklebone (talus). Asset keys follow `docs/DICE_IDS.md` (`<die_id>_<shape_id>`): `ferryman_coin`
(was `ferryman_d2`) and `powder_keg_d6` (was `powder_keg_d3`); the legacy `knucklebone_d6` key in `src/build_dice.py`
is a different, parked model and stays as it is.
Brief: `art/concept/special_dice/batch3_polyhedral_brief.md` in the team art folder (not in this repo). A rough first pass by the 3D Artist,
Oct 19 2026. These are visual assets only: no rules, tuning or gameplay code ship with them.
Proprietary, same terms as the rest of the repo (see `LICENSE`).

## Files
- `<die>.glb` (PC) and `<die>_mobile.glb` (mobile LOD) per die, each one mesh node, scale 1, at the origin.
- `materials/<slot>.tres`: toon-noir (`shaders/3d/toon_noir.gdshader`) with the ink hull (`die_ink_outline.tres`;
  `batch3_ink_thin.tres` for the Lantern's thin frame). The Verdict seal and the keg hoops have **no** hull: a
  push-from-centre hull floats over thin discs and bands as a black slab.
- `textures/<die>_faces.png`: 1024 px overlay atlas, 5 × 5 cells, **value v in cell v − 1**; cell 24 is bevel /
  trim, cell 23 the keg lids, cell 20 the Verdict seal.
- `batch3_faces.json`: per die the title, files, read mode, value → direction table (with the numeral's "up" on that
  face as a 3rd element, used to turn numerals upright in renders), tris, AABB, size, scale and the PC / mobile
  half-extents.
- `batch3_face_prints.json`: per die and value, the label painted on that face and an 8 × 8 fingerprint of its atlas
  cell (written by `write_batch3.py`); the test uses it to check each face shows its own mark.
- Source: `src/build_batch3.py` (Blender 4.5, geometry + UVs + `batch3_faces.json` + `src/batch3_layout.json`) and
  `src/write_batch3.py` (PIL, paints the atlases, writes materials and import mappings).
- Tests: `tests/test_batch3_dice.gd` (value_up-style table and per-mesh checks) and `tests/test_batch3_dice_shapes.gd`
  (extent cap, mobile hulls, coin, keg, face prints); both run in `./run_tests.sh`.

Rebuild:
```
blender -b --factory-startup --python art/models/dice/src/build_batch3.py
python3 art/models/dice/src/write_batch3.py
godot --headless --path . --import
godot --headless --path . --script res://tests/test_batch3_dice.gd
godot --headless --path . --script res://tests/test_batch3_dice_shapes.gd
```
Follow-up (not done yet): `build_batch3.py` (~850 lines) and `write_batch3.py` (~450 lines) should be split into
per-die modules with docstrings on the helpers.

Numerals and marks use Alfa Slab One (`fonts/`, SIL OFL 1.1, `fonts/OFL-alfaslabone.txt`), rasterised into the
textures as artwork; no font ships inside these assets.

## Conventions
Godot space: metres, +Y up, −Z forward. The origin is the **centre of mass** (solid centroid within 1.5 mm; tested),
so a body spins about the right point. Bodies are toon-noir, nothing is emissive (no fire on dice), and the reserved
colours (Soul cyan, Danger, Satanic violet, felt greens, Ember) stay off the bodies, both as authored and as lit by the
#FFB070 table lamp (`lamp_comp()` pre-divides the albedo by the lamp tint, so `.tres` hexes look bluer than the
swatches on purpose).

**Size:** each die's resting-pose AABB volume was matched to the 0.08 m d6 (cube root ≈ 0.08), the coin being a thin
Ø0.10 × 0.024 m disc. Then the **extent cap** (PM and Godot Dev, Oct 19): a non-d6 die's max per-axis half-extent from
the origin is **0.050 m** (d6s keep the 0.042 m box cap). Three dice were over and are scaled down uniformly in
`build_batch3.py` (`EXTENT_CAP`), PC and mobile by the same factor, computed from the measured PC extent: **Caltrop
×0.8491** (0.0589 → 0.0500 m), **Knucklebone ×0.8661** (0.0577 → 0.0500 m), **Lantern ×0.9427** (0.0530 → 0.0500 m).
The **Tithe** was 0.0507 m by our PC measure and 0.0509 m by a convex hull of its mobile mesh (Godot Dev's
`test_die_hull_extent`), so it is scaled **×0.9784** (`SCALE_FIXED`, 0.0498 / 0.0509, from the larger measure) to
0.0496 m PC / 0.0498 m mobile and hull. Face directions, the face table, the centroid centring, UVs and materials are
unchanged. The others are under the cap. `test_batch3_dice_shapes.gd` asserts ≤ 0.050 m per axis for every die on the
PC mesh, the mobile mesh and the hull of the mobile mesh.

**Mobile LODs and hulls:** Godot Dev builds the hull colliders from the *mobile* meshes, so each mobile LOD is centred
on its own centre of mass (within 0.5 mm; tested) and its extents, and its convex hull's, match the PC visual extents
within 0.5 mm on every half-axis (tested; worst: Caltrop 0.37 mm, Tithe 0.19, Midnight 0.17, Knucklebone 0.09,
Verdict 0.07, Coin 0.04, Lantern and Keg ~0). The bevelled dice's mobile chamfer depth and a uniform scale are searched
per die in `build_batch3.py` to land on the PC extents; the knucklebone LOD is fitted per half-axis and re-centred; the
coin's mobile LOD uses 20 segments and the keg's has the PC's four hoops so they match. The dice that are symmetric by
design (all but the knucklebone) keep every mirror symmetry of the PC hull in the mobile hull (tested); the Verdict's
wax seal is now 3-lobed and symmetric about the 20 face's mirror lines, 12-sided on both LODs.

| Die | PC tris | Mobile tris | AABB (m) | rest-volume cube root (m) | scale | max half-extent PC (m) | mobile (m) |
|---|---|---|---|---|---|---|---|
| Caltrop | 92 | 20 | 0.0829 × 0.0690 × 0.0725 | 0.0746 | ×0.8491 | 0.0500 | 0.0496 |
| Lantern | 152 | 92 | 0.1000 × 0.1000 × 0.1000 | 0.0743 | ×0.9427 | 0.0500 | 0.0500 |
| Tithe | 198 | 94 | 0.0991 × 0.0966 × 0.0950 | 0.0789 | ×0.9784 | 0.0496 | 0.0498 |
| Midnight | 276 | 116 | 0.0833 × 0.0724 × 0.0869 | 0.0806 | 1 | 0.0434 | 0.0436 |
| Verdict | 304 | 160 | 0.0788 × 0.0754 × 0.0884 | 0.0807 | 1 | 0.0442 | 0.0443 |
| Ferryman's Coin | 648 | 280 | 0.1000 × 0.0240 × 0.0985 | 0.0618 | 1 | 0.0500 | 0.0500 |
| Powder Keg | 416 | 320 | 0.0974 × 0.0694 × 0.0801 | 0.0815 | 1 | 0.0487 | 0.0487 |
| Knucklebone | 604 | 244 | 0.0967 × 0.0546 × 0.0739 | 0.0731 | ×0.8661 | 0.0500 | 0.0500 |

## Reading a result: value → local direction
The result is the value whose local direction is most nearly world-up (`basis * dir` with the largest `.y`). Every
die but the d4 reads its **top face**; the Caltrop d4 rests on a face and reads its **top vertex** (point-up, the pips
at each tip show that tip's value). The Powder Keg rolls on its long axis (local X) and shows the same value on
opposite staves (1, 2, 3, 1, 2, 3 round the barrel), so both directions of a value are listed. The coin is 1 = heads,
2 = tails. The Tithe d10 prints 1–10 (10 as "10", not "0"); Midnight prints I–XII (XII is the oxblood clock face);
the Verdict's 20 sits on its wax seal. Opposite faces sum to (top + 1) on the d8, d10, d12 and d20; the knucklebone
uses the classical astragalus values 1 / 3 / 4 / 6 (opposites sum to 7), and never rests on its knobbed ends (±X).

| Die | Read | Value → local direction (Godot space) |
|---|---|---|
| `caltrop_d4` (Caltrop) | top vertex | 1 → (0.0000, 1.0000, 0.0000); 2 → (0.0000, -0.3333, 0.9428); 3 → (-0.8165, -0.3333, -0.4714); 4 → (0.8165, -0.3333, -0.4714) |
| `lantern_d8` (Lantern) | top face | 1 → (0.5774, -0.5774, 0.5774); 2 → (-0.5774, -0.5774, 0.5774); 3 → (-0.5774, -0.5774, -0.5774); 4 → (0.5774, -0.5774, -0.5774); 5 → (-0.5774, 0.5774, 0.5774); 6 → (0.5774, 0.5774, 0.5774); 7 → (0.5774, 0.5774, -0.5774); 8 → (-0.5774, 0.5774, -0.5774) |
| `tithe_d10` (Tithe) | top face | 1 → (0.2292, -0.6707, 0.7054); 2 → (-0.6001, -0.6707, 0.4360); 3 → (-0.6001, -0.6707, -0.4360); 4 → (0.2292, -0.6707, -0.7054); 5 → (0.7417, -0.6707, 0.0000); 6 → (-0.7417, 0.6707, 0.0000); 7 → (-0.2292, 0.6707, 0.7054); 8 → (0.6001, 0.6707, 0.4360); 9 → (0.6001, 0.6707, -0.4360); 10 → (-0.2292, 0.6707, -0.7054) |
| `midnight_d12` (Midnight) | top face | 1 → (0.0000, -1.0000, 0.0000); 2 → (0.5257, -0.4472, 0.7236); 3 → (-0.5257, -0.4472, 0.7236); 4 → (-0.8507, -0.4472, -0.2764); 5 → (0.0000, -0.4472, -0.8944); 6 → (0.8507, -0.4472, -0.2764); 7 → (-0.8507, 0.4472, 0.2764); 8 → (0.0000, 0.4472, 0.8944); 9 → (0.8507, 0.4472, 0.2764); 10 → (0.5257, 0.4472, -0.7236); 11 → (-0.5257, 0.4472, -0.7236); 12 → (0.0000, 1.0000, 0.0000) |
| `verdict_d20` (Verdict) | top face | 1 → (-0.0000, -1.0000, 0.0000); 2 → (0.0000, -0.7454, 0.6667); 3 → (-0.5774, -0.7454, -0.3333); 4 → (0.5774, -0.7454, -0.3333); 5 → (0.9342, -0.3333, 0.1273); 6 → (0.5774, -0.3333, 0.7454); 7 → (-0.5774, -0.3333, 0.7454); 8 → (-0.9342, -0.3333, 0.1273); 9 → (-0.3568, -0.3333, -0.8727); 10 → (0.3568, -0.3333, -0.8727); 11 → (-0.3568, 0.3333, 0.8727); 12 → (0.3568, 0.3333, 0.8727); 13 → (0.9342, 0.3333, -0.1273); 14 → (0.5774, 0.3333, -0.7454); 15 → (-0.5774, 0.3333, -0.7454); 16 → (-0.9342, 0.3333, -0.1273); 17 → (-0.5774, 0.7454, 0.3333); 18 → (0.5774, 0.7454, 0.3333); 19 → (0.0000, 0.7454, -0.6667); 20 → (-0.0000, 1.0000, 0.0000) |
| `ferryman_coin` (Ferryman's Coin) | top face | heads → (0.0000, 1.0000, 0.0000); tails → (0.0000, -1.0000, 0.0000) |
| `powder_keg_d6` (Powder Keg) | top face | 1 → (0.0000, 1.0000, 0.0000); 1 → (0.0000, -1.0000, 0.0000); 2 → (0.0000, 0.5000, 0.8660); 2 → (0.0000, -0.5000, -0.8660); 3 → (0.0000, -0.5000, 0.8660); 3 → (0.0000, 0.5000, -0.8660) |
| `knucklebone_talus` (Knucklebone) | top face | 1 → (0.0000, 0.0000, 1.0000); 3 → (0.0000, 1.0000, 0.0000); 4 → (0.0000, -1.0000, 0.0000); 6 → (0.0000, 0.0000, -1.0000) |

The same table is hard-coded in `tests/test_batch3_dice.gd`; it and `tests/test_batch3_dice_shapes.gd` also check: a real face (or the d4's tip) lies on
every direction and is UV-mapped to that value's atlas cell, which carries a printed mark; turning any value's
direction to +Y reads that value back with no other direction within 10°; the d4 rests on the face opposite each tip;
each face shows its *own* mark (its atlas cell matches that value's fingerprint in `batch3_face_prints.json` and no
other value's, so swapping two faces' artwork fails) and is labelled with its own numeral; budgets (PC ≤ 650, mobile ≤
320 and below PC); slots, toon, ink hull, no emission, reserved colours, size, the extent cap, centring, and the mobile
LOD hull match and symmetry.

## Colliders (set up by Godot Dev, in code; not in the assets)
The art ships **no collider shapes**: the .glb files carry no physics. **Godot Dev owns the gameplay colliders** and
sets them up in code on `feat/nonstd-dice`. PM's ruling (Oct 19): d6s keep the 0.08 m box; **every non-d6 die,
the coin included, gets a convex hull built from its mobile mesh** (`<die>_mobile.glb`), so the mobile LODs are
centred and match the PC extents (above). Any edge-rest nudge is only a safety net. He reads the d4 from the vertex that
points up and the others from the face pointing up. The notes below are what the art side measured. The showcase
captures use a capture-only sandbox script kept outside the repo (`showcase_b3.gd` in the team's dice showcase tools)
with a convex hull per die (`Mesh.create_convex_shape(true, false)`) and the game's die tuning.

**Ferryman's Coin (Oct 19, "it doesn't flip and keeps landing the same side"):** the mesh was checked and is
symmetric; the cause was the showcase throw (a flat spin with the coin started heads-up), now a real flip.
- Collider: a **convex hull of `ferryman_coin_mobile.glb`, about 80 points** (80 today), mirror-symmetric heads/tails
  and following the barrelled edge out to r 0.050 m; heads = +Y, tails = −Y, centred at the origin.
- Mesh facts (tested in `test_batch3_dice_shapes.gd`): the AABB and the solid centre of mass are on the origin; the
  heads and tails faces sit at y = ±0.0120 m (thickness 0.0240 m); every vertex has a mirror twin at (x, −y, z)
  (542/542 PC, 182/182 mobile), so relief, rim and edge are identical on both sides (the skull and the moth are texture
  only); the convex hull is mirror-symmetric heads/tails (126/126 PC points, 80/80 mobile) and in X and Z.
- Profile per side (PC): the field is a flat disc r ≤ 0.0380 m sunk 1.1 mm below the rim; a 45° inner bevel,
  1.1 × 1.1 mm (r 0.0380 → 0.0391); a flat raised rim 7.4 mm wide (r 0.0391 → 0.0465) at y = ±0.0120; an outer
  bevel 0.58 mm radial × 1.6 mm (to r 0.0471 at y = ±0.0104); then a barrelled edge, an arc of radius 0.020 m to the
  0.0500 m equator, reeded (alternate vertices 0.8 mm in) on the three edge rings. Mobile drops the inner bevel ring
  (the field ramps straight up to the rim) and has 20 segments instead of 36 (even, so the reeding is symmetric).
- The barrelled edge is new (Oct 19): with the original flat 21 mm edge band the coin stood on its edge in 2/40 hull
  throws; with the arc (radius < the coin radius, so the equator is a ridge) it was 0/40.
- Art-side sandbox check (real flip: random start side, 36–42 rad/s end over end plus 16–20 rad/s about vertical): a
  hull of the mesh gave heads 20 / tails 20 and 0 edge landings in 40 throws; a plain cylinder (r 0.05, h 0.024) gave
  37 / 23 and 4/60 on the edge, which is why the coin is hulled.

**Powder Keg (die id `powder_keg`, shape `d6`):** a hexagonal barrel, 6 staves printed 1, 2, 3, 1, 2, 3 (each value on
two opposite staves, tested), read by the stave pointing up. It is hulled from its barrel mesh like the others; the
hull has 6 flat staves (tested), it isn't 3-valued. The lid ends are domed. Every hex ring's corners sit farther from the centre than the ring before it,
out to a small (≈4 mm) lid at the 0.049 m half-length, so a pose on the dome rolls back onto a stave. With flat lids it
stood on an end in 1 of 10 random throws (0/12 with the showcase's barrel-roll throw); with the dome it was 0/40 random
throws and 1/20 barrel-roll throws (plus one throw cocked against the back bumper). A flat chamfer and a spherical cap were tried first and made it worse
(their corners got closer to the centre toward the tip and left stable tilted rests). The hull of the mobile barrel keeps this
(same extents as the PC mesh); a capsule or cylinder would not (a cylinder's flat ends are stable).

**Caltrop d4:** always rests on a face and reads point-up: 12/12 sandbox throws with the top vertex exactly up (dot
1.000).

## Showcase
The team captures folder, `dice_showcase/batch3/` (not in the repo; batch-2 format, Hearth board): `lineup_hero_34.png`,
`lineup_top.png`, `dice_48px_strip.png` (+ `_x4`, the Bone d6 first for scale), `pile_48px_native.png` / `pile_48px_x4.png`
(the 8 mixed with three plain Bone d6s), `turn_<die>.png` (one tile per value), `roll_all.mp4` and `roll_<die>.mp4`
(every rendered frame captured at a fixed 60 fps; the coin's is a close-up of the flip, spin and wobble to flat), and
`showcase_log.txt` (settle times, up values, the throw batches).
