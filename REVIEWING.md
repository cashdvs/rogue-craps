# Reviewing PRs: Dice of the Damned (repo: rogue-craps)

The reviewer (PM, with QA support) works through this checklist for every PR. Contributor rules live in
**AGENTS.md**; if this file and AGENTS.md disagree, AGENTS.md wins and a follow-up PR fixes this file.

> Assumptions (AGENTS.md was not in the repo or any branch when this was written): module names come
> from the README "Layout" section, tests follow the existing `tests/test_*.gd` / `tests/qa_/qa_*.gd`
> convention, and history is linear (no merge commits). Re-align once AGENTS.md lands.

## Modules (for "stays in its module" and the 2-module rule)
`scripts/core` (pure rules) · `scripts/data` (+ `resources/`) · `scripts/table` (POC table scene) ·
`scripts/table3d` · `scripts/audio` · `scripts/ui` (greybox) · `shaders/` · `tools/` · `tests/`.
Tests for the module being changed don't count as a second module.

## 1. Gate checks (all must pass)
- [ ] CI is green, if a workflow exists (there's no `.github/workflows` yet, so the local run is the gate).
- [ ] On the PR head, in a clean worktree: `./run_tests.sh` exits 0, including `tests/qa_/qa_*.gd`.
- [ ] `godot --headless --path . --quit-after 300` prints no script errors, warnings or crashes.
- [ ] No new `push_error`/`WARNING` output in the test run beyond what tests trigger on purpose.

## 2. Conformance
- [ ] Follows AGENTS.md (naming, layout, commit/PR rules).
- [ ] Stays within the module(s) the PR description claims.
- [ ] Behavior changes come with tests: rules → `tests/test_*.gd`; scenes → scene smoke/input tests.
      `tests/qa_/` belongs to QA; contributors may add to it but not weaken existing checks.
- [ ] Small and focused: one concern, roughly ≤ 400 changed lines of code (excluding generated
      `.uid`/`.tres`/`.import` files). Larger PRs get split unless AGENTS.md says otherwise.
- [ ] Commit messages say what changed and why. No unrelated reformatting.

## 3. Gameplay and feel changes
- [ ] Play-check headlessly: scripted input like `tests/qa_/qa_input_edges.gd` (real InputEvents via
      `Input.parse_input_event`) and seeded sims like `tests/qa_/qa_craps_stats.gd`.
- [ ] Rule/odds changes: rerun the seeded sim; results stay within 3 SE of the expected rates.
- [ ] List in the review what still needs a human to play: flick thresholds, timings, shake/hit-stop,
      readability, audio, difficulty curve.

## 4. Outcome
- **Clean PR:** approve, then merge with **rebase / fast-forward** (history is linear, no merge commits).
- **Otherwise:** request changes. Every comment gives `file:line`, what is wrong, why, and a concrete fix.

## 5. Escalate to PM, do NOT merge, when a PR:
- changes core rules or balance: Soul formulas, payouts/odds, roll limits, targets, `tuning_data.gd`
  defaults or `resources/tuning/*.tres`;
- touches more than 2 modules (see the list above);
- changes CI or repo config: workflows, `run_tests.sh`, `project.godot`, export presets, `.gitignore`,
  `AGENTS.md`, `REVIEWING.md`;
- adds dependencies/addons/plugins, or large assets (> 1 MB per file, or any binary).

## 6. Safety (any hit = request changes, and escalate if it looks deliberate)
- [ ] No secrets, tokens, keys or credentials (including in `.tres`, `.cfg` and export presets).
- [ ] No network, HTTP, telemetry, analytics or auto-update code (`HTTPRequest`, `StreamPeer*`, `OS.shell_*`/`OS.execute`).
- [ ] No unexplained binaries or executables. Every asset has its source and a compatible license
      next to it (like `fonts/`), and the PR description credits it.
