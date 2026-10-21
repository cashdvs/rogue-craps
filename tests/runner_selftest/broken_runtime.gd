## Runner self-test fixture (run_tests.sh): deliberately broken. A runtime
## SCRIPT ERROR aborts the check function, yet the file exits 0 and prints a
## clean summary. The strict runner must still flag it. Not a real test: it
## lives outside the tests/test_*.gd glob and only the self-test runs it.
extends SceneTree


func _initialize() -> void:
	_checks()
	print("=== 0 passed, 0 failed ===")
	quit(0)


func _checks() -> void:
	var a: Array[int] = []
	var v: int = a[3]  # Out of bounds: SCRIPT ERROR, function aborts.
	print("unreachable ", v)
