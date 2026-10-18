# Dice of the Damned (Godot 4.7): POC table

[![CI](https://github.com/cashdvs/rogue-craps/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/cashdvs/rogue-craps/actions/workflows/ci.yml)

A single-player craps roguelite by **Tiny Anvil** (working title *The Gambler's Descent*; design
doc: [`docs/design/gamblers-descent.md`](docs/design/gamblers-descent.md), v0.4 section 12). The
current build is the **proof-of-concept table**, where the goal is feel. You get 2 plain bone
dice, a Pass Line, Soul, a 12-roll limit, a target bankroll, and a taunting Dealer. Visuals and
timings follow the art spec in [`docs/art/poc_feel.md`](docs/art/poc_feel.md).

**Contributing:** humans start with [CONTRIBUTING.md](CONTRIBUTING.md), AI coding agents with
[AGENTS.md](AGENTS.md). Claimable sub-sections are listed in [docs/MODULES.md](docs/MODULES.md).

## Run

```bash
# Play (main scene = scenes/table.tscn)
/home/box/tools/godot/godot --path /workspace/dice/game
# The old greybox screen is still available:
/home/box/tools/godot/godot --path /workspace/dice/game res://scenes/greybox.tscn
# Editor
/home/box/tools/godot/godot --editor --path /workspace/dice/game
# All headless tests (imports first)
./run_tests.sh
# One QA script by hand (run_tests.sh already runs all tests/qa_/qa_*.gd)
/home/box/tools/godot/godot --headless --path . --script res://tests/qa_/qa_craps_stats.gd
# Screenshots / movie (need a display; xvfb works)
xvfb-run -a -s "-screen 0 1920x1080x24" /home/box/tools/godot/godot --path . \
  --rendering-driver opengl3 --resolution 1920x1080 --script res://tools/capture_table.gd
xvfb-run -a -s "-screen 0 1920x1080x24" /home/box/tools/godot/godot --path . \
  --rendering-driver opengl3 --resolution 1280x720 --fixed-fps 30 \
  --write-movie /tmp/table_poc.avi --script res://tools/demo_table.gd
```

## How to play (PC: mouse and keyboard)

| Action | Input |
|---|---|
| Add a 5-Coin chip to the Pass Line (5-25, before the come-out only) | Click the bankroll chip stack or the Pass Line, or press Up/+ |
| Take the bet down (before the come-out) | Right-click the stack or the Pass Line, or press Down/- |
| Throw | **Press on the dice in your hand (bottom right), drag, and flick.** A slow release or a plain click drops them back into your hand. |
| Quick throw (keyboard) | Space / Enter |
| Fast-forward a roll | Click (or Space) during the reveal or resolve |
| Reduced motion | R, or the F1 panel |
| Debug: seed and restart, force the next roll, Hot Seven rule | F1 |

The throw is decided **at release**. The seeded `DiceRoller` picks the faces. The flick's
direction and speed plan the path (along the flick, off the rim, coming to rest in the landing
zone), and the dice tween along that path and settle on the chosen faces. You can't throw while
the come-out Pass bet is under 5 Coin. During a Point, the bet is locked and you throw again.

## Tuning (one file)

`resources/tuning/poc_tuning.tres` uses `TuningData` (`scripts/data/tuning_data.gd`), and the
defaults in the script are the doc numbers:

- **Table:** stake 20, target 40, 12 rolls, bets 5-25, chip value 5.
- **Soul:** 40 Soul. The formulas are:
  - Seven-out: 2 + ceil(lost/10).
  - Craps: 1 + ceil(lost/10).
  - Other losses: floor(lost/10).
  - `soul_on_loss = true` (PM decision).
- **End of table:** miss penalty 3 + 1 per 25% of the gap (max 7), bust 7, clear bonus +5, and +1
  per unused roll.
- **Throw gesture:** `min_throw_speed` (700 px/s), `min_throw_drag` (40 px), speed→distance,
  throw time at slow and fast flicks, rim restitution.
- **Spec timings:** wind-up, throw, bounces, settle, die B delay, reveal hold and punch, a resolve
  duration per moment, reset, chip, payout and rake times, puck times, shake px and hit-stop ms per
  moment, seven-out escalation caps, fast-forward speed, and the reduced-motion scale and particle
  factor.
- **Table rule (Hot Seven):** ships **off**, because doc v0.4 §12 puts table rules out of POC
  scope. Use F1 or `table_rule_enabled` to try it.

## Dealer lines

`resources/dealer/dealer_lines.json` maps each event to a list of lines. The events are
`natural`, `craps`, `point_set`, `point_hit`, `seven_out`, `big_bet` (stake ≥ 20), `low_soul`
(Soul ≤ 12, once per table), `table_win`, and `table_fail`. A line is picked at random with no
immediate repeats (`DealerLines`), and each one plays the `dealer_taunt` sound.

## Layout

```
project.godot              1920x1080 design size, stretch canvas_items, aspect expand
scripts/data/              Resources: die_face, die_data, bet_type, bet_catalog, tuning_data, table_rule_data
scripts/core/              Pure logic (unit-tested, no nodes)
  craps_round / roll_result / dice_roller / bankroll / active_bet / bet_payout / bet_resolver
  craps_table / table_report   betting session (Pass, Field, Any Craps, Odds, Hard-way logic)
  poc_table / poc_roll_report  POC table: Soul, roll limit, target, end-of-table, "why" line
  throw_gesture                drag -> release velocity, throw threshold, path planning
  dealer_lines                 JSON lines, random without immediate repeats
scripts/table/             The POC table scene (drawn in code, no textures)
  table_scene.gd           director: input, roll sequence, moments, chips, HUD, end/debug screens
  die_view / chip_view / puck_view / soul_meter / bankroll_stack / banner / dealer_view / dealer_bubble
  table_painter (rim, point row, Pass Line arc) / rule_plaque / shake_camera / palette
scripts/audio/             SfxSynth (procedural sounds) + SfxManager (pool; prefers audio/sfx/<event>.wav)
shaders/                   felt (stains, burns, edge darkening, flash, scorch), backdrop, bulb_light, grade
fonts/                     Alfa Slab One + Barlow Condensed (SIL OFL, licenses alongside)
tests/                     test_*.gd and qa_/qa_*.gd (both run by run_tests.sh); tests/qa_/ belongs to QA; PR review: REVIEWING.md
tools/                     generate_sample_resources, bake_sfx, capture_table, demo_table
```

## Doc names used in code

| Design doc / art spec | Code |
|---|---|
| Coin | `Bankroll.coin` |
| Pass ("Natural (Pass)" in data) / "PASS LINE" on the felt | `pass.tres`, `BetType.Rule.PASS` |
| Field, Any Craps (doc stretch) | `field.tres`, `any_craps.tres`: logic and tests only, not on the POC felt |
| Soul | `PocTable.soul`, `SoulMeter` |
| Table rule "Hot Seven" | `TableRuleData` inside the tuning file (off for the POC) |
| Croupier / Dealer | `DealerView`, `DealerLines` |

## Rule precedence
This is documented in `craps_round.gd` and tested. Totals outside 2-12 are rejected. On the
come-out, a Natural beats Craps, which beats setting a Point. In the Point phase, hitting the Point
beats a Seven-out.
