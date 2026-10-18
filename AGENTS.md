# AGENTS.md: guide for AI coding agents

This file is for coding agents (and the people driving them) who want to open pull requests
against **Dice of the Damned** by **Tiny Anvil Games**. Humans should also read
[CONTRIBUTING.md](CONTRIBUTING.md). Read this whole file before changing anything.

## 1. Project overview

- **Dice of the Damned** (working title *The Gambler's Descent*) is a single-player,
  craps-style dice roguelite made in **Godot 4.7.2** with **GDScript**. PC first (mouse and
  keyboard).
- You roll your way out of an infernal casino: bet on the Pass Line, hit a Coin target within a
  roll limit, and protect your **Soul** (the game's HP), which burns on bad rolls.
- **Current stage: proof of concept (POC).** One table, 2 plain dice, the Pass Line, Soul,
  a 12-roll limit, a Coin target and a taunting Dealer. **Odds** exist in the logic
  (`CrapsTable`) but aren't on the 2D felt yet. Their rules: Odds can only be placed while a Point
  is on, need a Pass Line bet underneath, are capped at 2× the Pass bet (`odds_max_multiple` in
  `TuningData`), and ignore the 5–25 table limits. The goal is *feel*. The 2D table is on
  `main` (`scenes/table.tscn`); a top-down 3D table is being built by the core team (see
  [docs/MODULES.md](docs/MODULES.md)).
- Shop, map, bosses, dice rarities, face mods and sacrifice are **designed but not built**.

**Read for context before coding:**

| Doc | Why |
|---|---|
| [docs/DESIGN.md](docs/DESIGN.md) | Public design summary: pillars, core loop, craps rules, Coin and Soul, table goal, POC scope. |
| [docs/MODULES.md](docs/MODULES.md) | The feature modules, which files each owns, owners, and how to claim one. |
| [REVIEWING.md](REVIEWING.md) | What reviewers check on every PR. |

The full design and art documents are maintained by the Tiny Anvil Games team outside this repo.
Issues quote any extra numbers or specs they need. Don't edit `docs/DESIGN.md` in a feature PR;
open an issue if something looks wrong.

**License:** the code and assets are proprietary (see [LICENSE](LICENSE)). Contributions you
submit are assigned (or licensed) to Tiny Anvil Games, so only submit work you have the right to submit.

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

Point `GODOT` at your binary (`run_tests.sh` reads `$GODOT`; its built-in fallback path only exists on
the studio machine, so always set it):

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

Known quirk: `tools/capture_table.gd` and `tools/demo_table.gd` currently write to a
studio-machine folder (`OUT` at the top of `capture_table.gd`). Point it at a local folder in your
working copy for captures, and don't commit that change.

Some "ERROR:" lines in test output are expected: tests deliberately feed bad input to check it is
rejected. Only the `N passed, M failed` summaries and the exit code matter.

## 4. Folder map (as of `main`)

```
project.godot            Godot project (main scene: res://scenes/studio_splash.tscn, which then
                         opens boot/next_scene = res://scenes/table.tscn; GL Compatibility)
run_tests.sh             Runs tests/test_*.gd and tests/qa_/qa_*.gd headless
scenes/                  table.tscn (2D POC table), greybox.tscn (old debug screen),
                         studio_splash.tscn (Tiny Anvil Games boot splash)
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
scripts/splash/          studio_splash.gd (timeline player), splash_state.gd (SplashState autoload)
assets/branding/studio/  Studio logo layers + splash_timings.json motion spec (Art Director)
resources/tuning/        poc_tuning.tres: ALL the table numbers
resources/bets/          pass/field/any_craps.tres + bet_catalog.tres
resources/dice/          standard_d6.tres
resources/dealer/        dealer_lines.json: Dealer taunt lines per event
audio/sfx/               Baked .wav sound effects (from tools/bake_sfx.gd)
fonts/                   Alfa Slab One, Barlow Condensed (SIL OFL; licenses alongside)
shaders/                 felt, backdrop, bulb_light, grade
tests/                   test_*.gd (headless SceneTree scripts); tests/qa_/ is owned by QA
tools/                   generate_sample_resources, bake_sfx, capture_table, demo_table
docs/                    DESIGN.md (public design summary), MODULES.md (module map)
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
   updated checks in `tests/test_*.gd` (follow the existing check pattern in the file you extend,
   e.g. `_check(condition, name)` or `check(...)`, and exit with
   `quit(1 if _failed > 0 else 0)`). A new test file named `tests/test_*.gd` runs automatically.
   `./run_tests.sh` must pass locally and in CI.
3. **Stay in your module.** Only touch files owned by the module you're working on
   ([docs/MODULES.md](docs/MODULES.md)). If you must touch another module's files, keep it
   minimal and explain why in the PR. A "module" is a feature module from MODULES.md, not a
   folder. **`tests/qa_/`** (owned by QA): you may **add** checks, but never weaken or remove
   existing ones. Don't edit `docs/DESIGN.md` in a feature PR.
4. **Never commit `.godot/`** (the import cache; it's in `.gitignore`), editor settings, builds,
   or large binaries. Do commit the `*.uid` files Godot creates next to new scripts, and the
   `*.import` files next to new assets.
5. **Keep seeded determinism** (see §5). If a test depends on randomness, give it a seed.
6. **Don't change game numbers on your own.** Numbers come from the Game Designer; if you think one
   is wrong, say so in the PR or an issue.
7. Visual changes need a screenshot or short capture in the PR.
8. Don't change CI, `project.godot` or `run_tests.sh` unless the issue asks for it.
9. Fill in the PR template. Link the issue (`Closes #N`). Branch names: see CONTRIBUTING.md.
10. Opening a PR means agreeing to the contribution terms in [LICENSE](LICENSE).

Reviewers use [REVIEWING.md](REVIEWING.md) (gate checks, conformance, feel checks, safety). Read
it to know what your PR will be checked against. In particular: no network/HTTP/telemetry code,
no `OS.execute`/shell calls, no secrets, and no unexplained binaries; every asset needs its source
and a compatible license next to it.

If you're unsure, open a draft PR early and ask.
