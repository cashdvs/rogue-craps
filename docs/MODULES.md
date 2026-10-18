# Module ownership map

Dice of the Damned is split into **feature modules**: sub-sections that one person or agent can
claim and work on without stepping on anyone else. **"Module" always means one of the feature
modules below** (not a folder). A normal feature PR spans several folders of one module, for
example `scripts/core` + `scripts/data` + `resources/bets` for Betting, and that's still one
module.

Each module lists the files it owns today (or **planned** paths for systems not built yet), its
status, its team owner and whether it's open to outside contributors.

- **Status:** `Built (POC)` = on `main` and tested · `In progress` = being built right now ·
  `Designed` = in the design, no code yet.
- **Owner** is the Tiny Anvil Games team role responsible for the module. Owners review PRs in their
  module; the default GitHub owner for every path is `@cashdvs` (see `.github/CODEOWNERS`).
- **Open to contributors:** `Yes` = claim it or pick up issues · `Issues only` = take labelled
  issues, but coordinate before larger work.
- Game design: [DESIGN.md](DESIGN.md).

## Team roles

| Role | Owns |
|---|---|
| **Godot Dev** | 3D table, dice physics, feel/juice, shaders |
| **Systems Dev** | run structure, shop, map/events, Embers, dice bag, bet slots/betting, bosses |
| **Sound Designer** | audio |
| **Art Director** | art, art import, fonts |
| **Game Designer** | design docs and tuning numbers (`resources/tuning/`, `TuningData` defaults) |
| **QA Tester** | `tests/qa_/` |
| **PM** | coordination: module claims, priorities, merges |

## Modules (label = `module:<id>`)

