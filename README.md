# Dice of the Damned

[![CI](https://github.com/cashdvs/rogue-craps/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/cashdvs/rogue-craps/actions/workflows/ci.yml)

A 3D, top-down dice roguelite set in an underworld casino, by **Tiny Anvil Games**, made in
**Godot 4.7.2** with GDScript. (The repo is still called `rogue-craps` from the old craps design.)

## Start here

**The game.** You lost your soul on one roll. Win it back table by table:

- **Bonfire tables:** throw 5 dice, pot a scoring combo from the dice that light up, then bank
  the points or throw the rest again. Nothing lights = bust (you lose the hand's pot and Soul).
  Clear a table by banking every required **bounty** (Two Pairs, Run of 4, ...) within its hands.
- **The run:** 3 floors, each a branching Slay the Spire-style map of Table, Elite, Event, Shop
  and Rest nodes, with a **boss** at the top who cheats (one rule-bending twist).
- **Build:** tables pay **Embers**. Spend them in the **Shop** on special dice for your
  **dice bag**, **face mods** carved onto single faces, and Infernal Seals that level up combos.
  **Soul** is your health; at 0 the run is over.

**Run it.**

1. Install **Godot 4.7.2-stable** (standard build, not .NET):
   [release page](https://github.com/godotengine/godot/releases/tag/4.7.2-stable).
   Headless Linux steps: [AGENTS.md §2](AGENTS.md#2-install-godot-472-headless-linux).
2. Clone the repo, then point `GODOT` at your binary:
   ```bash
   export GODOT=/path/to/godot              # run_tests.sh reads $GODOT
   "$GODOT" --headless --path . --import    # first time only: builds the .godot/ cache (never commit it)
   ```
3. Play: open the folder in the Godot editor (Import → `project.godot`) and press F5, or run
   `"$GODOT" --path .`. You get the studio splash, the title screen, then **Play** starts a run
   (`scenes/run.tscn`). Shortcuts:
   ```bash
   "$GODOT" --path . res://scenes/run.tscn       # straight to a new run (the map)
   "$GODOT" --path . res://scenes/bonfire.tscn   # one sandbox table, no run
   ```

**Test it.**

```bash
./run_tests.sh                                                   # every tests/test_*.gd + tests/qa_/qa_*.gd; non-zero exit = failure
"$GODOT" --headless --path . --script res://tests/test_run_screen.gd   # one test file
"$GODOT" --headless --path . res://scenes/bonfire.tscn --quit-after 300   # smoke run, like CI
```

Some `ERROR:` lines in test output are expected (tests feed bad input on purpose). Only the
`N passed, M failed` lines and the exit code matter.

## Where to go next

| You want to... | Read |
|---|---|
| Make your first PR (humans and bots) | [CONTRIBUTING.md](CONTRIBUTING.md) |
| Know how the code fits together, who owns what, how to add a die / face mod / event / boss | [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) |
| Find the current design docs | [docs/DESIGN_INDEX.md](docs/DESIGN_INDEX.md) |
| Coding conventions and tooling details (AI agents) | [AGENTS.md](AGENTS.md) |
| Know what reviewers check | [REVIEWING.md](REVIEWING.md) |
| Modules, labels and how to claim one | [docs/MODULES.md](docs/MODULES.md) |
| Steam release status, export CI and what's left before launch | [docs/STEAM_READINESS.md](docs/STEAM_READINESS.md) |
| Log AI-made content you add (Steam disclosure) | [docs/AI_CONTENT_LOG.md](docs/AI_CONTENT_LOG.md) |

Starter tasks carry the [`good first issue`](https://github.com/cashdvs/rogue-craps/issues?q=is%3Aopen+label%3A%22good+first+issue%22) label.

**License:** proprietary, all rights reserved; see [LICENSE](LICENSE). Contributions are
assigned (or licensed) to Tiny Anvil Games on submission.
