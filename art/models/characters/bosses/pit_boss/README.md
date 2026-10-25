# The Pit Boss — final, reference boss dealer (Floor 1)

> v3 (2026-10-24): AD-approved blockout taken to final. Toon-noir materials, ink, HeadTrack/HeadAnchor and `tests/test_pit_boss.gd`. See **v3** at the end. The other five bosses copy this setup.

Bust plus the signature prop, built on the **shared Smiles rig**. `src/build_pit_boss.py` imports
`smiles/src/build_smiles.py` for the bones, the Part helper and every clip, so nothing about the rig is forked:
- 29 bones (24 deform + 5 glow)
- rigid skinning
- the same origin, scale and armature name (`Smiles`)
- clips idle / taunt / grudging / cheat / deal / mc_idle / mc_cheer

`scenes/pit_boss(_mobile).tscn` is a straight swap for `smiles(_mobile).tscn` at the dealer spot (-0.42, -0.47, -0.86), with idle on autoplay, HeadTrack (LookAtModifier3D) and HeadAnchor (BoneAttachment3D) on `head`, the same as Smiles (added in v3).

| Slot | Smiles equivalent | Bone |
|---|---|---|
| PitBoss_Body | Smiles_Body | – |
| PitBoss_Head | Smiles_Head | – |
| PitBoss_Cap (flat cap) | Smiles_Visor | visor |
| PitBoss_Plaque (brass flip-plaque) | Smiles_Chip | chip |

Design (BRIEF, The Pit Boss):
- wide block head with jowls
- no neck: the head geometry sits 5 cm low on its bone, and a trapezius shrug runs into the jaw
- barrel shoulders and waistcoat
- flat cap
- cigar
- plaque: ONE numeral per face ("4" front, "2" back) plus an oxblood bar

Grey values only; there is no palette, toon material or ink yet.

| Tris | PC | Mobile |
|---|---|---|
| Total | 6,816 | 2,802 |
| Budget | 7.7k | 3.4k |
| Body | 3,590 | 1,674 |
| Head | 2,378 | 756 |
| Cap | 692 | 216 |
| Plaque | 156 | 156 |

Rebuild (run from the repo root):
```
blender -b --factory-startup --python art/models/characters/bosses/pit_boss/src/build_pit_boss.py
godot --headless --path . --import
godot --headless --path . --script res://art/models/characters/bosses/pit_boss/src/check_pit_boss.gd   # bones/tris/brazier gap
xvfb-run -a godot --path . --rendering-driver vulkan --resolution 1200x1200 --script res://art/models/characters/bosses/pit_boss/src/render_pit_boss.gd -- view=front|side|sil clip=RESET out=...
xvfb-run -a godot --path . --rendering-driver vulkan --resolution 1920x1080 --script res://art/models/characters/bosses/pit_boss/src/render_pit_boss.gd -- view=game [phone=844x390] out=...
```

Brazier and goal-plaque clearance uses the tests/test_smiles.gd camera v3 framing and checks every dealer clip every 0.05 s. The minimum is 55.7 px on PC and 23.0 px on phone; the rule is ≥ 20 px. Smiles measures 55.4 / 21.2 px with the same script.

## v2 (AD silhouette pass)
- Brim widened past the head and tilted 7°, cigar pushed out to break the outline, a 0.304 m upper shoulder block (1.4× the 0.216 m head) with the jowls merged in and no neck notch.
- Tris: PC 7,176 (≤7.7k), mobile 2,922 (≤3.4k). Gap min: PC 55.7 px, phone 23.0 px (≥20). Felt: PC 32.6%, phone 30.5%.
- The plaque's size and clips are unchanged. It now hangs 3 cm forward and 8 cm below the chip bone so it sits clear of the index finger at rest.
- Prop clip check: `blender -b --factory-startup --python ../tools/check_prop_clip.py -- pit_boss.glb` (per-shell test, 2 mm tolerance). About 35 frames still clip. They come from the shared Smiles clips: the hand sweeps to the face/vest in cheat/deal before the palm pop, and in idle and mc_cheer. Smiles' own chip fails the same check on 45 frames. Clearing them needs edits to the shared clips.
- Renders: /workspace/dice/art/renders/boss_dealers/pit_boss/v2/

## v2b (AD: no oxblood)
- The plaque bar is now `pitboss_bone` (0.90) in its own slot. Geometry is unchanged. Prop clip: 35 / 35 frames. The mobile figure was 34 before, and the recolour can't have moved it, so treat the +1 as checker variance. Render: pit_boss/v2b/front.png.

