# The Straight Man (grey blockout v1)

Built on the shared Smiles rig: 29 bones and every Smiles clip, with armature `Smiles`, so the scene is a straight swap for smiles.tscn.
- **Swap slots:** StraightMan_Body, StraightMan_Head, StraightMan_Hair (flat-top, on visor), StraightMan_Rod (on chip).
- **Look:** a tall, thin rectangle. Narrow straight jacket and trousers (radius ~0.11 m), square shoulder bar, long neck, a long narrow head and a flat-top block. Chalk pinstripes, an oxblood tie and pocket square. The tailor's rod is 30 cm, held as a strict 45° diagonal in the picture plane, with 3 oxblood tape bands.
- **Metrics:**
  - Tris: PC 3,316 / mobile 1,578.
  - GAP MIN: PC 66.1 px / phone 27.2 px (mobile LOD 67.3 / 27.7).
  - Top-most vertex: phone 9 px, PC 143 px.
  - Prop clip (bosses/tools/check_prop_clip.py, 2 mm): PC 32 / mobile 29 frames, against Smiles' 45. 23 of those are the mc_cheer "Icosphere" quirk. The rest are inherited from the clips: the cheat hand passing the face, and an idle pose dip.
  - Felt: PC 30.7%, phone 30.9%. Forward+.
- **Tuning env vars:** HEAD_DROP, FLAT_TOP, ROD_OFF, ROD_LEN, ROD_ANG, ROD_SHIFT. The rod length is capped by the clips: with a 40 cm rod, Smiles' raised-hand taunt pushes the tip out of the phone frame (-13 to -54 px).
- **Rig gap:** the brief wants the rod to rap the felt. That needs a dedicated rap clip (or a taunt variant). Today he only does the shared Smiles clips, with the rod rigid on chip.
- **Renders:** straight_man/v1/ (front, side, sil, sil_x8, game_pc, game_phone).

## v1b (AD rulings)
- **Rod seat:** ROD_OFF is now "0.012,-0.018,-0.01", so the rod crosses the front of the fingers right at the grip. Prop clip: PC 31 / mobile 28 frames, against Smiles' 45. Seating it any deeper, through the fist, gave 51–56 frames.
- **No oxblood:** the tie and rod bands are now `sm_brass` (0.70) and the pocket square is `sm_bone` (0.90). Each has its own material slot. Dealers use brass, bone and greys only.
- **Metrics:** tris 3,316 / 1,578. GAP MIN 66.1 / 27.2 px. Phone top 17 px. Phone felt 30.0%. Forward+.
- **Renders:** straight_man/v1b/ (front, game_phone).

## Toon final (Oct 24, 2026), templated on the Pit Boss
- Materials: `src/make_straight_man.gd` on `../tools/boss_toon.gd` (brass, bone, greys one value step up, pewter; bone rim #E8DCC0 at 0.30; neutral ambient #3A3732 at 0.40; emission 0). Accents keep their own slots. External `.tres` in `materials/`, wired by `../tools/write_boss_imports.py`.
- Scenes: `scenes/straight_man(_mobile).tscn` with Model, HeadTrack (LookAtModifier3D on head, influence 0) and HeadAnchor (BoneAttachment3D on head).
- Rebuild: `GODOT=… BLENDER=… src/rebuild_straight_man.sh` (SKIP_BLENDER=1 keeps the current .glb).
- Test: `tests/test_straight_man.gd` (186 checks, all pass), including the two AD ambient conditions on every material.
- Tris PC / mobile 3,316 / 1,578. Brazier gap min PC / phone 66.2 / 27.3 px. Felt luma PC / phone 31.7 / 30.9% (Forward+). Prop clip (Blender, PC) 31 frames.
- Renders: `/workspace/dice/art/renders/boss_dealers/straight_man/final/game_pc.png`, `game_phone.png`.
