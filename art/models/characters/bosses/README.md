# Boss dealers (shared Smiles rig)
Per-boss folders: pit_boss/, shuffle/ (and later ones). Each has a build script, scenes, check/render scripts and a README.
Shared tools: tools/check_prop_clip.py (per-shell prop clip test, 2 mm tolerance).
Run it with: `blender -b --factory-startup --python tools/check_prop_clip.py -- <file.glb>`

## Known issues
- **Shared Smiles clips pass the hand prop through the body in transit** (accepted by the AD on Oct 24, 2026, to match Smiles). Where it happens:
  - idle: the hand comes up to the face (about 0.33–0.6 s)
  - cheat and deal: the hand sweeps past the face and vest around 0.07–0.13 s, before the palm pop
  - mc_cheer: the arm goes overhead
  - At rest and while palmed (prop scale 0), nothing clips. Fixing it means editing the shared clips, which affects every boss on this rig.
- Frames with the prop inside the body (PC / mobile):

  | Model | Frames |
  |---|---|
  | Smiles chip | 45 (PC) |
  | Pit Boss v2 plaque | 35 / 34 |
  | Shuffle v1 cards | 25 / 23 |

- **Checker quirk:** in mc_cheer, check_prop_clip.py reports a stray "Icosphere" object at the origin (about 50 mm). It shows up for Smiles too, so it comes from the glTF import and not from the models. Ignore it, or filter it out when reading the results.
