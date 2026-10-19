## Headless tests for RunningTotal (single-die running total + stop).
##   godot --headless --path . --script res://tests/test_running_total.gd
extends SceneTree

var _failed: int = 0
var _passed: int = 0


func check(cond: bool, label: String) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		print("FAIL  ", label)


func _initialize() -> void:
	var rt := RunningTotal.new(12)
	var changes: Array[int] = []
	rt.total_changed.connect(func(t: int, _a: int) -> void: changes.append(t))
	var stops: Array[int] = []
	rt.stopped.connect(func(t: int, h: Array[Dictionary]) -> void:
		stops.append(t)
		check(h.size() == 3 and h[0]["die"] == "Bone" and h[2]["value"] == 6, "stopped carries the throw history"))
	check(rt.stop() == 0 and stops.is_empty(), "stop with nothing thrown does nothing")
	check(rt.add(4, "Bone") == 4, "first die sets the total")
	check(rt.add(1, "Bone") == 5 and rt.count() == 2, "second die adds")
	check(rt.distance_to_line() == -7 and not rt.is_over_line(), "under the line")
	rt.add(6, "Ember")
	check(rt.total == 11 and changes == [4, 5, 11], "total_changed per throw")
	check(rt.stop() == 11 and stops == [11], "stop returns and emits the final total")
	check(rt.total == 0 and rt.count() == 0, "stop starts a fresh total")
	rt.add(6)
	rt.add(6)
	rt.add(1)
	check(rt.is_over_line() and rt.distance_to_line() == 1, "over the line")
	rt.reset()
	check(rt.total == 0 and rt.throws.is_empty(), "reset clears")
	print("test_running_total: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)
