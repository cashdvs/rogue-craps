# Boss dealers (shared Smiles rig)
Per-boss folders: pit_boss/ (reference), shuffle/, ashmouth/, straight_man/, collector/, bloodletter/. All six are toon-final on the shared tools/boss_toon.gd (materials + scenes) and tests/support/boss_dealer_test.gd (tests); rebuild any one with `GODOT=… BLENDER=… <boss>/src/rebuild_<boss>.sh` (SKIP_BLENDER=1 keeps the .glb). Each has a build script, scenes, check/render scripts and a README.
Shared tools: tools/check_prop_clip.py (per-shell prop clip test, 2 mm tolerance).
Run it with: `blender -b --factory-startup --python tools/check_prop_clip.py -- <file.glb>`

## Known issues
- **Shared Smiles clips pass the hand prop through the body in transit** (accepted by the AD on Oct 24, 2026, to match Smiles). Where it happens:
  - idle: the hand comes up to the face (about 0.33–0.6 s)
  - cheat and deal: the hand sweeps past the face and vest around 0.07–0.13 s, before the palm pop
  - mc_cheer: the arm goes overhead
  - The pass-through is in the shared clips, so it hits all six dealers the same way (Pit Boss plaque, Shuffle cards, Straight Man rod, Collector cloche, Bloodletter bowl/lancet; Ashmouth has no hand prop).
  - At rest and while palmed (prop scale 0), nothing clips. Fixing it means editing the shared clips, which affects every boss on this rig.
- Frames with the prop inside the body (PC / mobile):

  | Model | Frames |
  |---|---|
  | Smiles chip | 45 (PC) |
  | Pit Boss v2 plaque | 35 / 34 |
  | Shuffle cards | 23 / 23 |
  | Straight Man rod | 31 / 28 |
  | Collector cloche | 39 / 35 |
  | Bloodletter bowl + lancet | 30 / 25 |
  | Ashmouth (no hand prop) | 0 / 0 |

  The in-engine guard in each `tests/test_<boss>.gd` (coarse nearest-triangle, 30 mm band, all 7 clips) is capped at 160 frames per LOD.

- **Each dealer .glb carries its own copy of the Smiles skeleton and the 7 clips (by design).** All 12 files (6 dealers × PC/mobile) embed the rig and idle, taunt, grudging, cheat, deal, mc_idle, mc_cheer, baked by each `build_<boss>.py` from `smiles/src/build_smiles.py`. A shared AnimationLibrary was evaluated (QA, PR #166) and not adopted: Ashmouth forks the rig (extra `firebox_door` bone, its own taunt keys), each glb's RESET track comes from its own rest pose, and swapping libraries on the editable glb instances risks silent animation regressions for ~1 MB of savings. **Any edit to Smiles' rig or clips therefore needs all six dealers rebuilt** (repo root; then run their tests):
  ```
  export GODOT=/home/box/tools/godot/godot BLENDER=/home/box/tools/blender/blender-4.5.14-linux-x64/blender
  for b in pit_boss shuffle ashmouth straight_man collector bloodletter; do art/models/characters/bosses/$b/src/rebuild_$b.sh; done
  for b in pit_boss shuffle ashmouth straight_man collector bloodletter; do $GODOT --headless --path . --script res://tests/test_$b.gd; done
  ```
- **`.glb.import` files are ~490 KB each (expected).** `tools/write_boss_imports.py` writes a ~4 KB file; Godot's importer rewrites it on every `--import` with every default spelled out, chiefly 256 empty `slice_N/*` entries for each of the 7 clips (~14k lines). Trimming them does not stick (the next import or editor open re-expands them) and Smiles' imports are the same size, so they are left as Godot writes them.
- **Checker quirk:** in mc_cheer, check_prop_clip.py reports a stray "Icosphere" object at the origin (about 50 mm). It shows up for Smiles too, so it comes from the glTF import and not from the models. Ignore it, or filter it out when reading the results.
- **TODO (polish): Straight Man felt rap.** The brief's rod rapping the felt needs a dedicated clip, or a taunt variant on the shared rig. For now he only plays the shared Smiles clips.
- **TODO (polish, optional): Collector cloche beat.** He lifts the cloche to peek, or tips it at the player. Rule: the cloche never covers dice.
- **Palette rule (AD):** dealers use brass, bone and greys only, with no oxblood. Accent colours each get their own material slot.
