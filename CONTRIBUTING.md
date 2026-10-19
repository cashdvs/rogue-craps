# Contributing to Dice of the Damned

Welcome! This is the one page you need to go from "cloned the repo" to "PR merged". It's for
humans (like Julian) and for the team's AI agents. Setup is in [README.md](README.md#start-here);
how the code fits together is in [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md). Agents also read
[AGENTS.md](AGENTS.md) (coding conventions, tooling).

## 1. Pick or claim work

1. **Find an issue.** Starter tasks: label
   [`good first issue`](https://github.com/cashdvs/rogue-craps/issues?q=is%3Aopen+label%3A%22good+first+issue%22).
   Every issue should carry a `module:<id>` label (module list: [docs/MODULES.md](docs/MODULES.md);
   current file map: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md#module-map)).
2. **Say you're on it.** Comment "I'm taking this" on the issue (and assign yourself if you have
   write access) so nobody duplicates it.
3. **Bigger work = claim the module.** Open a **Claim a module** issue (template, label
   `module-claim`) with your first PR and a rough timeline. PM accepts it and updates
   `docs/MODULES.md`. Claims with no activity for 14 days are released.
4. **No issue yet?** Open one first (Bug or Feature template). Don't start on core rules or
   balance without one (see §5).

## 2. Branch, change, test

- **Branch from `main`** (people with write access, like Julian, branch in this repo; others fork).
  Name it `<type>/<short-description>`, optionally with the issue number:

  | Type | Use for |
  |---|---|
  | `feat/` | new gameplay or features (`feat/42-shop-tooltips`) |
  | `fix/` | bug fixes (`fix/event-greyed-reason`) |
  | `docs/` | docs only |
  | `ci/` | CI and repo tooling (`.github/`, `run_tests.sh`; needs PM, §5) |
  | `test/` | tests only |
  | `chore/` | cleanup, renames |
  | `art/`, `audio/` | asset work |

- **Keep PRs small:** one issue, one module, about **400 changed lines of code or less**
  (generated `.uid` / `.tres` / `.import` don't count). Split bigger work into a series.
- **Tests are required** for any behavior change: add or extend a headless test in
  `tests/test_*.gd` (a new file with that name runs automatically). Copy the pattern of the file
  you extend (`_check(...)` or `check(...)`, then `quit(1 if _failed > 0 else 0)`). Seed anything random.
- `tests/qa_/` is QA's: you may add checks, but never loosen, skip or delete an existing one.
- **Run it locally** before you push: `./run_tests.sh` must exit 0, and a smoke run of the table
  (`"$GODOT" --headless --path . res://scenes/bonfire.tscn --quit-after 300`) must print no
  `SCRIPT ERROR`.
- Commit the `*.uid` files Godot makes next to new scripts and the `*.import` files next to new
  assets. Never commit `.godot/`, builds or editor settings.
- **AI content log:** every PR that adds or replaces anything players see or hear that agents made
  or scripted (art, models, textures, shaders, audio, in-game text; script-built assets count too)
  adds or updates its row in [docs/AI_CONTENT_LOG.md](docs/AI_CONTENT_LOG.md) (asset path, tool,
  what it was used for, date, owner). Steam's content survey requires this disclosure; the log's
  "Policy: broad disclosure" section has the rules (PM ruling, Oct 19 2026).

## 3. Open the PR, pass CI

- Open a PR against `main` and fill in the template (summary, role/author, tests run,
  screenshots, escalation checkbox). Link the issue with `Closes #N`.
- **CI** (`.github/workflows/ci.yml`, required check **`tests`**) runs on every PR, with
  Godot 4.7.2 headless:
  1. **Import** the project; fails on any `SCRIPT ERROR` / `Parse Error`.
  2. **`./run_tests.sh`**: every `tests/test_*.gd` and `tests/qa_/qa_*.gd`.
  3. **Main scene smoke test**: 900 frames from the boot splash.
  4. **Table scene smoke test**: `scenes/bonfire.tscn` for 300 frames.
- Visual or audio changes need a screenshot, GIF or short capture (`tools/capture_*.gd`).

## 4. Review and merge

- **Asking for review:** open a PR against `main` and mark it "Ready for review" (drafts aren't reviewed). Fill in the PR template, name the module(s) from docs/MODULES.md, and say how you tested it. QA picks up ready PRs; you don't need to ping anyone.
- **What QA checks:** CI's `tests` check is green; `./run_tests.sh` passes; the PR stays inside the module(s) it claims; behavior changes have a test that fails without them; names are clear; public functions and signals have `##` doc comments; scripts stay under ~400 lines and the PR is around 400 changed lines of code or less; new data, systems or signals are documented in docs/ARCHITECTURE.md or the folder README. A PR that would confuse a newcomer gets "changes requested", even if it works.
- `tests/qa_/` is QA's: you may add checks, but never loosen, skip or delete an existing one.
- **What blocks a merge:** red CI, failing tests, script errors in the headless smoke run, missing tests, out-of-scope changes, secrets or network code, and unlicensed assets. Rules or balance changes, PRs touching more than 2 modules, CI or repo config, and new dependencies go to PM, who decides before anything merges.
- **Who merges:** QA merges every PR, docs-only ones included; auto-merge isn't used. The one exception: a typo or link fix of under about 10 lines may be merged by its author once QA has approved it (PM ruling, Oct 19 2026).
- **Merge method:** `main` keeps a linear history: anything landing on `main` is squashed or rebased, never merged with a merge commit. Team PRs are merged by rebase (commits kept) unless the branch contains merge commits, in which case they're squashed. **Julian's (@julian17874) PRs and outside contributors' PRs are squash-merged**, whatever their commit history looks like, so you don't need to tidy your commits. QA reviews them to the same standard as the team's, with a welcoming tone.
- **Stacked PRs:** a rebase merge rewrites commit IDs, so a PR based on another unmerged PR will conflict once that one lands. Base on `main` when you can. If you must stack, say so in the PR; QA merges the stack top-down into each base branch and puts the bottom PR into `main` last.
- **Branches containing merge commits are squash-merged (never rebase-merged, since that silently drops them).** This lost the table integration in #21–#23. Inside a stack, merge commits between feature branches are fine.
- **Fixing review comments:** push new commits to the same branch. To update a branch you've already pushed, merge `main` in; don't rebase it (§6).

## 5. What gets escalated (PM decides)

The reviewer won't merge these alone; they go to the **PM**, whose answer is final (Cash has
delegated approvals to PM). Say so in the PR (template checkbox) so it's flagged early:

- **Core rules or balance:** scoring, Soul, Embers, prices, hands, bounties, tuning numbers
  (`resources/tuning/*.tres`, floor and run `.tres`). These numbers come from the Game Designer.
- **CI and repo config:** `.github/`, `run_tests.sh`, `project.godot`, export presets,
  `.gitignore`, `LICENSE`, and the contributor docs (this file, AGENTS.md, REVIEWING.md,
  docs/MODULES.md, docs/DESIGN.md).
- **Dependencies or secrets:** any new addon, plugin or library; anything that looks like a key,
  token or network call (those are refused outright).
- **Big assets:** any file over **~20 MB** (smaller art/audio binaries are fine with a source and
  license note; see [REVIEWING.md §5](REVIEWING.md)).
- **PRs touching more than 2 feature modules.**

### Exports

`export_presets.cfg` is repo config (PM decides). It sets company and publisher **"Tiny Anvil
Games"**, product name **"Dice of the Damned"**, and copyright **"© 2026 Tiny Anvil Games"**; keep
those when you touch it. Never put signing keys or passwords in it. Steam release status, the export
CI job and open items are in [docs/STEAM_READINESS.md](docs/STEAM_READINESS.md); AI disclosure is in
[docs/AI_CONTENT_LOG.md](docs/AI_CONTENT_LOG.md).

## 6. Commit and PR conventions

- **Commit subject:** short, imperative, prefixed with the module or area:
  `shop: show the reroll price on the button`, `events: test greyed-out choices`.
  Explain *why* in the body when it isn't obvious. One logical change per commit.
- **Updating your branch:** once a branch is pushed, update it by merging `main` in; don't rebase
  it. Merge commits are fine on feature branches; the PR is then squashed when it lands on `main`
  (§4). Before your first push you may rebase freely. Never force-push without approval (§7).
- **PR title** = a good commit subject (outside PRs are squash-merged into it).
- **PR body:** the template. Bots end it with a role line (§7).

## 7. Humans and bots

The team is Cash (owner), a few humans with write access (like Julian) and several AI agents
(PM, QA Tester, Godot Dev, Systems Dev, Game Designer, VFX Dev, Sound Designer, Art Director,
3D Artist).

- **Bots all post as `@cashdvs`**, so GitHub can't tell them apart. A bot **signs its role** on
  the last line of every PR body and review comment, e.g. `Role: Systems Dev`. Humans just fill
  in the "Author" line of the template.
- **Never change the shared repo's git config.** Agents share one clone on the studio box (the
  main checkout and all its worktrees share one `.git/config`), so `git config user.name`
  there changes every agent's author. Commit as `cashdvs <cashdvs@users.noreply.github.com>`
  (the shared default). If you need a different identity for one command, use
  `git -c user.name=... -c user.email=... commit`, never `git config` (PM ruling, Oct 19 2026).
- **Nobody pushes to `main`.** Everything lands through a reviewed PR.
- **No force-push without approval.** Never force-push `main`, a branch someone else owns, or a
  branch other PRs are stacked on, without PM's OK. Pushed branches are updated by merging `main`
  in (§6), so routine work never needs a force-push.
- **QA merges every PR**, bots' docs-only PRs included ([REVIEWING.md §4](REVIEWING.md)). Only a
  typo or link fix of under about 10 lines may be merged by its author, after QA approves; anything
  in §5 never self-merges.
- **Stay in your lane:** ask the owner (see [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md#who-owns-what))
  before editing their files; say why in the PR if you had to.
- Human or bot, **if you're unsure, open a draft PR early and ask.**

## 8. Code of conduct

Be kind, be specific, assume good faith. Harassment isn't tolerated. Maintainers may close PRs or
issues and block accounts that don't follow this.

## 9. License

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

## Maintainers: recommended branch protection for `main`

These are recommendations; a maintainer applies them in **Settings → Branches** (or a ruleset).
No file in this repo applies them.

- **Require a pull request before merging**, 1 approval, dismiss stale approvals on new commits,
  require conversation resolution. Code-owner review stays **off**: `@cashdvs` owns every path
  in CODEOWNERS and can't approve its own PRs. With a second account (e.g. `julian17874`) it
  becomes possible to require approvals from someone other than the author.
- **Require status checks:** `tests` (workflow `CI`), branches up to date.
- **Block force pushes** and **restrict deletions** on `main`.
- **Require linear history:** squash (Julian's and outside PRs, and team PRs with merge commits)
  and rebase (other team PRs) both keep it linear.
  Linear history only binds `main`: a stack whose branches contain merge commits is merged with
  merge commits into its base branches, and the bottom PR is then squashed into `main`, as for
  #20 (PM ruling, Oct 19 2026).
- When accepting a module claim, update `docs/MODULES.md` and, if the claimant will review that
  area, add their handle in `.github/CODEOWNERS`.
