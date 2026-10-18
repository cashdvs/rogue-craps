#!/usr/bin/env bash
# Runs every headless test. Exit code is non-zero if any test fails.
set -euo pipefail
GODOT="${GODOT:-/home/box/tools/godot/godot}"
DIR="$(cd "$(dirname "$0")" && pwd)"
# First import so class_name scripts are registered (needed on a fresh checkout).
"$GODOT" --headless --path "$DIR" --import >/dev/null 2>&1 || true
"$GODOT" --headless --path "$DIR" --script res://tests/test_craps_rules.gd
"$GODOT" --headless --path "$DIR" --script res://tests/test_main_scene.gd
"$GODOT" --headless --path "$DIR" --script res://tests/qa_/qa_craps_stats.gd
