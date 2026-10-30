#!/usr/bin/env bash
# Stamps the build version from version.cfg before an export:
#   - writes the git short sha into version.cfg (unless --no-sha: dev builds)
#   - sets Android version/code (major*10000 + minor*100 + patch, so it only
#     grows: 0.1.2 = 102) + version/name, Windows file_version +
#     product_version in export_presets.cfg, and config/version in project.godot
#   - prints the export file names
# Usage: tools/stamp_version.sh [--no-sha]  (STAMP_DIR / STAMP_SHA override the tree and sha; tests)
#
# WARNING: stamping edits 3 tracked files (version.cfg, export_presets.cfg,
# project.godot). Never commit a stamped tree: export from a fresh worktree,
# or run `git checkout -- version.cfg export_presets.cfg project.godot` after.
set -euo pipefail
DIR="${STAMP_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
CFG="$DIR/version.cfg"
PRESETS="$DIR/export_presets.cfg"
mm=$(sed -n 's/^major_minor="\(.*\)"/\1/p' "$CFG")
patch=$(sed -n 's/^patch=\([0-9]*\)/\1/p' "$CFG")
[ -n "$mm" ] && [ -n "$patch" ] || { echo "stamp_version: bad $CFG" >&2; exit 1; }
ver="$mm.$patch"
IFS=. read -r major minor <<< "$mm"
code=$((major * 10000 + minor * 100 + patch))  # monotonic: 0.1.2 -> 102
sha="dev"
if [ "${1:-}" != "--no-sha" ]; then
	sha="${STAMP_SHA:-$(git -C "$DIR" rev-parse --short=7 HEAD 2>/dev/null || echo dev)}"
fi
sed -i "s/^sha=.*/sha=\"$sha\"/" "$CFG"
sed -i "s/^version\/code=.*/version\/code=$code/; s/^version\/name=.*/version\/name=\"$ver\"/" "$PRESETS"
sed -i "s/^application\/file_version=.*/application\/file_version=\"$ver.0\"/; s/^application\/product_version=.*/application\/product_version=\"$ver.0\"/" "$PRESETS"
sed -i "s/^config\/version=.*/config\/version=\"$ver\"/" "$DIR/project.godot"
stem="DiceOfTheDamned-$ver"
echo "version $ver ($sha)"
echo "$stem-Windows.zip"
echo "$stem-Android.apk"
