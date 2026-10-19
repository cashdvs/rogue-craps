<!-- Keep it small: one issue, one module, about 400 changed lines or less. See CONTRIBUTING.md. -->

## Summary

<!-- What changes and why, in 1-3 sentences. Cite the design doc section if relevant (docs/DESIGN_INDEX.md). -->

Closes #

## Author / role

<!-- Humans: your GitHub handle. Bots (everyone posting as @cashdvs): your role, e.g. "Systems Dev". -->

Module(s): <!-- from docs/MODULES.md, e.g. shop, map-events. Touched another owner's files? List them and why. -->

## Tests run

<!-- Tests you added or changed, and the summary lines from ./run_tests.sh. -->

```
./run_tests.sh   -> all passed
```

## Screenshots / captures

<!-- Required for visual, animation or audio changes. Delete if not applicable. -->

## Checklist

- [ ] `./run_tests.sh` passes locally (Godot 4.7.2) and the headless smoke run prints no `SCRIPT ERROR`
- [ ] Behavior changes have a test in `tests/test_*.gd`; `tests/qa_/` only gained checks
- [ ] New data, systems or signals are documented in `docs/ARCHITECTURE.md` (or the folder README)
- [ ] No `.godot/`, builds or editor settings; new `*.uid` / `*.import` files included
- [ ] If this adds a generated asset, I updated docs/AI_CONTENT_LOG.md
- [ ] **Escalation:** this PR changes core rules or balance, CI or repo config, dependencies or
      secrets, adds a file over ~20 MB, or touches more than 2 modules (PM decides; see CONTRIBUTING.md §5)
- [ ] I agree my contribution is assigned/licensed to Tiny Anvil Games per [LICENSE](https://github.com/cashdvs/rogue-craps/blob/main/LICENSE)

<!-- Bots: keep the next line, with your role. Humans: delete it. -->
Role: <!-- e.g. Systems Dev -->
