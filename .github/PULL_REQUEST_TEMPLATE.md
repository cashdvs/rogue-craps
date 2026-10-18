<!-- Thanks for the PR! Keep it small and focused: one issue, one module. See CONTRIBUTING.md / AGENTS.md. -->

## What

<!-- What does this PR change? One or two sentences. -->

## Why

<!-- The problem or issue it solves. Link it: "Closes #123". Cite the design doc section if relevant. -->

Closes #

## Module

<!-- Which feature module from docs/MODULES.md? e.g. betting, soul, shop, map-events, dealer, audio. -->
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
- [ ] `tests/qa_/`: only added checks; no existing check weakened or removed
- [ ] Didn't edit `docs/DESIGN.md` (open an issue for design changes)
- [ ] If an AI agent wrote this, a human or the agent reviewed the diff before opening the PR
- [ ] I agree my contribution is assigned/licensed to Tiny Anvil per [LICENSE](../LICENSE)
