#!/usr/bin/env bash
# Stamps the build version from version.cfg around an export:
#   - writes the git short sha into version.cfg (unless --no-sha: dev builds)
#   - sets Android version/code (major*10000 + minor*100 + patch, so it only
#     grows: 0.1.2 = 102) + version/name, Windows file_version +
#     product_version in export_presets.cfg, and config/version in project.godot
#   - prints the export file names
#   - runs the export command given after `--`, then restores the 3 tracked
#     files (version.cfg, export_presets.cfg, project.godot) from a backup via
#     `trap ... EXIT`, so the tree is clean again on success AND on failure.
#     The script exits with the export command's status.
# Usage:
#   tools/stamp_version.sh [--no-sha] [--public] -- <export command...>
#     e.g. tools/stamp_version.sh -- godot --headless --export-release "Android" \
#            build/DiceOfTheDamned-0.1.2-Android.apk
#   tools/stamp_version.sh [--no-sha] [--public] --stamp-only
#     stamps and leaves the files stamped: only for a throwaway copy/CI checkout.
#   --public: public release, writes dev_tools=false (no sandbox); beta
#     review builds omit it and keep version.cfg's dev_tools=true.
# STAMP_DIR / STAMP_SHA override the tree and the sha (tests).
set -euo pipefail
DIR="${STAMP_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
CFG="$DIR/version.cfg"
PRESETS="$DIR/export_presets.cfg"
FILES=("$CFG" "$PRESETS" "$DIR/project.godot")
use_sha=1
public=0
stamp_only=0
while [ $# -gt 0 ]; do
	case "$1" in
		--no-sha) use_sha=0; shift ;;
		--public) public=1; shift ;;
		--stamp-only) stamp_only=1; shift ;;
		--) shift; break ;;
		*) echo "stamp_version: unknown option $1 (export command goes after --)" >&2; exit 2 ;;
	esac
done
if [ $stamp_only -eq 0 ] && [ $# -eq 0 ]; then
	echo "usage: stamp_version.sh [--no-sha] -- <export command...> | --stamp-only" >&2
	exit 2
fi
mm=$(sed -n 's/^major_minor="\(.*\)"/\1/p' "$CFG")
patch=$(sed -n 's/^patch=\([0-9]*\)/\1/p' "$CFG")
[ -n "$mm" ] && [ -n "$patch" ] || { echo "stamp_version: bad $CFG" >&2; exit 1; }
ver="$mm.$patch"
IFS=. read -r major minor <<< "$mm"
code=$((major * 10000 + minor * 100 + patch))  # monotonic: 0.1.2 -> 102
sha="dev"
if [ $use_sha -eq 1 ]; then
	sha="${STAMP_SHA:-$(git -C "$DIR" rev-parse --short=7 HEAD 2>/dev/null || echo dev)}"
fi
if [ $stamp_only -eq 0 ]; then
	BACKUP=$(mktemp -d)
	for i in "${!FILES[@]}"; do cp -p "${FILES[$i]}" "$BACKUP/$i"; done
	restore() {
		for i in "${!FILES[@]}"; do cp -p "$BACKUP/$i" "${FILES[$i]}"; done
		rm -rf "$BACKUP"
	}
	trap restore EXIT
fi
sed -i "s/^sha=.*/sha=\"$sha\"/" "$CFG"
if [ $public -eq 1 ]; then
	if grep -q "^dev_tools=" "$CFG"; then sed -i "s/^dev_tools=.*/dev_tools=false/" "$CFG"; else echo "dev_tools=false" >> "$CFG"; fi
fi
sed -i "s/^version\/code=.*/version\/code=$code/; s/^version\/name=.*/version\/name=\"$ver\"/" "$PRESETS"
sed -i "s/^application\/file_version=.*/application\/file_version=\"$ver.0\"/; s/^application\/product_version=.*/application\/product_version=\"$ver.0\"/" "$PRESETS"
sed -i "s/^config\/version=.*/config\/version=\"$ver\"/" "$DIR/project.godot"
stem="DiceOfTheDamned-$ver"
echo "version $ver ($sha)"
echo "$stem-Windows.zip"
echo "$stem-Android.apk"
[ $stamp_only -eq 1 ] && exit 0
export STAMP_VERSION="$ver" STAMP_STEM="$stem" STAMP_DIR="$DIR"
"$@"
