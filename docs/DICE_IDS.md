# Dice ids

One id per die and per shape. Code: `scripts/data/dice_ids.gd` (`DiceIds`). Test: `tests/test_dice_ids.gd`.
Owner: Systems Dev. Adding a die = add it here and in `DiceIds.ALL` in the same PR.

## Rulings (Game Designer, 2026-10-19)

1. **Ferryman's Coin:** die id `ferryman`, shape `coin`. Art renames `ferryman_d2` → `ferryman_coin`; `d2` is an old alias of shape `coin`.
2. **Knucklebone:** shape `talus` (4-sided astragalus). Deliberately not `d4` — that would collide with the Caltrop's body.
3. **Standard die:** die id `bone`.
4. **Powder Keg:** die id `powder_keg`, shape **`d6`** (not `d3`). The body is a d6 printed 1-1-2-2-3-3; "d3" stays only in the display name and text. Art key `powder_keg_d6` (old `powder_keg_d3` is an alias). Faces `powder_keg_1` … `powder_keg_3`; Twin Face on the 3s.
5. **Coin shape vs `d2`:** shape id is `coin`. `d2` remains only as an old alias (art #102).

## Rules
- **Shape id** = the physical body / face count: `coin d3 d4 d6 d8 d10 d12 d20 talus`. Physics, meshes and face layout use it (`TableDie.shape`).
- **Die id** = the named gameplay die: `caltrop`, `ferryman`, ... Run data, shop, scoring, audio and VFX use it (`DieShape.id`, `RunDie`, `SfxManager`).
- All ids are lowercase snake_case. A die id is never also a shape id (so no die called `coin` or `d6`).
- **Art asset key** = `<die_id>_<shape_id>`: `caltrop_d4`, `ferryman_coin`, `powder_keg_d6`, `mirror_d6` (main's d6 specials already follow this).
- **Face key** (pre-carved/special face) = `<die_id>_<value>` in Arabic digits: `verdict_20`, `verdict_1`, `midnight_12`, `tithe_10`, `lantern_8`, `powder_keg_1`…`powder_keg_3`. Coin faces: `ferryman_heads`, `ferryman_tails`.
- **Audio cue ids** for a die start with its die id: `ferryman_heads_copy`, `caltrop_run`, `knucklebone_level`.
- Names come from `design/nonstandard_dice.md` §10 (final dice list), in the spelling the most merged/in-flight code already uses.

## Shapes
| Shape id | Faces | Old aliases | Notes |
|---|---|---|---|
| `coin` | 2 (heads/tails) | `d2` (art, #102) | Ruled by Game Designer, 2026-10-19 |
| `d3` | 3 | — | Valid shape (#61 TableDie/DiceSim). **No die uses it today.** Powder Keg is `d6`. |
| `d4` | 4 | — | Caltrop body |
| `d6` | 6 | — | Bone + d6 specials + Powder Keg (printed 1-1-2-2-3-3) |
| `d8` `d10` `d12` `d20` | 8 / 10 / 12 / 20 | — | |
| `talus` | 4 (astragalus; values 1, 3, 4, 6) | `d6` (build_dice.py `knucklebone_d6`, Burn Line) | Ruled by Game Designer, 2026-10-19. Not `d4` (Caltrop). |

## Dice
| Die id | Shape | Display name | Old aliases | Where used | Must rename |
|---|---|---|---|---|---|
| `bone` | d6 | Bone Die | `standard`, `standard_d6` (file), `d6` as a die id (#50 `d6.tres`) | main resources/dice/standard_d6.tres (no id field), #50 | Systems Dev (#50). Ruled by Game Designer, 2026-10-19 |
| `bellows` `blood_pact` `coven` `cracked` `extra` `last_breath` `mirror` `twin_flame` `wanderer` | d6 | <Name> Die | — | main resources/dice/special/*.tres, art `*_d6` | none |
| `caltrop` | d4 | Caltrop | `caltrop_d4` (asset key, fine) | #50, #102, audio | none |
| `lantern` | d8 | Lantern | — (face `lantern_8` ok) | #50, #102, audio | none |
| `tithe` | d10 | Tithe | — | #50, #102, audio | none |
| `midnight` | d12 | Midnight | face `midnight_xii` → `midnight_12` | #50, #102, audio | Sound Designer |
| `verdict` | d20 | Verdict | `verdict_20_alt` cue ok; faces `verdict_20`/`verdict_1` ok | #50, #102, audio | none |
| `ferryman` | coin | Ferryman's Coin | `coin` (#50 `coin.tres` id, audio), `ferrymans_coin` (audio), `ferryman_d2` (#102), cues `coin_*` | #50, #61, #102, audio | Systems Dev, 3D Artist (`ferryman_d2` → `ferryman_coin`), Sound Designer. Ruled by Game Designer, 2026-10-19 |
| `powder_keg` | **d6** | Powder Keg | `keg`, `keg_3` (audio), `powder_keg_d3` (old asset key → alias) | #50, #102, audio | 3D Artist (#102 `powder_keg_d3` → `powder_keg_d6`), Sound Designer. Ruled by Game Designer, 2026-10-19 |
| `knucklebone` | talus | Knucklebone | `knucklebone_talus` asset key fine; `knucklebone_d6` (Burn Line model) | #50, #102, audio | 3D Artist (Burn Line `knucklebone_d6` → `knucklebone_talus`). Ruled by Game Designer, 2026-10-19 |

### Rename lists (owners)

**3D Artist (#102):**
- `ferryman_d2` → `ferryman_coin`
- `powder_keg_d3` → `powder_keg_d6`
- `knucklebone_d6` (Burn Line) → `knucklebone_talus`

**Sound Designer:**
- cues / ids `coin_*` → `ferryman_*` (keep `ferryman_heads` / `ferryman_tails`)
- `keg` / `keg_3` → `powder_keg` / `powder_keg_3`
- face `midnight_xii` → `midnight_12`

**Systems Dev (#50):**
- `coin.tres` die id → `ferryman`
- `d6.tres` / standard die id → `bone`

**Godot Dev (#61):** shape `coin` is already correct; leave it. Shape `d3` stays valid with no die attached.

Notes:
- `coin` stays a valid **shape** id (#61 TableDie/DiceSim/DieVisual use it correctly as a shape); it is only wrong as a **die** id.
- `d3` stays a valid **shape** id (#61); no die uses it today. Powder Keg's physical body is `d6`.
- Two-Face Coin (gamblers-descent.md, craps-era 0/7 coin) is retired; if it comes back it gets its own die id on the `coin` shape.
- Unbuilt oddballs from nonstandard_dice.md §7, if built: `devils_d7` shape `d7`, `sinner`, `fudge`.
