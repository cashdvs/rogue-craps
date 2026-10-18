#!/usr/bin/env bash
# Runs every headless test in tests/test_*.gd. Exit code is non-zero if any fails.
# QA checks in tests/qa_/qa_*.gd also run (known-failing ones live in tests/qa_/known_failing/, not run).
set -uo pipefail
GODOT="${GODOT:-/home/box/tools/godot/godot}"
DIR="$(cd "$(dirname "$0")" && pwd)"
# Import first so class_name scripts are registered (needed on a fresh checkout).
"$GODOT" --headless --path "$DIR" --import >/dev/null 2>&1 || true
status=0
for test in "$DIR"/tests/test_*.gd; do
	name="$(basename "$test")"
	echo "### $name"
	if ! "$GODOT" --headless --path "$DIR" --script "res://tests/$name"; then
		echo "### $name FAILED"
		status=1
	fi
done
for test in "$DIR"/tests/qa_/qa_*.gd; do
	name="$(basename "$test")"
	echo "### qa_/$name"
	if ! "$GODOT" --headless --path "$DIR" --script "res://tests/qa_/$name"; then
		echo "### qa_/$name FAILED"
		status=1
	fi
done
exit $status
