<!-- Thanks for the PR! Keep it small and focused: one issue, one module. See CONTRIBUTING.md / AGENTS.md. -->

## What

<!-- What does this PR change? One or two sentences. -->

## Why

<!-- The problem or issue it solves. Link it: "Closes #123". Cite the design doc section if relevant. -->

Closes #

## Module

<!-- Which module from docs/MODULES.md? e.g. dealer, betting, soul, dice-physics, ui, audio. -->
<!-- If you touched another module's files, list them and say why. -->

## Tests

<!-- Which tests did you add or change? Paste the summary lines from ./run_tests.sh. -->

```
=== N passed, 0 failed ===
```

## Screenshots / captures

<!-- Required for visual, animation or audio changes (screenshot, GIF, or short video). Delete if not applicable. -->

## Checklist

- [ ] `./run_tests.sh` passes locally (Godot 4.7.2)
- [ ] Logic changes have tests in `tests/test_*.gd`
- [ ] Changes stay within one module (or the PR explains why not)
- [ ] Static typing used; comments explain the *why* for beginners
- [ ] Game logic in `scripts/core/`, kept out of scenes/views
- [ ] No hard-coded game numbers (tuning lives in `resources/tuning/poc_tuning.tres` / `TuningData`)
- [ ] Randomness goes through the seeded `DiceRoller` (determinism kept)
- [ ] No `.godot/` folder, builds or editor settings committed; new `*.uid` / `*.import` files included
- [ ] Didn't edit `docs/design/`, `docs/art/` (mirrors) or `tests/qa_/` (QA-owned)
- [ ] If an AI agent wrote this, a human or the agent reviewed the diff before opening the PR
