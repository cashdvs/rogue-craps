# AGENTS.md: guide for AI coding agents

This file is for coding agents (and the people driving them) who want to open pull requests
against **Dice of the Damned** by **Tiny Anvil**. Humans should also read
[CONTRIBUTING.md](CONTRIBUTING.md). Read this whole file before changing anything.

## 1. Project overview

- **Dice of the Damned** (working title *The Gambler's Descent*) is a single-player,
  craps-style dice roguelite made in **Godot 4.7.2** with **GDScript**. PC first (mouse and
  keyboard).
- You roll your way out of an infernal casino: bet on the Pass Line, hit a Coin target within a
  roll limit, and protect your **Soul** (the game's HP), which burns on bad rolls.
- **Current stage: proof of concept (POC).** One table, 2 plain dice, Pass Line (plus Odds), Soul,
  a 12-roll limit, a Coin target and a taunting Dealer. The goal is *feel*. The 2D table is on
  `main` (`scenes/table.tscn`); a top-down 3D table is being built by the core team (see
  [docs/MODULES.md](docs/MODULES.md)).
- Shop, map, bosses, dice rarities, face mods and sacrifice are **designed but not built**.

**Read for context before coding:**

| Doc | Why |
|---|---|
| [docs/design/gamblers-descent.md](docs/design/gamblers-descent.md) | The design doc. §12 is the POC scope; §2–3 are table and Soul rules. |
| [docs/art/poc_feel.md](docs/art/poc_feel.md) | Timings and "moments" for the 2D POC table. |
| [docs/art/poc_3d.md](docs/art/poc_3d.md) | Camera, materials, lighting and dice physics for the 3D table. |
| [docs/art/style_guide.md](docs/art/style_guide.md) | Palette and colour rules (Soul cyan `#4FE6E0` is only for Soul). |
| [docs/MODULES.md](docs/MODULES.md) | Which sub-section owns which files, and how to claim one. |

The files under `docs/design/` and `docs/art/` are **mirrors** of the studio's working docs, which
live outside the repo on the studio machine (`/workspace/dice/design`, `/workspace/dice/art/concept`).
Don't edit them in a feature PR; open an issue if something is wrong. See [docs/README.md](docs/README.md).

## 2. Install Godot 4.7.2 (headless, Linux)

Use exactly **4.7.2-stable** (standard build, not the .NET/mono build). Official builds are
attached to the godotengine GitHub release:

```
https://github.com/godotengine/godot/releases/download/<version>-stable/Godot_v<version>-stable_linux.x86_64.zip
```

```bash
GODOT_VERSION=4.7.2
mkdir -p ~/tools/godot && cd ~/tools/godot
curl -fL -o godot.zip \
  "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip"
unzip -o godot.zip && rm godot.zip
mv "Godot_v${GODOT_VERSION}-stable_linux.x86_64" godot && chmod +x godot
./godot --headless --version   # expect: 4.7.2.stable.official.ed1daf0bf
```

(For arm64 use `..._linux.arm64.zip`. On macOS/Windows grab the matching asset from the same
release page.) No display or GPU is needed for tests: everything runs with `--headless`.

## 3. Run the game and the tests

Point `GODOT` at your binary (the scripts default to the studio path `/home/box/tools/godot/godot`):

```bash
export GODOT=~/tools/godot/godot

# 1) First time on a fresh checkout: import, so class_name scripts and assets are registered.
#    (Generates the .godot/ cache. Never commit it.)
"$GODOT" --headless --path . --import

# 2) Run every test (run_tests.sh also imports first). Non-zero exit = a failure.
./run_tests.sh

# 3) Run one test file
"$GODOT" --headless --path . --script res://tests/test_poc_table.gd

# 4) Play (needs a display)
"$GODOT" --path .
# Editor
"$GODOT" --editor --path .
```

Screenshots or a short movie for your PR (works on a headless Linux box with `xvfb`):

```bash
xvfb-run -a -s "-screen 0 1920x1080x24" "$GODOT" --path . \
  --rendering-driver opengl3 --resolution 1920x1080 --script res://tools/capture_table.gd
```

Some "ERROR:" lines in test output are expected: tests deliberately feed bad input to check it is
rejected. Only the `N passed, M failed` summaries and the exit code matter.

## 4. Folder map (as of `main`)

```
project.godot            Godot project (main scene: res://scenes/table.tscn, GL Compatibility)
run_tests.sh             Runs tests/test_*.gd and tests/qa_/qa_*.gd headless
scenes/                  table.tscn (2D POC table), greybox.tscn (old debug screen)
scripts/data/            Resource classes (data definitions): DieFace, DieData, BetType,
                         BetCatalog, TuningData, TableRuleData
scripts/core/            Pure game logic, no nodes (RefCounted): DiceRoller, CrapsRound,
                         RollResult, Bankroll, ActiveBet, BetPayout, BetResolver, CrapsTable,
                         TableReport, PocTable, PocRollReport, ThrowGesture, DealerLines
scripts/table/           2D table scene views: table_scene.gd (director), die_view, chip_view,
                         puck_view, soul_meter, bankroll_stack, banner, dealer_view,
                         dealer_bubble, table_painter, rule_plaque, shake_camera, palette
scripts/audio/           SfxSynth (procedural sounds) + SfxManager (prefers audio/sfx/<event>.wav)
scripts/ui/              greybox.gd
resources/tuning/        poc_tuning.tres: ALL the table numbers
resources/bets/          pass/field/any_craps.tres + bet_catalog.tres
resources/dice/          standard_d6.tres
resources/dealer/        dealer_lines.json: Dealer taunt lines per event
audio/sfx/               Baked .wav sound effects (from tools/bake_sfx.gd)
fonts/                   Alfa Slab One, Barlow Condensed (SIL OFL; licences alongside)
shaders/                 felt, backdrop, bulb_light, grade
tests/                   test_*.gd (headless SceneTree scripts); tests/qa_/ is owned by QA
tools/                   generate_sample_resources, bake_sfx, capture_table, demo_table
docs/                    Mirrored design/art docs + MODULES.md
.github/                 PR/issue templates and CI
```

Planned (not on `main` yet): `scenes/table_3d.tscn`, `scripts/table3d/`, `shaders/3d/` for the 3D
table. Check [docs/MODULES.md](docs/MODULES.md) for where new systems should go.

## 5. Coding conventions

- **Static typing everywhere.** Type every variable, parameter and return
  (`var soul: int = 40`, `func roll(die: DieData) -> int:`). The project warns on untyped
  declarations; don't add new warnings.
- **Comments for beginners.** Studio code is written to be read by people learning Godot. Start
  each script with a `##` doc comment saying what it does and *why*; explain non-obvious rules
  (e.g. cite the design doc section). Keep comments true when you change code.
- **Logic separate from scenes/UI.** Rules and numbers go in `scripts/core/` as `RefCounted`
  classes with no nodes, so they can be unit-tested headless. Views (`scripts/table/`) only
  display state and forward input. Never put a craps rule in a view.
- **Signals for communication.** Logic emits signals (`Bankroll.coin_changed`,
  `PocTable.soul_changed`, `CrapsRound.roll_resolved`, ...); views connect to them. Children
  signal up, parents call down. Avoid reaching across the tree with hard-coded node paths.
- **`class_name` for reusable classes**, `snake_case` files, `PascalCase` classes,
  `snake_case` functions/variables, `UPPER_SNAKE` constants, `_leading_underscore` for private.
  Tabs for indentation (Godot default).
- **Seeded determinism.** All randomness goes through `DiceRoller` (or an injected
  `RandomNumberGenerator`). Never call global `randi()`/`randf()` in game logic. The same seed
  must give the same rolls; tests and the F1 force-roll debug depend on it. Animations and physics
  may *look* random but must land on the result `DiceRoller` picked.
- Keep files focused; prefer a new small class over growing `table_scene.gd`.

## 6. Data-driven Resources

Game content is defined as Godot `Resource` classes in `scripts/data/` and saved as `.tres` files
in `resources/`, so designers can tune without code:

| Class | File | Holds | Instances |
|---|---|---|---|
| `DieFace` | `scripts/data/die_face.gd` | one face: `value`, `effect_id`, `tags` | inside dice |
| `DieData` | `scripts/data/die_data.gd` | a die: name, `level`, `faces`, `ability_id`, level-up costs | `resources/dice/standard_d6.tres` |
| `BetType` | `scripts/data/bet_type.gd` | a bet: `rule`, payout ratio and overrides, winning totals, unlock cost | `resources/bets/*.tres` |
| `BetCatalog` | `scripts/data/bet_catalog.gd` | list of `BetType`s | `resources/bets/bet_catalog.tres` |
| `TuningData` | `scripts/data/tuning_data.gd` | every table number (stake, target, rolls, bet limits, Soul formulas, end-of-table, Dealer thresholds, Odds, throw gesture, timings) | `resources/tuning/poc_tuning.tres` |
| `TableRuleData` | `scripts/data/table_rule_data.gd` | a table rule (e.g. Hot Seven: Soul multipliers, roll-limit delta) | sub-resource in the tuning file |

Dealer taunts are plain JSON: `resources/dealer/dealer_lines.json` (event -> list of lines).

**Where tuning lives:** `resources/tuning/poc_tuning.tres`. Defaults are in
`scripts/data/tuning_data.gd`. **Never hard-code a game number in logic or views**: add an
`@export` to `TuningData` (with a `##` comment and the doc section) and read it from there.
`tools/generate_sample_resources.gd` regenerates sample resources; don't run it unless your change
needs it, because it rewrites files in `resources/`.

## 7. Rules for PRs

1. **Small, focused PRs.** One issue / one module per PR, roughly ≤ 400 changed lines of code
   (generated `.uid`/`.tres`/`.import` excluded). No drive-by refactors or reformatting.
   Rebase on `main` to update your branch; no merge commits (history is linear).
2. **Tests required for logic.** Any change in `scripts/core/` or `scripts/data/` needs new or
   updated checks in `tests/test_*.gd` (follow the existing `_check(condition, name)` pattern and
   `quit(1 if _failed > 0 else 0)`). A new test file named `tests/test_*.gd` runs automatically.
   `./run_tests.sh` must pass locally and in CI.
3. **Stay in your module.** Only touch files owned by the module you're working on
   ([docs/MODULES.md](docs/MODULES.md)). If you must touch another module's files, keep it
   minimal and explain why in the PR. Don't edit `tests/qa_/` (QA owns it) or `docs/design`,
   `docs/art` (mirrors).
4. **Never commit `.godot/`** (the import cache; it's in `.gitignore`), editor settings, builds,
   or large binaries. Do commit the `*.uid` files Godot creates next to new scripts, and the
   `*.import` files next to new assets.
5. **Keep seeded determinism** (see §5). If a test depends on randomness, give it a seed.
6. **Don't change game numbers on your own.** Numbers come from the design doc; if you think one
   is wrong, say so in the PR or an issue.
7. Visual changes need a screenshot or short capture in the PR.
8. Don't change CI, `project.godot` or `run_tests.sh` unless the issue asks for it.
9. Fill in the PR template. Link the issue (`Closes #N`). Branch names: see CONTRIBUTING.md.

Reviewers use [REVIEWING.md](REVIEWING.md) (gate checks, conformance, feel checks, safety). Read
it to know what your PR will be checked against. In particular: no network/HTTP/telemetry code,
no `OS.execute`/shell calls, no secrets, and no unexplained binaries; every asset needs its source
and a compatible licence next to it.

If you're unsure, open a draft PR early and ask.
