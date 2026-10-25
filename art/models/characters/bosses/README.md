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

- **Checker quirk:** in mc_cheer, check_prop_clip.py reports a stray "Icosphere" object at the origin (about 50 mm). It shows up for Smiles too, so it comes from the glTF import and not from the models. Ignore it, or filter it out when reading the results.
- **TODO (polish): Straight Man felt rap.** The brief's rod rapping the felt needs a dedicated clip, or a taunt variant on the shared rig. For now he only plays the shared Smiles clips.
- **TODO (polish, optional): Collector cloche beat.** He lifts the cloche to peek, or tips it at the player. Rule: the cloche never covers dice.
- **Palette rule (AD):** dealers use brass, bone and greys only, with no oxblood. Accent colours each get their own material slot.
