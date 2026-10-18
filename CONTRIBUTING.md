# Contributing to Dice of the Damned

Thanks for helping! Dice of the Damned is a craps-style dice roguelite by **Tiny Anvil Games**, built
in Godot 4.7.2. We welcome PRs from people and from AI coding agents. Agents (and anyone driving
one) should also read [AGENTS.md](AGENTS.md), which has the technical details.

## 1. Setup

1. Install **Godot 4.7.2-stable** (standard build, not .NET). Get it from the
   [4.7.2-stable release](https://github.com/godotengine/godot/releases/tag/4.7.2-stable), or
   follow the headless Linux steps in [AGENTS.md §2](AGENTS.md#2-install-godot-472-headless-linux).
2. Fork the repo and clone your fork.
3. Import once, then run the tests:
   ```bash
   export GODOT=/path/to/godot      # run_tests.sh uses $GODOT
   "$GODOT" --headless --path . --import
   ./run_tests.sh
   ```
4. Play: `"$GODOT" --path .` or open the project in the Godot editor.
5. Read the design summary ([docs/DESIGN.md](docs/DESIGN.md)), especially the
   proof-of-concept scope, and skim [docs/MODULES.md](docs/MODULES.md).

## 2. Workflow

1. **Find or open an issue.** Starter tasks are labelled
   [`good first issue`](../../issues?q=is%3Aopen+label%3A%22good+first+issue%22). Each module has a
   `module:<name>` label.
2. **Say you're on it.** Comment on the issue; for bigger work, claim the module (§6).
3. **Branch** from `main`.
4. Make a **small, focused** change with tests.
5. Run `./run_tests.sh` locally. It must pass.
6. **Open a PR** to `main` and fill in the template. CI runs the same tests.
7. Address review comments by pushing more commits to the same branch.

### Branch naming

`<type>/<short-description>`, optionally with the issue number:

| Type | Use for |
|---|---|
| `feat/` | new gameplay or features (`feat/12-dealer-table-lines`) |
| `fix/` | bug fixes (`fix/odds-cap-rounding`) |
| `test/` | tests only |
| `docs/` | docs only |
| `chore/` | tooling, CI, cleanup |
| `art/`, `audio/` | asset work |

### Commit style

- Short imperative summary, ideally with the module: `dealer: add table_win lines`,
  `betting: pay Field 2 at 2:1`.
- One logical change per commit; explain *why* in the body if it isn't obvious.
- Update your branch by rebasing on `main`, not by merging `main` in (history stays linear).
- Reference issues with `#N`. Don't commit `.godot/`, builds or editor settings.

## 3. What makes a good PR

- Does one thing, linked to an issue (`Closes #N`).
- Stays inside one module's files (see [docs/MODULES.md](docs/MODULES.md)), or explains why not.
- Logic changes come with tests in `tests/test_*.gd`; `./run_tests.sh` passes.
- Static typing, beginner-friendly comments, logic in `scripts/core/` separate from views.
- Game numbers come from `resources/tuning/poc_tuning.tres` (`TuningData`), not hard-coded.
- Randomness goes through the seeded `DiceRoller`, so runs stay reproducible.
- Visual or audio changes include a screenshot, GIF or short capture.

## 4. Review

- Every PR needs **green CI** and **one approving review** from a maintainer before merge.
- Reviewers check scope, tests, determinism, typing and feel (for visual changes, we'll play it).
- The full reviewer checklist is in [REVIEWING.md](REVIEWING.md) (on `main`).
- History on `main` is **linear** (no merge commits):
  - **Outside contributor PRs are squash-merged.** Your PR becomes one commit, so make the PR
    title a good commit summary.
  - **Team PRs are merged with rebase or fast-forward**, keeping their individual commits.
  - Either way, update your branch by **rebasing** on `main`, not by merging `main` in.
- Aim for roughly ≤ 400 changed lines of code per PR (generated `.uid`/`.tres`/`.import` excluded).
- PRs that change core rules or balance (Soul formulas, payouts, tuning defaults), CI/repo config,
  or more than 2 modules are escalated to the Tiny Anvil Games team before merging.
- Feel and design calls belong to the Tiny Anvil Games team; we may ask you to put a change behind a
  tuning flag instead of changing default behaviour.

## 5. Docs and design changes

[docs/DESIGN.md](docs/DESIGN.md) is a public summary; the full design and art docs are
maintained by the Tiny Anvil Games team. Please don't edit `DESIGN.md` in a feature PR. Open an issue to
propose a design change or report a mistake. Changes to game numbers need the Game Designer's OK.

## 6. Claiming a module

The game is split into claimable feature modules (betting, Soul, run, dice bag, table rules,
shop, map/events, bosses, dealer, audio and more; some core modules take issues only). See [docs/MODULES.md](docs/MODULES.md) for paths,
status and owners.

1. Open a **Claim a module** issue (issue templates, "New issue").
2. Describe the first PR you plan and a rough timeline.
3. PM accepts it and updates `docs/MODULES.md`.
4. Claims with no activity for 14 days are released.

## 7. Code of conduct

Be kind, be specific, assume good faith. Harassment isn't tolerated. Maintainers may close PRs or
issues and block accounts that don't follow this.

## 8. License

This repository is **proprietary**: see [LICENSE](LICENSE). Copyright (c) 2026 Tiny Anvil Games
(Cash Davis). All rights reserved. In short:

- You may not use, copy, modify or distribute the code or assets without prior written permission
  from Tiny Anvil Games.
- Anything you submit (code, assets, docs) is **assigned to Tiny Anvil Games** on submission. Where an
  assignment isn't possible, you grant Tiny Anvil Games a perpetual, irrevocable, worldwide,
  royalty-free license to it, with the right to sublicense.
- You confirm you have the right to submit it (it's your own work, or you have permission, and
  any third-party asset's license allows it).

**Opening a pull request means you agree to these terms.** The PR template has a checkbox for it.

## Maintainers

### Recommended branch protection for `main`

These are recommendations; a maintainer applies them in **Settings → Branches** (or a ruleset).
They are not applied by any file in this repo.

- **Require a pull request before merging**
  - Required approvals: **1**
  - **Dismiss stale pull request approvals when new commits are pushed**: on
  - Require review from Code Owners: **off** for now. `@cashdvs` owns every path in CODEOWNERS
    and can't approve their own PRs, so turning this on would block team PRs opened from that account
  - Require conversation resolution before merging: on
  - Note: while `@cashdvs` is the only account with write access, PRs opened from it can't get
    an approval from anyone else. Either allow admins to bypass, or add a second reviewer
    account first.
- **Require status checks to pass before merging**: on
  - Required check: **`tests`** (job in workflow `CI`, `.github/workflows/ci.yml`; shown as
    "CI / tests")
  - Require branches to be up to date before merging: on
- **Block force pushes**: on (don't allow force pushes to `main`)
- **Restrict deletions**: on
- **Require linear history**: on. Squash merges (outside contributors) and rebase /
  fast-forward merges (team) both keep it linear; disable "Allow merge commits" in
  Settings → General.
- Do not allow bypassing the above settings: recommended once more than one maintainer exists
  (admins may need to bypass while only one GitHub account has access).

### Merging and claims

- Squash-merge outside contributor PRs; rebase or fast-forward team PRs. Never a merge commit.
- Check the PR's license checkbox is ticked before merging an outside contribution.
- When accepting a module claim, update `docs/MODULES.md` and, if the claimant will review that
  area, uncomment/add a line in `.github/CODEOWNERS`.
- Keep `docs/DESIGN.md` in step with the team's living design doc when the public-facing basics
  change (no internal names or process notes).
