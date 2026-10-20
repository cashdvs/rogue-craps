#!/usr/bin/env bash
# Runs every headless test in tests/test_*.gd. Exit code is non-zero if any fails.
# QA checks in tests/qa_/qa_*.gd also run (known-failing ones live in tests/qa_/known_failing/, not run).
# Strict: a test also fails if its output has any "SCRIPT ERROR" or "Parse Error" (a runtime or
# parse error can abort a test function and silently skip its checks while the file still exits 0).
# Plain "ERROR:" lines are still allowed: some tests feed bad input on purpose.
# The runner first checks itself: tests/runner_selftest/*.gd are deliberately broken fixtures
# (outside the test_*.gd glob) and each must be flagged, or the run fails.
set -uo pipefail
GODOT="${GODOT:-/home/box/tools/godot/godot}"
DIR="$(cd "$(dirname "$0")" && pwd)"
STRICT_PATTERN='SCRIPT ERROR|Parse Error'

# run_one <res path> <label>: runs one test, streams its output, returns non-zero if it failed
# (non-zero exit, or a SCRIPT ERROR / Parse Error line, reported with the file it came from).
run_one() {
	local res="$1" label="$2" out rc=0
	out="$(mktemp)"
	"$GODOT" --headless --path "$DIR" --script "$res" >"$out" 2>&1 || rc=$?
	cat "$out"
	if grep -Eq "$STRICT_PATTERN" "$out"; then
		echo "### $label: script errors (strict runner):"
		grep -En "$STRICT_PATTERN" "$out" | sed "s|^|###   $label: |"
		[ "$rc" -eq 0 ] && rc=1
	fi
	rm -f "$out"
	return "$rc"
}

# Import first so class_name scripts are registered (needed on a fresh checkout).
"$GODOT" --headless --path "$DIR" --import >/dev/null 2>&1 || true

status=0
echo "### runner self-test"
for fixture in "$DIR"/tests/runner_selftest/*.gd; do
	[ -e "$fixture" ] || { echo "### runner self-test FAILED: no fixtures"; status=1; break; }
	name="$(basename "$fixture")"
	if run_one "res://tests/runner_selftest/$name" "runner_selftest/$name" >/dev/null 2>&1; then
		echo "### runner self-test FAILED: broken fixture $name was not flagged"
		status=1
	else
		echo "### runner self-test: $name flagged (ok)"
	fi
done

for test in "$DIR"/tests/test_*.gd; do
	name="$(basename "$test")"
	echo "### $name"
	if ! run_one "res://tests/$name" "$name"; then
		echo "### $name FAILED"
		status=1
	fi
done
for test in "$DIR"/tests/qa_/qa_*.gd; do
	name="$(basename "$test")"
	echo "### qa_/$name"
	if ! run_one "res://tests/qa_/$name" "qa_/$name"; then
		echo "### qa_/$name FAILED"
		status=1
	fi
done
exit $status
