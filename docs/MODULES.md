# Module ownership map

Dice of the Damned is split into **modules**: sub-sections that one person or agent can claim and
work on without stepping on anyone else. Each module lists the files it owns today (or the
**planned** paths for systems not built yet), its status and its owner.

- **Owner** is `Unclaimed`, `Tiny Anvil core` (the studio team; send PRs, but coordinate first), or
  a GitHub handle once a claim is accepted.
- **Status:** `Built (POC)` = on `main` and tested · `In progress` = being built right now ·
  `Designed` = in the design doc, no code yet.
- Design references are sections of [design/gamblers-descent.md](design/gamblers-descent.md).

## How to claim a module

1. Check this table and open issues (label `module:<name>`) so you don't duplicate work.
2. Open a **"Claim a module"** issue (template in `.github/ISSUE_TEMPLATE`), saying what you plan
   to do first and roughly when.
3. A maintainer replies and, if accepted, updates the owner here (and `CODEOWNERS` later).
   Claims on `Tiny Anvil core` modules are usually for a specific sub-task, not the whole module.
4. Work in small PRs that each close one issue. A claim with no activity for 14 days goes back to
   `Unclaimed`.

Shared files (`project.godot`, `run_tests.sh`, `.github/`, `scripts/data/tuning_data.gd`,
`resources/tuning/poc_tuning.tres`) belong to **Tiny Anvil core**. Small additions (a new export in
`TuningData` for your module, an autoload) are fine; say so in the PR.

## Modules

| Module (label) | Owns (current paths) | Planned paths | Status | Owner |
|---|---|---|---|---|
| **Dice physics** (`module:dice-physics`) | `scripts/core/dice_roller.gd`, `scripts/core/throw_gesture.gd`, `scripts/table/die_view.gd`, `scripts/data/die_data.gd`, `scripts/data/die_face.gd`, `resources/dice/` | `scripts/table3d/` dice + throw (RigidBody3D, seeded landing), `scenes/table_3d.tscn` | 2D: Built (POC) · 3D: In progress | Tiny Anvil core |
| **Betting / bet slots** (`module:betting`) | `scripts/core/craps_round.gd`, `roll_result.gd`, `bankroll.gd`, `active_bet.gd`, `bet_payout.gd`, `bet_resolver.gd`, `craps_table.gd`, `table_report.gd`; `scripts/data/bet_type.gd`, `bet_catalog.gd`; `resources/bets/`; `scripts/table/bet_zone.gd`, `chip_view.gd`, `bankroll_stack.gd`, `puck_view.gd`; `tests/test_betting.gd`, `tests/test_craps_rules.gd` | more `resources/bets/*.tres` (doc §5) | Pass + Odds: Built (POC) · Field/Any Craps: logic only · other bets: Designed | Unclaimed (logic) |
| **Soul** (`module:soul`) | `scripts/core/poc_table.gd`, `poc_roll_report.gd` (Soul, roll limit, target, end of table); `scripts/table/soul_meter.gd`; `tests/test_poc_table.gd` | `scripts/core/soul.gd` if split out | Built (POC) | Tiny Anvil core |
| **Table rules** (`module:table-rules`) | `scripts/data/table_rule_data.gd` (Hot Seven, off in POC), `scripts/table/rule_plaque.gd` | `resources/rules/*.tres`, `scripts/core/table_rules/` (doc §6) | Designed (Hot Seven data only) | Unclaimed |
| **Dealer / taunts** (`module:dealer`) | `scripts/core/dealer_lines.gd`, `resources/dealer/dealer_lines.json`, `scripts/table/dealer_view.gd`, `dealer_bubble.gd`; `tests/test_dealer_lines.gd` | | Built (POC) | Unclaimed |
| **Shop** (`module:shop`) | none yet | `scripts/core/shop/`, `scripts/data/shop_item.gd`, `resources/shop/`, `scenes/shop.tscn`, `scripts/shop/` (doc §5, §7, §8, §9) | Designed | Unclaimed |
| **Map / events** (`module:map`) | none yet | `scripts/core/map/` (floor generation, doc §9), `scripts/data/event_data.gd`, `resources/events/`, `scenes/map.tscn`, `scripts/map/` | Designed | Unclaimed |
| **Bosses** (`module:bosses`) | none yet | `scripts/data/dealer_boss_data.gd`, `resources/bosses/`, `scripts/core/bosses/` (doc §10) | Designed (needs table rules first) | Unclaimed |
| **UI** (`module:ui`) | `scripts/table/table_scene.gd` (HUD, end/debug screens), `banner.gd`, `table_painter.gd`, `palette.gd`, `shake_camera.gd`, `bulb_view.gd`; `scripts/ui/`; `scenes/`; `shaders/`; `fonts/`; `tests/test_table_scene.gd`, `tests/test_greybox_scene.gd` | `scripts/ui/` menus, run-over, settings | Built (POC) | Tiny Anvil core |
| **Audio** (`module:audio`) | `scripts/audio/`, `audio/sfx/`, `tools/bake_sfx.gd` | `audio/music/` | Built (POC, procedural SFX) | Unclaimed |
| **Art import** (`module:art-import`) | `fonts/`, `shaders/` (with UI), `*.import` settings | `art/` (textures, models, `.import` presets), `shaders/3d/` (toon-noir, outlines; see `art/poc_3d.md`) | In progress (3D greybox) | Tiny Anvil core |
| **QA** | `tests/qa_/` | | Built | Tiny Anvil core (QA) |
| **Tools / CI** | `tools/`, `run_tests.sh`, `.github/` | | Built | Tiny Anvil core |

`scripts/table/table_scene.gd` is the 2D table's director and is touched by several modules; keep
changes there small and mention them in the PR.
