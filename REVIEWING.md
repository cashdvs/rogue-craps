# Reviewing PRs: Dice of the Damned (repo: rogue-craps)

The reviewer (PM, with QA support) works through this checklist for every PR.
**AGENTS.md is the source of truth** for contributor rules (with CONTRIBUTING.md and
docs/MODULES.md). The contributor-facing summary of review and merge is CONTRIBUTING.md §4.
If this file disagrees with them, AGENTS.md wins and a follow-up PR fixes this file.

## Modules
"Module" means a **feature module in [docs/MODULES.md](docs/MODULES.md)**: 3D table, Dice physics,
Feel/juice, Betting/bet slots, Soul, Run structure, Dice bag, Table rules, Shop, Map/events, Bosses,
Embers, Dealer/taunts, UI, Shaders, Audio, Fonts, Art import, QA tests, Tools/CI. Use its "Owns" and
"Planned paths" columns to decide which module a file belongs to; MODULES.md wins if this list drifts.
- A module's own tests count as part of that module.
- **Shared files** (as in MODULES.md): `project.godot`, `run_tests.sh`, `.github/` (Tools / CI) and the
  tuning file `resources/tuning/poc_tuning.tres` with the defaults in `scripts/data/tuning_data.gd`
  (Game Designer's numbers). Adding a new `@export` to `TuningData` for the PR's module is fine and
  doesn't count as an extra module; changing an existing number needs the Game Designer's OK (escalate).
- `scripts/table/table_scene.gd` is touched by Feel, UI and Betting: keep edits small and say which part changed.

## 1. Gate checks (all must pass)
- [ ] **CI green:** the required `tests` check (`.github/workflows/ci.yml`) passes. Locally,
      `./run_tests.sh` exits 0 on the PR head in a clean worktree (it includes `tests/qa_/qa_*.gd`).
- [ ] Smoke runs, as in CI: `godot --headless --path . --quit-after 900` (main scene) and
      `godot --headless --path . res://scenes/bonfire.tscn --quit-after 300` print no script
      errors, warnings or crashes.
- [ ] No new `push_error`/`WARNING` output in the test run beyond what tests trigger on purpose.

## 2. Conformance
- [ ] Follows AGENTS.md (conventions, folder layout, PR rules) and fills in the PR template.
- [ ] Stays within the module(s) it claims (see Modules above).
- [ ] Behavior changes come with tests in `tests/test_*.gd` (scenes: smoke/input tests).
- [ ] `tests/qa_/` is QA's: you may add checks, but never loosen, skip or delete an existing one. (No loosened tolerances, deleted checks or skipped scripts.)
- [ ] Doesn't edit `docs/DESIGN.md` in a feature PR (open an issue instead).
- [ ] Small and focused: one concern, roughly ≤ 400 changed lines of code (excluding generated
      `.uid`/`.tres`/`.import`). Clean commit messages, no unrelated reformatting.

## 3. Gameplay and feel changes
- [ ] Play-check headlessly: scripted input like `tests/qa_/qa_input_edges.gd` and seeded sims like
      `tests/qa_/qa_craps_stats.gd`. Rule/odds changes: rerun the sim (within 3 SE of the expected rates).
- [ ] List in the review what still needs a human to play: flick thresholds, timings, shake/hit-stop,
      readability, audio, difficulty.

## 4. Outcome
- **Clean PR:** approve and merge. QA merges every PR, docs-only ones included.
  - **Julian's (@julian17874) and outside contributors' PRs: squash merge.** Review them to the
    same standard as the team's, with a welcoming tone.
  - **Team bots' PRs: rebase / fast-forward** (keeps their commits). If the branch contains merge
    commits, **squash** instead: a rebase merge drops them silently.
  - `main` stays linear: nothing lands on `main` with a merge commit. Merge commits are fine
    between stacked feature branches.
- **Author merge:** the only exception to "QA merges" is a typo or link fix
  of under about 10 lines, which its author may merge after QA approves. Anything in §5 is never
  self-merged.
- **Otherwise:** request changes. Every comment gives `file:line`, what is wrong, why, and a concrete fix.

## 5. Escalate to PM, do NOT merge, when a PR:
- changes core rules or balance: Soul formulas, payouts/odds, roll limits, targets, `TuningData`
  defaults or `resources/tuning/*.tres` (Game Designer's OK needed);
- touches **more than 2 feature modules** (per docs/MODULES.md, shared-file rule above);
- changes CI or repo config: `.github/` (workflows, CODEOWNERS, templates), `run_tests.sh`,
  `project.godot`, export presets, `.gitignore`, `LICENSE`, `AGENTS.md`, `CONTRIBUTING.md`,
  `docs/MODULES.md`, `docs/DESIGN.md`, `REVIEWING.md`;
- adds dependencies/addons/plugins, or very large assets (any file over about 20 MB). Binaries under
  that are fine when they're art or audio (PM ruling, Oct 19 2026).

## 6. Safety (any hit = request changes, and escalate if it looks deliberate)
- [ ] No secrets, tokens, keys or credentials (including in `.tres`, `.cfg` and export presets).
- [ ] No network, HTTP, telemetry, analytics or auto-update code (`HTTPRequest`, `StreamPeer*`,
      `OS.execute`/shell calls).
- [ ] No unexplained binaries or executables. Every asset has its source and a compatible license next
      to it (like `fonts/`), and the PR description credits it.
