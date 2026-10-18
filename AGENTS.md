# AGENTS.md: guide for AI coding agents

This file is for coding agents (and the people driving them) who want to open pull requests
against **Dice of the Damned** by **Tiny Anvil Games**. Humans should also read
[CONTRIBUTING.md](CONTRIBUTING.md). Read this whole file before changing anything.

## 1. Project overview

- **Dice of the Damned** (formerly *The Gambler's Descent*) is a single-player,
  craps-style dice roguelite made in **Godot 4.7.2** with **GDScript**. PC first (mouse and
  keyboard).
- You roll your way out of an infernal casino: bet on the Pass Line, hit a Coin target within a
  roll limit, and protect your **Soul** (the game's HP), which burns on bad rolls.
- **Current stage: proof of concept (POC).** One table, 2 plain dice, the Pass Line, Soul,
  a 12-roll limit, a Coin target and a taunting Dealer. **Odds** exist in the logic
  (`CrapsTable`) but aren't on either felt yet. Their rules: Odds can only be placed while a Point
  is on, need a Pass Line bet underneath, are capped at 2× the Pass bet (`odds_max_multiple` in
  `TuningData`), and ignore the 5–25 table limits. The goal is *feel*. The main table is now
  the **3D table** (`scenes/table_3d.tscn`: angled overhead camera, real-physics dice you grab
  and flick; see §4a). It is still being built by the core team (see
  [docs/MODULES.md](docs/MODULES.md)). The 2D table (`scenes/table.tscn`) stays as a reference.
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
"$GODOT" --headless --path . --script res://tests/test_table_3d.gd   # 3D table + real physics

# 4) Play (needs a display). Main scene = the 3D table; the 2D table is still runnable:
"$GODOT" --path .
"$GODOT" --path . res://scenes/table.tscn
# Editor
"$GODOT" --editor --path .
```

Screenshots or a short movie for your PR (works on a headless Linux box with `xvfb`):

```bash
# 3D table (Forward+ needs Vulkan; lavapipe under xvfb works). Writes PNGs to --out=<folder>
# (default user://captures_3d/). Add `idle` after `--` for just the idle shot.
xvfb-run -a -s "-screen 0 1920x1080x24" "$GODOT" --path . --rendering-driver vulkan \
  --resolution 1920x1080 --script res://tools/capture_table_3d.gd -- --out=/tmp/captures_3d/

# 2D table
xvfb-run -a -s "-screen 0 1920x1080x24" "$GODOT" --path . \
  --rendering-driver opengl3 --resolution 1920x1080 --script res://tools/capture_table.gd

# 3D dice physics sweep: settle-time / landing stats, any TuningData number overridable
"$GODOT" --headless --path . --script res://tools/stats_table_3d.gd -- die_linear_damp=1.0
```

Known quirk: the 2D tools `tools/capture_table.gd` and `tools/demo_table.gd` currently write to a
studio-machine folder (`OUT` at the top of `capture_table.gd`). Point it at a local folder in your
working copy for captures, and don't commit that change.

Some "ERROR:" lines in test output are expected: tests deliberately feed bad input to check it is
rejected. Only the `N passed, M failed` summaries and the exit code matter.

## 4. Folder map (as of `main`)

```
project.godot            Godot project "Dice of the Damned" (main scene: res://scenes/table_3d.tscn;
                         Forward+ renderer, Mobile renderer on mobile; Jolt Physics at 120 Hz)
run_tests.sh             Runs tests/test_*.gd and tests/qa_/qa_*.gd headless
scenes/                  table_3d.tscn (3D POC table, main scene), table.tscn (2D POC table,
                         reference), greybox.tscn (old debug screen)
scripts/data/            Resource classes (data definitions): DieFace, DieData, BetType,
                         BetCatalog, TuningData, TableRuleData
scripts/core/            Pure game logic, no nodes (RefCounted): DiceRoller, CrapsRound,
                         RollResult, Bankroll, ActiveBet, BetPayout, BetResolver, CrapsTable,
                         TableReport, PocTable, PocRollReport, ThrowGesture, DealerLines
scripts/table3d/         3D table (see §4a): table_3d.gd (director), dice_sim, throw_recording,
                         die_visual, table_3d_builder, camera_rig, chip_3d, puck_3d, dealer_3d,
                         lamp_3d, felt_print, fx_3d, toon
scripts/table/           2D table scene views (some reused by the 3D table's HUD layer):
                         table_scene.gd (director), die_view, chip_view,
                         puck_view, soul_meter, bankroll_stack, banner, dealer_view,
                         dealer_bubble, table_painter, rule_plaque, shake_camera, palette
scripts/audio/           SfxSynth (procedural sounds) + SfxManager (prefers audio/sfx/<event>.wav)
scripts/ui/              greybox.gd
resources/tuning/        poc_tuning.tres: ALL the table numbers
resources/bets/          pass/field/any_craps.tres + bet_catalog.tres
resources/dice/          standard_d6.tres
resources/dealer/        dealer_lines.json: Dealer taunt lines per event
audio/sfx/               Baked .wav sound effects (from tools/bake_sfx.gd)
fonts/                   Alfa Slab One, Barlow Condensed (SIL OFL; licenses alongside)
shaders/                 2D: felt, backdrop, bulb_light, grade
shaders/3d/              toon_noir (stepped toon lighting, felt/chip modes), outline (inverted-hull
                         ink), fx_unshaded, fx_particle (billboard particles)
tests/                   test_*.gd (headless SceneTree scripts, incl. test_table_3d.gd); tests/qa_/ is
                         owned by QA
tools/                   generate_sample_resources, bake_sfx, capture_table, demo_table (2D);
                         capture_table_3d, stats_table_3d (3D)
docs/                    DESIGN.md (public design summary), MODULES.md (module map)
.github/                 PR/issue templates and CI
```

Check [docs/MODULES.md](docs/MODULES.md) for where new systems should go.

## 4a. The 3D table and its dice

- **Scene:** `scenes/table_3d.tscn` with `scripts/table3d/table_3d.gd` as the director. It runs the
  same one-Pass-Line loop as the 2D table. The rules stay in `PocTable` (pure logic), and the 2D-in-spec UI
  (Soul meter, banners, sum, bankroll, why-line) is reused from `scripts/table/` on a CanvasLayer.
  Units are meters, with the felt at y = 0. `Table3DBuilder` builds the greybox table (felt, padded
  rails, backboard, room dressing) **and the colliders** the dice bounce off. `CameraRig` is the angled
  perspective camera (reveal follow, shake, phone framing: portrait rotates the view, and the camera moves
  closer if a die would render under `min_die_px`).
- **Input:** click the Pass Line or the bankroll to stack chips (5–25 Coin; right-click takes one down).
  Then grab the dice, drag and **flick**: release speed and direction shape the throw, and a weak flick drops the dice
  back into your hand. Space = quick throw. Click during a roll = fast-forward. T = speed 1×/2×/Instant.
  R = reduced motion. F1 = debug panel (force the next roll). The `forced_rolls` export queues faces for tests.
- **Physics:** Jolt Physics at **120 ticks/s** (`project.godot [physics]`, bounce threshold
  0.15 m/s so dice rebound off the backboard). Dice use heavier gravity (`die_gravity_scale`) and
  damping so the median settle is ≤ `settle_target` (0.9 s).
- **How the seeded result is hit with real physics** (`dice_sim.gd`, `die_visual.gd`):
  1. At release the director asks the seeded `DiceRoller` for the faces. That's the result.
  2. **Pre-simulate:** `DiceSim` throws two invisible `RigidBody3D` dice with the flick's velocity and
     spin. The physics clock is sped up (`sim_warp`), so the whole throw is computed during the 0.12 s
     wind-up, and every tick (transforms, contacts, rest and tumble-end times) goes into a `ThrowRecording`.
     A die resting cocked against a rail gets a small recorded nudge to tip it flat.
  3. **Invisible face remap:** the recording says which physical face ended on top. The visible
     die's inner `faces` node is turned (`DieVisual.remap_basis`, one of the 24 cube orientations) so the
     seeded face sits there. This is done before playback, so you see the true physical tumble landing on the right face.
  4. **Playback** at normal speed. `DieVisual` copies the recorded transforms and emits its audio
     signals in sync: `impact` (relative contact speed, surface, die-die once per pair, material;
     silent under `impact_min_speed`), `tumble_ending`, `rest` and `settled`.
  5. **Settle assist:** a die still moving at `assist_start` (1.2 s after release) is eased smoothly
     flat (no snap), so the reveal always completes by `reveal_cap` (1.5 s).
  Never replace this with a scripted path or a visible snap. Throw and bounce feel come first.
- **Tuning:** every 3D number (throw shaping, die mass, bounce and damping, `sim_warp`, settle and assist
  timings, camera, `min_die_px`, audio thresholds) is an `@export` in `TuningData`, set in
  `resources/tuning/poc_tuning.tres`.
- **Tests:** `tests/test_table_3d.gd` throws real dice headless. It checks:
  - the face-remap math for all (physical, wanted) pairs;
  - that many seeded flicks always settle flat, on the felt, showing the `DiceRoller` result;
  - the settle median and reveal cap;
  - that weak flicks don't roll, the speed toggle works, and the audio signals fire;
  - that wins never restore Soul;
  - that dice are ≥ 48 px on phone-sized viewports.
- **Shaders:** every opaque prop uses `shaders/3d/toon_noir.gdshader` through the `Toon` material
  factory (`toon.gd`), plus an optional `outline.gdshader` ink hull. Effects use `fx_unshaded` and `fx_particle`.

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
- Keep files focused; prefer a new small class over growing `table_scene.gd` or `table_3d.gd`.

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
