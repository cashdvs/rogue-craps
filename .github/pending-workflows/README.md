# Pending workflow

`ci.yml` here is the CI workflow for this repo. It couldn't be pushed straight to
`.github/workflows/` because the automation token that opened this PR lacks GitHub's `workflow`
scope. A maintainer activates it with:

```bash
gh auth refresh -h github.com -s workflow   # once, interactive
git mv .github/pending-workflows/ci.yml .github/workflows/ci.yml
git rm .github/pending-workflows/README.md
git commit -m "ci: activate Godot 4.7.2 headless test workflow" && git push
```

Until it's in `.github/workflows/`, GitHub doesn't run it and the README badge shows no status.
