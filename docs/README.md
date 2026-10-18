# docs/

These are **mirrored copies** of the studio's working documents, kept in the repo so that outside
contributors (people and coding agents) can read them. The masters live on the Tiny Anvil studio
machine and are edited there by the design and art leads; this folder is refreshed from them by
maintainers.

| File | What it is | Mirrored from (studio box) | Mirrored on |
|---|---|---|---|
| `design/gamblers-descent.md` | Game design doc (v0.4). §12 is the proof-of-concept scope being built now. | `/workspace/dice/design/gamblers-descent.md` | 2026-10-18 |
| `art/style_guide.md` | Concept style guide: palette, colour rules (Soul cyan is reserved for Soul), UI style | `/workspace/dice/art/concept/style_guide.md` | 2026-10-18 |
| `art/poc_feel.md` | Feel spec for the POC table: timings, moments, chips, Soul meter, reduced motion | `/workspace/dice/art/concept/poc_feel.md` | 2026-10-18 |
| `art/poc_3d.md` | 3D POC spec: camera, table, materials, lighting, toon shading, dice physics | `/workspace/dice/art/concept/poc_3d.md` | 2026-10-18 |
| `art/dice_rarities.md` | Visual spec for dice rarity tiers (post-POC) | `/workspace/dice/art/concept/dice_rarities.md` | 2026-10-18 |
| `MODULES.md` | Module ownership map: claimable sub-sections of the game | (lives here) | |

Rules for contributors:

- **Don't edit the mirrored files in a feature PR.** If a doc looks wrong or out of date, open an
  issue (or ask in your PR). Maintainers fix the master and re-mirror.
- The design doc says "the doc's numbers are placeholders". The numbers the game actually uses live
  in `resources/tuning/poc_tuning.tres` (see `scripts/data/tuning_data.gd`).
- Names: the game was called *The Gambler's Descent* and is now **Dice of the Damned**. Some code,
  file names (`gamblers-descent.md`) and `project.godot` still use the old name.
- Concept images are not in the repo yet.
