# Ashmouth - grey blockout v1 (shared Smiles rig)
Build: `blender -b --factory-startup --python src/build_ashmouth.py` (env knob PIPE_TOP), then `godot --headless --path . --import`. Check: `src/check_ashmouth.gd`.
Slots: Ashmouth_Body, Ashmouth_Head, Ashmouth_Pipe (visor bone). The chip bone has no mesh: his prop is the board's Hearth brazier, unlit, and is not duplicated here.

- Tris: PC 5,858 (≤7.7k), mobile 2,426 (≤3.4k). Gap min: PC 55.7 px, phone 23.0 px. Felt: PC 32.3%, phone 30.7%.
- Top-most vertex: phone y 10 px, PC 134 px. The head is 5 cm low on its bones. The stovepipe goes straight up (no back sweep) and is short (6 cm).
- Prop clip: n/a (no hand prop).
- **Rig gap (BRIEF says Hero/Stoker rig).** The Smiles rig has no bones for:
  - the firebox door (taunt "flings his belly door open")
  - the stovepipe's smoke-ring puff
  - an ash puff from the brazier
  - Belly fire mood/dim: none, and the firebox is kept cold here anyway.

  Smiles' clips are a lean man's poses. On this round body the elbows and hands sit outside the belly, so idle and deal read fine. Taunt and grudging read as Smiles' gestures, not the Stoker's.
  Options:
  - add 1–2 extra bones (door hinge, pipe puff) to a forked rig
  - drive the door, ash puff and candle snuff as board/VFX events
- Renders: /workspace/dice/art/renders/boss_dealers/ashmouth/v1/

## v2 (AD rulings)
- **Rig fork: exactly one extra bone.** `firebox_door` (child of `spine`), a vertical hinge at the door's stage-left edge (Blender (0.075, -0.19, 0.12)). It is added in-process in build_ashmouth.py; build_smiles.py is untouched. 30 bones (25 deform). Armature is still `Smiles`, so the scene swap still works.
- **Taunt:** the door is shut at 0–0.12 s, flings open at 0.19 s (overshoot to 113°), sits at 105° through 1.0 s, and slams shut at 1.2 s. Every other clip keeps it shut.
- **VFX sockets** (Marker3D under BoneAttachment3D, in both scenes):
  - `Model/Smiles/Skeleton3D/PipeMouthAttach/PipeMouth` (bone visor), at the pipe mouth
  - `Model/Smiles/Skeleton3D/FireboxDoorAttach/FireboxDoor` (bone firebox_door), at the door face
- **Stovepipe:** 11 cm (brim 0.64 to top 0.75). Head and pipe dropped 4 cm more. Top-most vertex is 7 px on phone and 129 px on PC.
- **Metrics:** tris 5,870 PC / 2,438 mobile. GAP MIN 55.7 px PC / 23.0 px phone (grudging, inherited). No prop, so PROPCLIP was skipped.
- **Renders:** ashmouth/v2/ (sil, sil_x8, front, game_phone), Forward+, phone felt 30.3%.
