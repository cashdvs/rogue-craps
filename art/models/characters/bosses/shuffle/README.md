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

## v2 (AD option b: sculpted bob)
- The tower is replaced by a sculpted bob: crown dome, back mass, and side wings flaring past the jaw. Hair span is about 1.6× the 0.144 m face. The front curl stays.
- HEAD_DROP is back to 0 (5 cm built in) now that the tall shape is gone, which lifts the jaw clear of the shoulder line.
- Tris: PC 4,798, mobile 2,028. Gap min: PC 75.0 px, phone 29.4 px. Top-most vertex: phone 11 px, PC 141 px.
- Cards: fan unchanged at ±18°. ±23° gave 27 clip frames and ±28° gave 28, both over the cap of 25. Clip frames: 23 PC / 23 mobile.
- Renders: /workspace/dice/art/renders/boss_dealers/shuffle/v2/

## v3 (AD: wider bell)
- Flares pushed out and up above the shoulder line, and the crown dome widened. The front curl stays but is lowered so it no longer peaks the outline.
- Hair span 0.26 m vs 0.142 m face = 1.83×. Top-most vertex: phone 19 px, PC 162 px. Tris PC 4,798, mobile 2,028. Gaps PC 75.0 px, phone 29.4 px.
- Fan and clip unchanged (23 / 23 frames vs Smiles' 45).
- Renders: shuffle/v3/. Phone felt 30.4%, Forward+.

## Toon final (Oct 24, 2026), templated on the Pit Boss
- Materials: `src/make_shuffle.gd` on `../tools/boss_toon.gd` (brass, bone, greys one value step up, pewter; bone rim #E8DCC0 at 0.30; neutral ambient #3A3732 at 0.40; emission 0). Accents keep their own slots. External `.tres` in `materials/`, wired by `../tools/write_boss_imports.py`.
- Scenes: `scenes/shuffle(_mobile).tscn` with Model, HeadTrack (LookAtModifier3D on head, influence 0) and HeadAnchor (BoneAttachment3D on head).
- Rebuild: `GODOT=… BLENDER=… src/rebuild_shuffle.sh` (SKIP_BLENDER=1 keeps the current .glb).
- Test: `tests/test_shuffle.gd` (180 checks, all pass), including the two AD ambient conditions on every material.
- Tris PC / mobile 4,798 / 2,028. Brazier gap min PC / phone 75.0 / 29.4 px. Felt luma PC / phone 31.2 / 30.5% (Forward+). Prop clip (Blender, PC) 23 frames.
- Renders: `/workspace/dice/art/renders/boss_dealers/shuffle/final/game_pc.png`, `game_phone.png`.
