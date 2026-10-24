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
