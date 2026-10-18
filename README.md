# The Gambler's Descent (Godot 4.7)

A single-player 2D craps-style dice roguelite. This is the **greybox**: roll two
dice and watch come-out / Point rules resolve. Everything is set up so bet
types, dice-face mods, relics, and Dealer bosses can plug in later.

## Run

```bash
# Play (Roll button or Space)
/home/box/tools/godot/godot --path /workspace/dice/game

# Open in the editor
/home/box/tools/godot/godot --editor --path /workspace/dice/game

# Tests (headless). On a fresh checkout, import once first so class_names register:
/home/box/tools/godot/godot --headless --path /workspace/dice/game --import
/home/box/tools/godot/godot --headless --path /workspace/dice/game --script res://tests/test_craps_rules.gd
/home/box/tools/godot/godot --headless --path /workspace/dice/game --script res://tests/test_main_scene.gd
# ...or all at once:
./run_tests.sh
```

## Layout

```
project.godot            1280x720, main scene = scenes/main.tscn
scripts/data/            Resources: plain data, editable in the inspector
  die_face.gd            DieFace  - value, effect_id, tags
  die_data.gd            DieData  - name, level, faces[], ability id/description
  bet_type.gd            BetType  - id, name, payout, unlock_cost, description
  relic_data.gd          RelicData - id, name, description, hook_ids[]
scripts/core/            Pure logic, no nodes/UI (unit-testable)
  craps_round.gd         CrapsRound - come-out/Point state machine
  roll_result.gd         RollResult - outcome enum + totals + message
  dice_roller.gd         DiceRoller - rolls DieData with an injectable/seeded RNG
scripts/ui/main.gd       Greybox screen: thin glue between data, logic, labels
scenes/main.tscn         Greybox scene (Labels + ColorRects)
resources/dice/          standard_d6.tres, lucky_d6.tres (the 2 greybox dice)
resources/bets/          pass_line.tres (starter), field.tres (shop unlock sample)
resources/relics/        rabbits_foot.tres
tests/                   Headless SceneTree tests
tools/generate_sample_resources.gd   Regenerates the sample .tres files
```

## Architecture in one minute

1. **Data** (`scripts/data`) is Resources only. A die is a list of `DieFace`
   resources, so "modify a face mid-run" = edit one entry. Effects, abilities,
   bets, and relic hooks are referenced by **id** (`StringName`), and behavior
   for each id will live in code systems; the `.tres` files stay simple.
2. **Logic** (`scripts/core`) is `RefCounted`, with no scene dependency.
   `DiceRoller` turns `DieData` into landed faces, `CrapsRound.resolve_dice()`
   turns numbers into a `RollResult`. Rolling uses a seedable
   `RandomNumberGenerator`, so tests and seeded runs are deterministic.
3. **UI** (`scripts/ui`) only displays results. It never decides rules.

Rules (standard craps, Pass Line point of view):

| Phase    | Roll              | Outcome                          |
|----------|-------------------|----------------------------------|
| Come-out | 7, 11             | NATURAL_WIN (stay in come-out)   |
| Come-out | 2, 3, 12          | CRAPS_LOSS (stay in come-out)    |
| Come-out | 4,5,6,8,9,10      | POINT_SET -> Point phase         |
| Point    | the Point         | POINT_HIT -> back to come-out    |
| Point    | 7                 | SEVEN_OUT -> back to come-out    |
| Point    | anything else     | NO_DECISION                      |

### Extension points
- **Dealer bosses rigging rules:** `CrapsRound.natural_totals`,
  `craps_totals`, `seven_out_total` are plain variables a boss can change.
- **Face mods:** call `DieData.make_run_copy()` at run start (the greybox does)
  and edit `faces` freely; the shared `.tres` stays untouched.
- **Bets / relics:** listen to `CrapsRound.roll_resolved(result)` and use
  `result.is_win()`, `is_loss()`, `outcome`, `total`, `point_before`.
- **Replays/seeded runs:** `DiceRoller.new(seed)`; set `rng_seed` on the Main
  node in the inspector for a repeatable greybox session.
