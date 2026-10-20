## Runner self-test fixture (run_tests.sh): deliberately does not parse
## (undeclared identifier). The strict runner must flag the Parse Error.
extends SceneTree


func _initialize() -> void:
	print(not_declared_anywhere)
	quit(0)
