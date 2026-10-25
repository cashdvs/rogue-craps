# The Bloodletter — v1 grey blockout

Polite barber-surgeon on the shared Smiles rig (straight scene swap, armature "Smiles"). Build: `blender -b --factory-startup --python bloodletter/src/build_bloodletter.py`.

- **Swap slots:** Bloodletter_Body, Bloodletter_Head, Bloodletter_Specs (on visor), Bloodletter_Lancet (twin-spout bowl + silver lancet, on chip).
- **Form:** round bald dome head with grey side tufts, round brass spectacles, a very tall starched collar (double-sided funnel from shoulders to cheeks), apron bib with bone straps/brass buckles flaring to a wide hem, rolled shirt sleeves. Bowl (6 cm, pewter + brass rim, two spouts) held low and wide below his right hand, lancet (bone handle, silver blade) laid across the rim.
- **Silhouette:** round head on a collar stalk over a broad block — reads apart from the Straight Man's narrow flat-top column (see renders `sil_vs_straight_man*.png`).
- **Palette:** greys + brass + bone + silver/pewter only. No red, no blood imagery.
- **Env vars:** HEAD_DROP (0.02), BOWL_OFF ("0.0,-0.09,-0.12"), BOWL_R (0.06).
- **Metrics:** tris 4,184 PC / 1,922 mobile; gap 64.1 / 26.5 px (mobile 65.4 / 26.9); top-most vertex pc 156 px, phone 14 px; felt 31.8% PC / 31.4% phone; prop clip frames 30 PC / 25 mobile (Smiles 45).
- **Renders:** art/renders/boss_dealers/bloodletter/v1/ (front/side/sil framed frame=1.3 cy=0.16 to keep the bowl in shot). Forward+.
- **Rig gaps:** the bowl is small in the game view (sits at the rail lip); any lancet gesture needs a dedicated clip.

## Toon final (Oct 24, 2026), templated on the Pit Boss
- Materials: `src/make_bloodletter.gd` on `../tools/boss_toon.gd` (brass, bone, greys one value step up, pewter; bone rim #E8DCC0 at 0.30; neutral ambient #3A3732 at 0.40; emission 0). Accents keep their own slots. External `.tres` in `materials/`, wired by `../tools/write_boss_imports.py`.
- Scenes: `scenes/bloodletter(_mobile).tscn` with Model, HeadTrack (LookAtModifier3D on head, influence 0) and HeadAnchor (BoneAttachment3D on head).
- Rebuild: `GODOT=… BLENDER=… src/rebuild_bloodletter.sh` (SKIP_BLENDER=1 keeps the current .glb).
- Test: `tests/test_bloodletter.gd` (200 checks, all pass), including the two AD ambient conditions on every material.
- Tris PC / mobile 4,184 / 1,922. Brazier gap min PC / phone 64.2 / 26.5 px. Felt luma PC / phone 33.1 / 30.7% (Forward+). Prop clip (Blender, PC) 30 frames.
- Renders: `/workspace/dice/art/renders/boss_dealers/bloodletter/final/game_pc.png`, `game_phone.png`.
- Glass lenses (`bl_glass`) and silver lancet (`bl_silver`) keep their blocked greys. `bl_black` is unused on any surface and has no material.
- Phone read: head, ears and spectacles read against the far wall; the tall collar sits mostly below the rail line at phone zoom.