| Module | Label | Owns (current paths) | Planned paths | Status | Owner | Open to contributors |
|---|---|---|---|---|---|---|
| **3D table** | `module:table-3d` | none on `main` yet | `scenes/table_3d.tscn`, `scripts/table3d/` | In progress | Godot Dev | Issues only |
| **Dice physics** | `module:dice-physics` | `scripts/core/dice_roller.gd`, `scripts/core/throw_gesture.gd`, `scripts/table/die_view.gd` | 3D dice + throw in `scripts/table3d/` (RigidBody3D, seeded landing) | 2D: Built (POC) · 3D: In progress | Godot Dev | Issues only |
| **Feel / juice** | `module:feel` | `scripts/table/table_scene.gd` (roll sequence, moments, timings), `banner.gd`, `shake_camera.gd`, `bulb_view.gd` | | Built (POC) | Godot Dev | Issues only |
| **Betting / bet slots** | `module:betting` | `scripts/core/craps_round.gd`, `roll_result.gd`, `bankroll.gd`, `active_bet.gd`, `bet_payout.gd`, `bet_resolver.gd`, `craps_table.gd`, `table_report.gd`; `scripts/data/bet_type.gd`, `bet_catalog.gd`; `resources/bets/`; `scripts/table/bet_zone.gd`, `chip_view.gd`, `bankroll_stack.gd`, `puck_view.gd`; `tests/test_betting.gd`, `tests/test_craps_rules.gd` | more `resources/bets/*.tres`, bet-slot unlocks | Pass + Odds: Built (POC) · Field/Any Craps: logic only · others: Designed | Systems Dev | Yes |
| **Soul** | `module:soul` | `scripts/core/poc_table.gd`, `poc_roll_report.gd` (Soul, roll limit, target, end of table); `scripts/table/soul_meter.gd`; `tests/test_poc_table.gd` | `scripts/core/stake_rules.gd` | Built (POC) | Systems Dev | Yes |
| **Run structure** | `module:run` | none yet | `scripts/core/run/` (purse, floors, run state, run over) | Designed | Systems Dev | Yes |
| **Dice bag** | `module:dice-bag` | `scripts/data/die_data.gd`, `scripts/data/die_face.gd`, `resources/dice/` | `scripts/core/dice_bag.gd`, rarities, face mods, `resources/dice/*.tres` | Data: Built · rest: Designed | Systems Dev | Yes |
| **Table rules** | `module:table-rules` | `scripts/data/table_rule_data.gd` (Hot Seven, off in the POC), `scripts/table/rule_plaque.gd` | `resources/rules/*.tres`, `scripts/core/table_rules/` | Designed (Hot Seven data only) | Systems Dev | Yes |
| **Shop** | `module:shop` | none yet | `scripts/core/shop/`, `scripts/data/shop_data.gd`, `resources/shop/`, `scenes/shop.tscn`, `scripts/shop/` | Designed | Systems Dev | Yes |
| **Map / events** | `module:map-events` | none yet | `scripts/core/map/` (floor generation, scaling), `scripts/data/event_data.gd`, `resources/map/`, `resources/events/`, `scenes/map.tscn`, `scripts/map/` | Designed | Systems Dev | Yes |
| **Bosses** | `module:bosses` | none yet | `scripts/data/dealer_boss_data.gd`, `resources/bosses/`, `scripts/core/bosses/` | Designed (needs table rules first) | Systems Dev | Yes |
| **Embers (meta)** | `module:embers` | none yet | `scripts/core/meta/`, `resources/meta/` | Designed (post-POC) | Systems Dev | Later |
| **Dealer / taunts** | `module:dealer` | `scripts/core/dealer_lines.gd`, `resources/dealer/dealer_lines.json`, `scripts/table/dealer_view.gd`, `dealer_bubble.gd`; `tests/test_dealer_lines.gd` | | Built (POC) | PM (assigns) | Yes |
| **UI** | `module:ui` | HUD, end and debug screens in `scripts/table/table_scene.gd`; `table_painter.gd`, `palette.gd`; `scripts/ui/`; `scenes/table.tscn`, `scenes/greybox.tscn`; `tests/test_table_scene.gd`, `tests/test_greybox_scene.gd` | `scripts/ui/` menus, settings | Built (POC) | Godot Dev | Issues only |
| **Shaders** | `module:shaders` | `shaders/` | `shaders/3d/` (toon shading, outlines) | Built (2D) · 3D: In progress | Godot Dev | Issues only |
| **Audio** | `module:audio` | `scripts/audio/`, `audio/sfx/`, `tools/bake_sfx.gd` | `audio/music/` | Built (POC, procedural SFX) | Sound Designer | Yes |
| **Fonts** | `module:fonts` | `fonts/` (with their license files) | | Built | Art Director | Issues only |
| **Art import** | `module:art-import` | `*.import` settings for art | `art/` (textures, models, import presets) | In progress (3D greybox) | Art Director | Issues only |
| **QA tests** | `module:qa` | `tests/qa_/` | | Built | QA Tester | Add checks only (see below) |
| **Tools / CI** | `module:tools-ci` | `tools/`, `run_tests.sh`, `.github/` | | Built | PM | Issues only |

`scripts/table/table_scene.gd` is the 2D table's director. Feel, UI and Betting all touch it, so
keep changes there small and say which part you changed in the PR.

**`tests/qa_/`:** contributors may **add** checks there, but must never weaken or remove existing
ones.

**Shared files:** `project.godot`, `run_tests.sh`, `.github/` (Tools / CI) and the tuning file
`resources/tuning/poc_tuning.tres` with the defaults in `scripts/data/tuning_data.gd` (Game
Designer's numbers). Adding a new `@export` to `TuningData` for your module is fine; changing an
existing number needs the Game Designer's OK.

## How to claim a module

1. Check this table and open issues (label `module:<id>`) so you don't duplicate work.
2. Open a **"Claim a module"** issue (template in `.github/ISSUE_TEMPLATE`), saying what you plan
   to do first and roughly when.
3. PM replies and, if accepted, adds you to this table (and to `.github/CODEOWNERS` if you'll
   review that area). Claims on `Issues only` modules are for a specific sub-task.
4. Work in small PRs that each close one issue. A claim with no activity for 14 days goes back to
   unclaimed.
