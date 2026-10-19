# Dice ids

One id per die and per shape. Code: `scripts/data/dice_ids.gd` (`DiceIds`). Test: `tests/test_dice_ids.gd`.
Owner: Systems Dev. Adding a die = add it here and in `DiceIds.ALL` in the same PR. A new die id must not match a face-mod id in `resources/mods/` (the test checks).

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
  `DiceIds.canonical()` also accepts a current art key and returns its die id (`ferryman_coin` → `ferryman`, `powder_keg_d6` → `powder_keg`), as well as the old aliases below.
- **Face key** (pre-carved/special face) = `<die_id>_<value>` in Arabic digits: `verdict_20`, `verdict_1`, `midnight_12`, `tithe_10`, `lantern_8`, `powder_keg_1`…`powder_keg_3`. Coin faces: `ferryman_heads`, `ferryman_tails`.
- **Audio cue ids:** a **die-specific** cue starts with the die id: `ferryman_heads_copy`, `caltrop_run`, `knucklebone_level`, `powder_keg_3`, `verdict_20_alt`. A **generic or flavour** cue for a die uses `trigger_flavor_<die_id>`: `trigger_flavor_lantern`, `trigger_flavor_tithe`, `trigger_flavor_verdict`, `trigger_flavor_powder_keg`. Cue *files* carry the `trigger_` prefix (`trigger_ferryman_heads_copy.wav`); the id inside the flavour key is always the canonical die id.
- **Asset-only keys** (`DiceIds.ASSET_ONLY_KEYS`): a few art keys have no die id (retired or showcase models). They are never die ids or aliases; see [Asset-only keys](#asset-only-keys-no-die-id).
- Names come from the final dice list in the design doc `nonstandard_dice.md` §10 (design doc, not in repo), in the spelling the most merged/in-flight code already uses.

## Shapes
| Shape id | Faces | Old aliases | Notes |
|---|---|---|---|
| `coin` | 2 (heads/tails) | `d2` (art, #102) | Ruled by Game Designer, 2026-10-19 |
| `d3` | 3 | — | Valid shape (#61 TableDie/DiceSim). **No die uses it today.** Powder Keg is `d6`. |
| `d4` | 4 | — | Caltrop body |
| `d6` | 6 | — | Bone + d6 specials + Powder Keg (printed 1-1-2-2-3-3) |
| `d8` `d10` `d12` `d20` | 8 / 10 / 12 / 20 | — | |
| `talus` | 4 (astragalus; values 1, 3, 4, 6) | — | Knucklebone body (#102 `knucklebone_talus`). Ruled by Game Designer, 2026-10-19. Not `d4` (Caltrop). The old Burn Line `knucklebone_d6` cube is a retired asset, not an alias (see below). |

## Dice
| Die id | Shape | Display name | Old aliases | Where used | Must rename |
|---|---|---|---|---|---|
| `bone` | d6 | Bone Die | `standard`, `standard_d6` (file), `d6` as a die id (#50 `d6.tres`) | main resources/dice/standard_d6.tres (no id field), #50 | Systems Dev (#50). Ruled by Game Designer, 2026-10-19 |
| `bellows` `blood_pact` `coven` `cracked` `extra` `last_breath` `mirror` `twin_flame` `wanderer` | d6 | <Name> Die | — | main resources/dice/special/*.tres, art `*_d6` | none |
| `caltrop` | d4 | Caltrop | `caltrop_d4` (asset key, fine) | #50, #102, audio | none |
| `lantern` | d8 | Lantern | — (face `lantern_8`, flavour `trigger_flavor_lantern` ok) | #50, #102, audio | none |
| `tithe` | d10 | Tithe | — (face `tithe_10`, flavour `trigger_flavor_tithe` ok) | #50, #102, audio | none |
| `midnight` | d12 | Midnight | face `midnight_xii` → `midnight_12` | #50, #102, audio | Sound Designer |
| `verdict` | d20 | Verdict | `verdict_20_alt` cue ok; faces `verdict_20`/`verdict_1` ok; flavour `trigger_flavor_verdict` ok | #50, #102, audio | none |
| `ferryman` | coin | Ferryman's Coin | `coin` (#50 `coin.tres` id, audio), `ferrymans_coin` (audio), `ferryman_d2` (#102), cues `coin_*` | #50, #61, #102, audio | Systems Dev, 3D Artist (`ferryman_d2` → `ferryman_coin`), Sound Designer. Ruled by Game Designer, 2026-10-19 |
| `powder_keg` | **d6** | Powder Keg | `keg`, `keg_3`, flavour `trigger_flavor_keg` (audio), `powder_keg_d3` (old asset key → alias) | #50, #102, audio | 3D Artist (#102 `powder_keg_d3` → `powder_keg_d6`), Sound Designer. Ruled by Game Designer, 2026-10-19 |
| `knucklebone` | talus | Knucklebone | `knucklebone_talus` (asset key, fine) | #50, #102, audio | none. Ruled by Game Designer, 2026-10-19. (`knucklebone_d6` is a retired asset with no die id, not an alias.) |

### Rename lists (owners)

**3D Artist (#102):**
- `ferryman_d2` → `ferryman_coin`
- `powder_keg_d3` → `powder_keg_d6`
- `knucklebone_talus` is already canonical. Do **not** rename the Burn Line `knucklebone_d6` spec in `art/models/dice/src/build_dice.py`; it is retired and keeps its key (see [Asset-only keys](#asset-only-keys-no-die-id)).

**Sound Designer:**
- die-specific cues / ids `coin_*` → `ferryman_*` (`ferryman_heads_copy`, `ferryman_tails_copy`, `ferryman_alone_heads`, …; keep faces `ferryman_heads` / `ferryman_tails`)
- `keg_3` → `powder_keg_3`; flavour key `keg` → `powder_keg` (`trigger_flavor_keg` → `trigger_flavor_powder_keg`)
- face `midnight_xii` → `midnight_12`
- map the canonical id `ferryman` in `ModTriggerSynth.ALIASES` (today it falls through to the generic cue)
- lantern, tithe and verdict flavour cues (`trigger_flavor_<die_id>`) already follow the rule: none

**Systems Dev (#50):** data, code and tests (line numbers are #50 head 7fe42e2):
- `resources/dice/shapes/coin.tres` `id = &"coin"` → `&"ferryman"` (rename the file to `ferryman.tres` and fix `resources/map/bonfire_run.tres:38`)
- `resources/dice/shapes/d6.tres` `id = &"d6"` → `&"bone"` (rename to `bone.tres`, fix `bonfire_run.tres:36`)
- plain-die marker `&"d6"` → `&"bone"` (better `DiceIds.DIE_BONE`) in `scripts/core/run/run_die.gd:17,19,22` and `scripts/core/run/run_progress.gd:89,103,133,139,144,146,320`; comments `&"coin"` → `&"ferryman"` at `run_progress.gd:73,128,305`; `scripts/map/run_screen.gd:279`
- **`run_progress.gd:344` `td.set("shape", d.shape)` → `td.set("shape", DiceIds.shape_of(d.shape))`.** `RunDie.shape` holds a *die* id but `TableDie.shape` wants a *shape* id; it only works today because `coin` is both. Without this, the Ferryman rolls as a d6 after the rename (and the batch-3 dice already get the wrong body).
- tests: `tests/support/shaped_table_child.gd:16`; `tests/test_die_shapes.gd` `:41,54,66,80,103,123` `coin` → `ferryman`, `:48,89` `d6` → `bone`; `:116` expects `&"d6"` for `powder_keg` once `:344` maps through `DiceIds`

**Godot Dev (#61):** shape `coin` is already correct; leave it. Shape `d3` stays valid with no die attached. Add `talus` (4 faces) to `TableDie.SHAPE_FACES` or read `DiceIds.SHAPES`; without it a Knucklebone plays as a d6.

Notes:
- `coin` stays a valid **shape** id (#61 TableDie/DiceSim/DieVisual use it correctly as a shape); it is only wrong as a **die** id.
- `d3` stays a valid **shape** id (#61); no die uses it today. Powder Keg's physical body is `d6`.
- Two-Face Coin (craps-era 0/7 coin, from the design doc `gamblers-descent.md`, not in repo) is retired; if it comes back it gets its own die id on the `coin` shape.
- Unbuilt oddballs from the design doc `nonstandard_dice.md` §7 (not in repo), if built: `devils_d7` shape `d7`, `sinner`, `fudge`.

## Asset-only keys (no die id)

Art keys on `main` that no gameplay die uses. `DiceIds.ASSET_ONLY_KEYS` lists them; `canonical()` and the other helpers return empty for them, and the test fails if one is ever reused as a die id or alias.

| Asset key | Where | Status |
|---|---|---|
| `knucklebone_d6` | parked Burn Line d6 spec in `art/models/dice/src/build_dice.py` (`--all` only; no `.glb` on `main`) | **Legacy, retired** (Systems Dev ruling, 2026-10-19). Keeps its key; not renamed, because `knucklebone_talus` is #102's different, real Knucklebone model. Was an alias of `knucklebone` in #107; removed. |
| `gilded_d6` | `art/models/dice/gilded_d6.glb` + `materials/gilded_*.tres` | Model of the **Gilded Face** face mod (`resources/mods/gilded.tres`, id `gilded`), not a die: no `resources/dice` entry and not in the special-dice list (see `art/models/dice/SPECIAL_DICE.md`, "Open questions"). **Deprecated** (Game Designer, Oct 19): retired as a die; kept only as material reference for the Gilded face look. Art Director decides any reuse. |
| `hellfire_d6` | `art/models/dice/hellfire_d6.glb` + `materials/hellfire_*.tres` | Same for the **Hellfire Face** face mod (`resources/mods/hellfire.tres`, id `hellfire`). **Deprecated**, same ruling. |

If Gilded or Hellfire ever become real dice, they can't take the die ids `gilded` / `hellfire`: those are face-mod ids, and die ids and face-mod ids share one namespace (`SfxManager.play_mod_trigger`). The test checks this.
