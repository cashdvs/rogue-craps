# Design index

Where the design lives and which docs are current. **The full design docs are not in this repo**
(there's no `design/` folder here): they live in the Tiny Anvil Games team shared folder
`design/` (with the simulations in `sim/`), maintained by the Game Designer. Issues quote any
numbers you need; ask in the issue if a doc is missing. Rules and numbers change only with
PM's approval.

## In the repo

| Doc | Status | Notes |
|---|---|---|
| [docs/DESIGN.md](DESIGN.md) | **Superseded** (craps era) | Describes the craps proof of concept (Pass Line, Coin, 12-roll limit). Kept for history; don't edit it in a feature PR. Use the current docs below. |
| [docs/MODULES.md](MODULES.md) | Current for labels and claims | Status and planned paths predate the Bonfire loop; see [ARCHITECTURE.md](ARCHITECTURE.md) for today's files. |
| `art/models/**/README.md`, `art/models/dice/SPECIAL_DICE.md` | Current | Per-asset hooks, locked art direction, special dice visuals. |
| `assets/branding/studio/*.md` | Current | Boot splash motion spec and Godot notes. |
| `scripts/audio/README.md`, `audio/sfx/SOURCES.md` | Current | Sound events and asset sources. |

## Team shared folder `design/` (not in the repo)

| Doc | Status | What it covers |
|---|---|---|
| `how_bonfire_plays.md` | **Current**: start here | Plain-language guide to the Bonfire loop (its §4 fixes are proposals). |
| `bonfire_build_content.md` | **Current** | Build content: special dice, face mods, Infernal Seals, archetypes, handful size. No relics. |
| `bonfire_map_events_juice.md` | **Current** | Map, nodes, Elites and bosses, events, shop and rest, scoring juice, onboarding. |
| `nonstandard_dice.md` | **Current** (§10 is the final dice list) | Non-d6 dice (Coin, d3, d4-d20): rules, odds, prices; §10 names the final dice (Ferryman's Coin, Powder Keg d3, Caltrop d4, ... Verdict d20). |
| `run_tuning_v1.md` | **Current** (PM-approved) | Difficulty curve; per-floor data changes; boss and Elite retune addendum. |
| `backstory.md` | **Current** (canon lore) | Pitch, the torn soul contract, the Proprietor and the Underhouse. Tone reference for text and art. |
| `onboarding_hints_v1.md` | Proposal | Table 1 teaching flow; would replace the hint strings in `scripts/bonfire/bonfire_tutorial.gd` once approved. |
| `playtest_v1_questions.md` | Current (process) | Questions for Cash after a playtest. |
| `notes/value_tag_plan.md` | Plan (Godot Dev) | Value tag over settled non-d6 dice; no code yet. |
| `burn_line.md` | **Superseded** | Unfinished "Burn Line" loop draft, replaced by Bonfire. |
| `gamblers-descent.md` | **Superseded** (craps era) | Design doc v0.5 for the craps game. |
| `gamblers-descent-v0.1.md`, `-v0.4.md`, `-v0.5-pre3c.md`, `-v0.5-pre-package.md`, `-v0.5-pre-burnline.md` | **Superseded** (craps era) | Archived snapshots of the craps design. |
| `progression-options.md` | **Superseded** | Archived craps-era progression options (its own header says so). The map and rewards are now in `bonfire_map_events_juice.md`. |

Art concepts and briefs (`art/concept/`, `art/ui/`, `art/renders/`) are also in the team shared
folder; see the art sections of [ARCHITECTURE.md](ARCHITECTURE.md).