## v3 final (reference dealer, AD approved the blockout)
- **Materials** (`materials/*.tres`, built by `src/make_pit_boss.gd -- materials`): one toon_noir ShaderMaterial per glTF slot, each with an ink hull `next_pass` (`outline.gdshader`, #0E1414, 0.0048, the same as Smiles). The thin 0.0018 ink is on black / ash / cigar. Eyes have no ink.
- **Palette:** brass #B08D3C, bone #E8DCC0, pewter #8A8D8F and greys only.
  - Every colour uniform is set explicitly: shadow, ambient, rim, spec and emission. This matters because the shader defaults are oxblood shadow/ambient and a teal rim.
  - `emission_energy` is 0 everywhere.
  - Accents (brass, bone) stay in their own slots.
- **Hooks:** HeadTrack (LookAtModifier3D on `head`; ±60° yaw, ±20° pitch, 0.25 s sine ease-out, influence 0 until Godot Dev targets it) and HeadAnchor (BoneAttachment3D on `head`), under `Model/Smiles/Skeleton3D`.
- **Rebuild:** `GODOT=… BLENDER=… art/models/characters/bosses/pit_boss/src/rebuild_pit_boss.sh` (Blender build → materials → `tools/write_boss_imports.py` (uids kept) → `--import` → scenes).
- **Test:** `tests/test_pit_boss.gd` checks 166 cases:
  - rig bones and parents against `test_smiles.gd`
  - clip lengths and loop wraps
  - tris
  - toon + ink + palette + no emission on every slot and surface (the palette rule self-checks: oxblood, cyan and violet must fail)
  - no lights or scripts
  - HeadTrack and HeadAnchor
  - brazier gap ≥20 px in both game cams
  - felt left clear (a depth-aware vertex-splat proxy over the render's felt sample grid, with a self-check)
  - plaque: brass/black/bone, chip bone only, "4"/"2" faces, palmed in cheat
  - slot swap: cap on visor only and plaque on chip only, and a cap override doesn't touch the head
  - a prop-clip regression guard
- **Metrics:**
  - Tris: PC 7,176, mobile 2,922.
  - Gap min (test sweep): PC 55.7 px, phone 23.1 px.
  - Felt: PC 32.4%, phone 30.2% (lit, Forward+).
  - Prop clip: Blender per-shell check 35 / 35. The coarse in-engine check reads 150 for both and is guarded at ≤160.
- **Renders:** `/workspace/dice/art/renders/boss_dealers/pit_boss/final/game_pc.png`, `game_phone.png`.

### Template for the other five bosses
1. `bosses/tools/boss_toon.gd` holds the palette constants, the `brass()/bone()/pewter()/cloth()/base()` param builders, `materials()` (toon + ink .tres) and `scene()` (Model + HeadTrack + HeadAnchor).
2. `bosses/tools/write_boss_imports.py <boss> <slots…>` writes the external-material `.glb.import` files and keeps the uids.
3. `tests/support/boss_dealer_checks.gd` covers counters, the palette and emission check, game cams, CPU skinning, the brazier gap, the felt proxy and prop-clip frames.
4. For a new boss, copy `make_pit_boss.gd`, `rebuild_pit_boss.sh` and `tests/test_pit_boss.gd`, then change the slot table, part names and swap bones.

## v3b dark-read fix (AD 2026-10-24, materials only, no board lights)
- **Shared, in `boss_toon.gd`, so every dealer inherits it:**
  - Bone rim `RIM_BONE` #E8DCC0, `RIM_STRENGTH` 0.30, `RIM_POWER` 2.0. The black slot keeps 0.45.
  - The rim lights only on the lit side (toon_noir `light()`), so `emission_energy` stays 0.
  - `GREY_STEP` 0.08 is added in `cloth()`.
  - Neutral room ambient changed from #141416 / 0.25 to `AMBIENT` #3A3732 at `AMBIENT_ENERGY` 0.40. This is the shader's shade-band ambient term, not emission. It did the most visible work: the rim alone barely shows, because the dealer sits outside most of the lamp's reach.
- **Pit Boss (one value step up):**

  | Slot | v1 | v3b |
  |---|---|---|
  | Vest | 0.30 | 0.38 |
  | Cap | 0.22 | 0.30 |
  | Black | 0.11 | 0.19 |
  | Skin | #B5AC9B | #C2B9A8 |
  | Cigar | #4E4A45 | #625D57 |
  | Ash | #8A8D8F | #9DA0A2 |

  The plaque's bone face (`pitboss_bone`) is lifted with shadow #787264 and mid_tint 0.80.
- **Gate:** on game_phone, the cap brim, cigar and shoulder line now read against the far wall.
  - Felt: PC 33.8%, phone 30.4%.
  - Renders: `/workspace/dice/art/renders/boss_dealers/pit_boss/final_v2/`
- **Test:** `test_pit_boss.gd` now also checks that each rim is bone and low (≤ 0.5). 175 checks.
