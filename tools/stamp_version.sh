#!/usr/bin/env bash
# Stamps the build version from version.cfg before an export:
#   - writes the git short sha into version.cfg (unless --no-sha: dev builds)
#   - sets Android version/code + version/name, Windows file_version +
#     product_version in export_presets.cfg, and config/version in project.godot
#   - prints the export file names
# Usage: tools/stamp_version.sh [--no-sha]  (STAMP_DIR / STAMP_SHA override the tree and sha; tests)
set -euo pipefail
DIR="${STAMP_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
CFG="$DIR/version.cfg"
PRESETS="$DIR/export_presets.cfg"
mm=$(sed -n 's/^major_minor="\(.*\)"/\1/p' "$CFG")
patch=$(sed -n 's/^patch=\([0-9]*\)/\1/p' "$CFG")
[ -n "$mm" ] && [ -n "$patch" ] || { echo "stamp_version: bad $CFG" >&2; exit 1; }
ver="$mm.$patch"
sha="dev"
if [ "${1:-}" != "--no-sha" ]; then
	sha="${STAMP_SHA:-$(git -C "$DIR" rev-parse --short=7 HEAD 2>/dev/null || echo dev)}"
fi
sed -i "s/^sha=.*/sha=\"$sha\"/" "$CFG"
sed -i "s/^version\/code=.*/version\/code=$patch/; s/^version\/name=.*/version\/name=\"$ver\"/" "$PRESETS"
sed -i "s/^application\/file_version=.*/application\/file_version=\"$ver.0\"/; s/^application\/product_version=.*/application\/product_version=\"$ver.0\"/" "$PRESETS"
sed -i "s/^config\/version=.*/config\/version=\"$ver\"/" "$DIR/project.godot"
stem="DiceOfTheDamned-$ver"
echo "version $ver ($sha)"
echo "$stem-Windows.zip"
echo "$stem-Android.apk"
