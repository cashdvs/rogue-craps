# Dice ids

One id per die and per shape. Code: `scripts/data/dice_ids.gd` (`DiceIds`). Test: `tests/test_dice_ids.gd`.
Owner: Systems Dev. Adding a die = add it here and in `DiceIds.ALL` in the same PR.

## Rules
- **Shape id** = the physical body / face count: `coin d3 d4 d6 d8 d10 d12 d20 talus`. Physics, meshes and face layout use it (`TableDie.shape`).
- **Die id** = the named gameplay die: `caltrop`, `ferryman`, ... Run data, shop, scoring, audio and VFX use it (`DieShape.id`, `RunDie`, `SfxManager`).
- All ids are lowercase snake_case. A die id is never also a shape id (so no die called `coin` or `d6`).
- **Art asset key** = `<die_id>_<shape_id>`: `caltrop_d4`, `ferryman_coin`, `mirror_d6` (main's d6 specials already follow this).
- **Face key** (pre-carved/special face) = `<die_id>_<value>` in Arabic digits: `verdict_20`, `verdict_1`, `midnight_12`, `tithe_10`, `lantern_8`, `powder_keg_3`. Coin faces: `ferryman_heads`, `ferryman_tails`.
- **Audio cue ids** for a die start with its die id: `ferryman_heads_copy`, `caltrop_run`, `knucklebone_level`.
- Names come from `design/nonstandard_dice.md` §10 (final dice list), in the spelling the most merged/in-flight code already uses.

## Shapes
| Shape id | Faces | Old aliases |
|---|---|---|
| `coin` | 2 (heads/tails) | `d2` (art, #102) |
| `d3` | 3 values (6-face barrel printed 1-1-2-2-3-3) | — |
| `d4` `d6` `d8` `d10` `d12` `d20` | 4 / 6 / 8 / 10 / 12 / 20 | — |
| `talus` | 4 (1, 3, 4, 6) | `d6` (build_dice.py `knucklebone_d6`, the Burn Line die) |

## Dice
| Die id | Shape | Display name | Old aliases | Where used | Must rename |
|---|---|---|---|---|---|
| `bone` | d6 | Bone Die | `standard_d6` (file), `d6` as a die id (#50 `d6.tres`) | main resources/dice/standard_d6.tres (no id field), #50 | Systems Dev (#50) |
| `bellows` `blood_pact` `coven` `cracked` `extra` `last_breath` `mirror` `twin_flame` `wanderer` | d6 | <Name> Die | — | main resources/dice/special/*.tres, art `*_d6` | none |
| `caltrop` | d4 | Caltrop | `caltrop_d4` (asset key, fine) | #50, #102, audio | none |
| `lantern` | d8 | Lantern | — (face `lantern_8` ok) | #50, #102, audio | none |
| `tithe` | d10 | Tithe | — | #50, #102, audio | none |
| `midnight` | d12 | Midnight | face `midnight_xii` → `midnight_12` | #50, #102, audio | Sound Designer |
| `verdict` | d20 | Verdict | `verdict_20_alt` cue ok; faces `verdict_20`/`verdict_1` ok | #50, #102, audio | none |
| `ferryman` | coin | Ferryman's Coin | `coin` (#50 `coin.tres` id, audio), `ferrymans_coin` (audio), `ferryman_d2` (#102), cues `coin_*` | #50, #61, #102, audio | Systems Dev, 3D Artist, Sound Designer |
| `powder_keg` | d3 | Powder Keg | `keg`, `keg_3` (audio), `powder_keg_d3` (asset key, fine) | #50, #102, audio | Sound Designer |
| `knucklebone` | talus | Knucklebone | `knucklebone_talus` asset key fine; `knucklebone_d6` (Burn Line model) | #50, #102, audio | 3D Artist (see note) |

Notes:
- `coin` stays a valid **shape** id (#61 TableDie/DiceSim/DieVisual use it correctly as a shape); it is only wrong as a **die** id.
- Two-Face Coin (gamblers-descent.md, craps-era 0/7 coin) is retired; if it comes back it gets its own die id on the `coin` shape.
- Unbuilt oddballs from nonstandard_dice.md §7, if built: `devils_d7` shape `d7`, `sinner`, `fudge`.
