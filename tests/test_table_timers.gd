## Table timers stop when the table leaves the tree (issue #128): a wait that
## is still running when the table is removed never wakes up afterwards, and
## the list of live timers is emptied.
##   godot --headless --path . --script res://tests/test_table_timers.gd
extends SceneTree

var _passed: int = 0
var _failed: int = 0
## Set by _slow_wait() if its wait ever finishes.
var _woke: bool = false


func _initialize() -> void:
	_run.call_deferred()


func check(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		print("FAIL  ", what)


## Waits on the table's own timer, then records that it woke up.
func _slow_wait(t: Table3D, seconds: float) -> void:
	await t._wait(seconds)
	_woke = true


func _run() -> void:
	var t := (load("res://scenes/bonfire.tscn") as PackedScene).instantiate() as Table3D
	root.add_child(t)
	await process_frame
	# 1. A short wait finishes normally while the table is in the tree.
	_woke = false
	_slow_wait(t, 0.05)
	await create_timer(0.3).timeout
	check(_woke, "a wait finishes while the table is in the tree")
	# 2. A wait still running when the table leaves never wakes up.
	_woke = false
	_slow_wait(t, 0.3)
	check(not t._timers.is_empty(), "the running wait is tracked")
	root.remove_child(t)
	check(t._timers.is_empty(), "leaving the tree clears the timers")
	await create_timer(0.6).timeout
	check(not _woke, "the wait never wakes after the table left the tree")
	t.free()
	print("test_table_timers: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)
