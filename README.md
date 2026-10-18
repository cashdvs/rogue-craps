# The Gambler's Descent (Godot 4.7)

A single-player 2D craps-style dice roguelite (design doc:
`/workspace/dice/design/gamblers-descent.md`). Current state: craps rules, Coin
bankroll, and Pass / Field / Hard 8 betting, with a plain greybox screen.

## Run

```bash
# Play (Roll button or Space)
/home/box/tools/godot/godot --path /workspace/dice/game

# Open in the editor
/home/box/tools/godot/godot --editor --path /workspace/dice/game

# Tests (headless). On a fresh checkout, import once first so class_names register:
/home/box/tools/godot/godot --headless --path /workspace/dice/game --import
/home/box/tools/godot/godot --headless --path /workspace/dice/game --script res://tests/test_craps_rules.gd
/home/box/tools/godot/godot --headless --path /workspace/dice/game --script res://tests/test_betting.gd
/home/box/tools/godot/godot --headless --path /workspace/dice/game --script res://tests/test_greybox_scene.gd
# ...or all at once:
./run_tests.sh
```

## Layout

```
project.godot            1280x720
scripts/data/            Resources: plain data, editable in the inspector
  die_face.gd            DieFace  - value, effect_id, tags
  die_data.gd            DieData  - name, level, faces[], ability id/description, level-up costs
  bet_type.gd            BetType  - id, name, rule, payout_numerator/denominator, overrides, unlock cost
  bet_catalog.gd         BetCatalog - the list of bets offered
  chip_data.gd           ChipData - chips are the RELICS (doc naming); money is Coin
scripts/core/            Pure logic, no nodes/UI (unit-testable)
  craps_round.gd         CrapsRound - come-out/Point state machine (rejects totals outside 2-12)
  roll_result.gd         RollResult - outcome enum + totals + message
  dice_roller.gd         DiceRoller - rolls DieData with a seeded RNG (-1 = random)
  bankroll.gd            Bankroll  - Coin with coin_changed signal; can't go negative
  active_bet.gd          ActiveBet - a stake sitting on the felt
  bet_payout.gd          BetPayout - WIN / LOSE / PUSH / STAYS + profit for one bet
  bet_resolver.gd        BetResolver - stateless: RollResult + bets -> payouts
  craps_table.gd         CrapsTable - betting session: place/clear bets, roll, pay
  table_report.gd        TableReport - what one roll did
scripts/ui/greybox.gd    Plain-button test screen (scenes/greybox.tscn)
resources/dice/          standard_d6 + doc starter dice (ember, weighted_bone, mirror, lucky_knuckle)
resources/bets/          pass, field, hard_8 + bet_catalog.tres
resources/chips/         the 5 first-playable chips (data only)
tests/                   test_*.gd run by run_tests.sh; tests/qa_/ is QA-only
tools/generate_sample_resources.gd   Regenerates resources/ from the doc numbers
```

## Doc names used in code

| Design doc | Code |
|---|---|
| Coin (money) | `Bankroll.coin` |
| Chips (relics) | `ChipData`, `resources/chips/` |
| Natural (Pass), 1:1 | `pass.tres`, `BetType.Rule.PASS` |
| Field: 1:1, 2 pays 2:1, 12 pays 3:1 | `field.tres`, `Rule.ONE_ROLL` + overrides |
| Hard 8, 9:1 | `hard_8.tres`, `Rule.HARD_WAY` |
| Odds (true odds) | `Rule.ODDS` logic exists; data paused |
| Min bet 5, table cap 25 | `CrapsTable.min_bet / max_bet` |

## Architecture in one minute

1. **Data** (`scripts/data`) is Resources only. A die is a list of `DieFace`
   resources, so "modify a face mid-run" = edit one entry. Payouts are
   whole-number ratios (`6:5` = numerator 6, denominator 5) and computed with
   integer math (rounded down to whole Coin).
2. **Logic** (`scripts/core`) is `RefCounted`, with no scene dependency.
   `DiceRoller` -> die values -> `CrapsTable.roll()` -> `CrapsRound` decides the
   outcome -> `BetResolver` settles each bet -> Coin goes back to the `Bankroll`.
3. **UI** only displays results and forwards clicks. It never decides rules.

### Rule precedence (for Dealers that rig rules)
Documented at the top of `craps_round.gd` and tested: totals outside 2-12 are
rejected first; on the come-out Natural beats Craps beats setting a Point; in
the Point phase hitting the Point beats Seven-out.

### Paused (per PM)
Table Coin targets / roll limits, Soul, the shop, and the rest of the
first-playable bets are parked on the local branch `wip/table-run-shop`.
