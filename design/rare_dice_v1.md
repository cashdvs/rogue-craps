# Rare dice v1 (Oct 25, 2026)
Status: **SPEC, approved scope** (Cash approved rare dice in the shop via PM; Julian's F2). Docs/sims only: no game code or game data changed. Sim: `sim/rare_dice_run.py` (results `sim/rare_dice_results.txt`). Strings: `sim/build_strings_v1.py` → `design/strings_v1.md` (394 rows, `check_strings.py` 0 problems).

## 1. Idea in one line
A rare die is a **plain d6 body that comes with one or two existing face mods already carved** (the same `preset_mods` mechanism Lantern, Tithe, Midnight, Verdict and Powder Keg already use). No new scoring hook, no new shape, no new mod. The only new system is a rarity field + shop offer roll (1 PR).

## 2. The dice (Systems Dev checklist)
All four: `DieShape` resources in `game/resources/dice/shapes/`, **faces `[1, 2, 3, 4, 5, 6]`** (plain d6, weights equal), `enabled = true`, `rarity = &"rare"`, `preset_mods` as below. Each **takes a bag slot** (counts toward `max_dice = 6`); with the bag full, buying one is a swap (sell a die at 50%, as today). Sell value = half the price paid, rounded down.

| Die id | Name | preset_mods (face value → mod) | Exact rule | Base price (F1) | F2 (+25%) | F3 (+50%) | Body / visual |
|---|---|---|---|---|---|---|---|
| `pyre` | Pyre Die | 6 → `hellfire`, 5 → `ember_pip` | Showing 6: pot gets x1.5 (Hellfire). Showing 5: pot gets +2 mult (Ember Pip). Both are normal lit faces (5 lights alone; 6 only in a combo). | 30 | 38 | 45 | **obsidian**, bone pips; Hellfire mark on 6, Ember Pip mark on 5 (reuses asset-only `hellfire_d6` body) |
| `gilt` | Gilt Die | 1 → `gilded`, 5 → `gilded` | Potting the 1 or 5 gives +1 Ember each (Gilded; kept on bust). Both faces light alone, so it pays often. | 22 | 28 | 33 | **brass**; Gilded marks on 1 and 5 (reuses asset-only `gilded_d6` body) |
| `lodestone` | Lodestone Die | 6 → `wild` | Showing 6: counts as whichever value 1–6 scores best (Wild rules, nonstandard_dice §5: >6 only with a non-d6 present). | 26 | 33 | 39 | **glass**, clear (not frosted, so it stays distinct from Mirror/Lantern); Wild spark mark on 6 |
| `ossuary` | Ossuary Die | 3 → `twin`, 6 → `twin` | Showing 3 or 6: counts as two dice of that value for sets, never in runs (Twin rules, as Powder Keg). | 28 | 35 | 42 | **bone**, aged/darker tone; Twin two-dice mark on 3 and 6; corner emblem = `glyph_twin_face` |

F2/F3 prices = base × `shop_floor_price_percent [0, 25, 50]`, rounded to nearest (x.5 up). All sit above Extra Die 18 (rule: anything that adds a body costs ≥18) and above a d6 + its mods bought separately on F1 (e.g. Pyre = 18 body + 14 Hellfire + 6 Pip = 38 with step scaling → 30 is a ~20% "rare deal", offset by low odds). Run income ≈150/floor after the 5-Ember points cap, so one rare = 15–30% of a floor's income: a real choice, not a must-buy.

## 3. Interactions (all existing rules, nothing new)
- **Scoring:** faces score at printed value; the carved mod applies exactly as if the player had carved it. Pyre's 6 Hellfire multiplies after mult, rounded down.
- **Nerve:** can target all four (plain d6, not copy dice). Nudging moves to the adjacent face, which carries that face's mark (nudge a Pyre 5→6 = Hellfire). Undo window unchanged (nerve_v1).
- **Hot Hand:** counts like any die; no special rule.
- **Bust:** no free-rethrow protection (d6 only, nonstandard_dice §4). Gilt's Embers from earlier pots this hand are kept on bust (Gilded rule).
- **Seals:** unchanged; Ossuary's Twin raises the set level (e.g. Pair → Trips), then that combo's Seal applies.
- **Points→Embers cap:** Gilt's Embers are Gilded income, not points, so they are **outside** the 5/table cap (same as Gilded faces today). Sim: +1.5–3 end Embers, acceptable.
- **Carving:** pre-carved faces can't be recarved or blanked (new refusal string); the other 4–5 faces are carvable. The +50%-per-existing-mod price step **does not count pre-carved faces** (otherwise rares become carve-dead).

## 4. Rarity and shop odds
- New field `rarity: StringName` on `DieShape` and `SpecialDieData` (`&"common"` default; `&"rare"` for these four).
- **Shop only** (not Elite reward options, not events): each shop rolls once; on success the **second dice slot** becomes a rare (equal weight among the 4, no repeat of an owned rare in the same shop).
- Odds per shop: **F1 10% · F2 20% · F3 30%** (`RunData.shop_rare_die_chance = [0.10, 0.20, 0.30]`). Shaped-dice slot (`shape_offer_chance 0.25`) and specials are unchanged in the first slot, so the common pool doesn't dilute.
- Shop card shows a "Rare" tag (`shop_rare_tag`).

## 5. Phone read at 48 px
Family colour + mark face does the work; pip faces stay standard so value reads first.
- **Pyre:** black body, bone pips; the 6 face's Hellfire mark and the 5's Pip mark are high-contrast cream on black. Reads "dark die with a mark".
- **Gilt:** brass body, dark pips; Gilded mark on 1 and 5 (lit faces) so it's visible exactly when it pays.
- **Lodestone:** clear glass, dark pips with a thin outline (glass needs its own lit/cold glow tuning, as the props doc says); Wild spark on 6.
- **Ossuary:** darker bone than baseline + corner emblem so it never reads as a plain Bone; two-dice Twin mark on 3 and 6.
- Glow only on dice (lit rim), never fire; marks are carved decals on their own face only (world_props_v1 §3).
- AD to check all four as lit/cold stills at 48 px in both renderers.

### Tooltips (strings_v1, ≤12 words, one sentence; checked)
| id | text |
|---|---|
| `pyre` | A die whose 6 is Hellfire and 5 is Ember Pip. |
| `gilt` | A die whose 1 and 5 are Gilded: +1 Ember each. |
| `lodestone` | A die whose 6 is Wild, any number that scores best. |
| `ossuary` | A die whose 3 and 6 each count as two. |
| `shop_rare_tag` | Rare: its carved faces come with the die. |
| `rare_carved_locked` | Carved at the forge; this face cannot be recarved. |

**New strings_v1 ids:** `pyre`, `gilt`, `lodestone`, `ossuary`, `shop_rare_tag`, `rare_carved_locked`. Display names (Pyre Die, Gilt Die, Lodestone Die, Ossuary Die) are in the table above. `check_strings.py`: 394 checked, 0 problems.

## 6. Sim check
`sim/rare_dice_run.py`: starting_dice_sim (approved economy: points cap 5, bag 6, floor markup, hands 5/4/4, boss 7/5/5), rare dice as d6 + preset faces, shop-only at 10/20/30%, prices above. 2,000 runs per row.

| Variant | Win % greedy / standard / random | End Embers g / s / r | Rares bought/run (g/s/r) |
|---|---|---|---|
| Baseline (no rares) | 98.5 / 97.2 / 92.8 | 89 / 94 / 102 | — |
| **All 4 offered** | 99.0 / 97.7 / 94.2 | 91 / 95 / 106 | 0.68 / 0.45 / 0.56 |
| Only Pyre | 98.8 / 96.7 / 93.2 | 89 / 95 / 103 | 0.16 / 0.13 / 0.28 |
| Only Gilt | 98.5 / 96.7 / 93.2 | 91 / 96 / 106 | 0.36 / 0.14 / 0.30 |
| Only Lodestone | 98.8 / 97.0 / 94.6 | 90 / 95 / 105 | 0.45 / 0.14 / 0.29 |
| Only Ossuary | 98.6 / 96.8 / 93.4 | 89 / 95 / 104 | 0.36 / 0.14 / 0.28 |

Read: every die moves win rate by ≤1.8 pp and end Embers by ≤+3.5 — inside sim noise (~±0.6 pp at 2,000 runs for greedy; ±1 pp random). Nothing is a must-buy; Lodestone is the strongest per buy (watch it; first lever: price 26 → 30). Caveat: the sim's win rates are already near ceiling, so it measures "doesn't break the economy", not fun or build identity.

## 7. Answers to Systems Dev's open questions (julian_ideas_systems_scope.md §2)
1. **Enable existing shapes first, or new dice?** Rare dice reuse the d6 shape + preset_mods only, so they need no new shape work. Enabling the off shapes (Caltrop, Lantern, Tithe, …) is a separate balance pass and not part of this spec.
2. **Bag cap:** stays **6**. Rares take a slot; selling or swapping is the intended flow once the bag is full. Test the shop-full swap state with a rare offer.
3. **Rarity:** yes. Add a `rarity` field (common/rare) plus per-floor rare odds `[0.10, 0.20, 0.30]` on the second dice slot. No weight table for commons for now (equal, as today).
4. **Prices:** shapes stay a flat 18 (Economy v1). Rule dice are priced by power: the rares are 22–30 base, then floor-scaled.
5. **Shop-only vs elite:** rares are **shop-only** in v1. Elite dice options stay common, so Elite rewards don't spike.
(Character questions in §1 of the notes are out of scope here.)

## 8. PR split for Systems Dev
- **PR 1: data + rarity + shop roll.** Add `rarity` to `DieShape`/`SpecialDieData`; add `RunData.shop_rare_die_chance`; update `map_run_shop.gd _dice_offers` (slot 2 rare roll, no repeats, floor markup via the existing `shop_floor_price_percent`). Add 4 `.tres` (`pyre`, `gilt`, `lodestone`, `ossuary`) with DiceIds entries plus docs/DICE_IDS.md. Pre-carved faces are locked against carving and are skipped by the mod price step. Tests: seeded offer distribution per floor, prices F1/F2/F3, bag-full swap, preset faces score as their mods, Nerve on a preset face, the DiceIds test.
- **PR 2: strings + shop tag + assets hookup.** The 6 strings_v1 ids, the "Rare" tag on the shop card, and the `rare_carved_locked` refusal. Art keys `<die_id>_d6` (AD: obsidian/brass/glass/bone bodies, reusing the `hellfire_d6`/`gilded_d6` asset-only bodies). Godot Dev handles the card UI; Sound reuses the existing d6 settle and mod cues.


## Rulings on #174 (Oct 25, 2026)
1. Rares only from the shop rare roll (not common slot, not Elite). Confirmed.
2. Owned rares are not re-offered; if all four are owned, the roll misses and the slot stays a normal die offer.
3. Separate seed for the rare roll. Confirmed.
4. Sell value = half BASE price (like all dice); replaces "half the price paid". No paid-price storage.
5. Carving lock covers the pre-carved faces only and also blocks event remove-mod on them. Confirmed.
