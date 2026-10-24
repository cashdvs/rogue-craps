# Madame Shuffle - grey blockout v1
Shared Smiles rig (29 bones, all clips); straight scene swap (scenes/shuffle(_mobile).tscn). Slots: Shuffle_Body / Shuffle_Head / Shuffle_Hair (visor bone) / Shuffle_Cards (chip bone).
Build: `blender -b --factory-startup --python src/build_shuffle.py` (env knobs HAIR_TOP, HAIR_BACK, HEAD_DROP, CARD_OFF), then `godot --headless --path . --import`.
Checks: `src/check_shuffle.gd` (tris/gaps/top-most vertex), `../tools/check_prop_clip.py -- shuffle.glb`.

- Tris: PC 4,954 (≤7.7k), mobile 2,080 (≤3.4k). Gap min: PC 75.0 px, phone 29.4 px. Felt: PC 30.9%, phone 30.5%.
- Top-most vertex: phone y 3 px (inside the frame), PC 120 px. The head sits 8 cm low on its bones (5 + 3), and the tower tops out at about 0.75 m with a 3 cm back sweep.
  Sweeping it further back makes things worse: this camera looks down, so moving the tower back raises it on screen.
- High stand collar up to the jaw. Opera gloves are the lightest grey. Plain card backs, no pips or marks. Greys only.
- Card clip: 25 frames PC / 23 mobile in transit vs 45 for Smiles' chip; 0 at rest.
- Renders: /workspace/dice/art/renders/boss_dealers/shuffle/v1/
