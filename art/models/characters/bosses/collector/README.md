# The Collector (grey blockout v1)

**Head:** an animal head on the Smiles body, per the AD ruling, which overrides the BRIEF's "head TBD". I chose a **jackal**. The board draft shows a furry canid-like head with tall pointed ears. A jackal is a scavenger, which suits a confiscating hoarder, and its two tall ears read at 48 px.

**Rig:** the shared Smiles rig, unchanged (29 bones, every clip, armature `Smiles`), so the scene is a straight swap.
- **Swap slots:** Collector_Body, Collector_Head, Collector_Ears (on visor), Collector_Cloche (on chip).
- **Palette (AD):** brass, bone and greys only. The accent slots `col_brass`, `col_bone` and `col_glass` are kept separate.

**Form:** hunched (a back hump above the shoulders), long neck, head 5 cm forward and 6 cm low, a frock coat with tails, a scarf high on the neck and over the muzzle base, furred paw-hands with bone claws, and a brass cuff band. The prop is a small glass cloche (8 cm) with a brass rim and knob, held just below the fingertips.

**Metrics:**
- Tris: PC 4,622 / mobile 2,006.
- GAP MIN: PC 62.6 px / phone 25.8 px (mobile LOD 64.0 / 26.4).
- Top-most vertex: phone 12 px, PC 151 px.
- Prop clip (2 mm): PC 39 / mobile 35 frames, against Smiles' 45. That includes the mc_cheer Icosphere quirk.
- Felt: PC 32.0%, phone 30.7%. Forward+.

**Env vars:** HEAD_DROP, HEAD_FWD, EAR_TOP, CLOCHE_OFF.

**Rig gaps:** the cloche never covers dice (rule). An optional later beat, lifting the cloche to peek or tipping it at the player, would need a dedicated clip; see the bosses README TODO. The muzzle pokes out past the scarf, so the scarf only covers the mouth from the side.

**Renders:** collector/v1/ (front, side, sil, sil_x8, game_pc, game_phone).

## v1b
Reframed front/sil (frame=1.3, cy=0.16) so the cloche is in shot. In-game the cloche is visible in both game_pc and game_phone, held at the rail lip over the felt edge (see cloche_check_*.png, with vs hidden). Renders: art/renders/boss_dealers/collector/v1b/. Signed off.
