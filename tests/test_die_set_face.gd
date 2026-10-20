## DieVisual.set_face (Nerve, nerve_v1.md): a settled die turns to any face
## slot. A d6 by its FACE_AXES, a hull die (d8, d20) by its face directions;
## animate = false snaps at once (reduced motion / Instant speed), animate =
## true tweens and ends on the same face. The die itself doesn't move.
##   godot --headless --path . --script res://tests/test_die_set_face.gd
extends SceneTree

var _passed: int = 0
var _failed: int = 0


func _initialize() -> void:
	_run.call_deferred()


func check(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		print("FAIL  ", what)


func make_die(shape: StringName, pose: Basis) -> DieVisual:
	var d := DieVisual.new()
	d.shape = shape
	root.add_child(d)
	d.global_transform = Transform3D(pose, Vector3(0.1, 0.04, -0.2))
	return d


func _run() -> void:
	var pose := Basis(Vector3(0.3, 1, 0.2).normalized(), 0.9)
	# d6: snap to every face; the die's own pose and place stay put.
	var d6 := make_die(&"d6", pose)
	var ok := true
	for slot in range(1, 7):
		d6.set_face(slot, false)
		ok = ok and d6.up_slot() == slot
	check(ok, "d6: set_face(slot, false) shows every slot 1..6 on top")
	check(d6.global_transform.basis.is_equal_approx(pose) and d6.global_position.is_equal_approx(Vector3(0.1, 0.04, -0.2)), "d6: the die body doesn't move")
	# Non-d6 dice (hull face directions).
	for shape: StringName in [&"d8", &"d20", &"d4"]:
		if not PolyDie.has_shape(shape):
			continue
		var p := make_die(shape, pose)
		var n := PolyDie.dirs(shape).size()
		var all := true
		for slot in range(1, n + 1):
			p.set_face(slot, false)
			all = all and p.up_slot() == slot
		check(all, "%s: set_face shows every slot 1..%d on top" % [shape, n])
		p.queue_free()
	# Animated: ends on the face, and a second call replaces the first.
	d6.set_face(2, true)
	d6.set_face(5, true)
	check(d6.face_tween != null and d6.face_tween.is_valid(), "animated: a tween runs")
	await create_timer(DieVisual.FACE_TURN_TIME + 0.2).timeout
	check(d6.up_slot() == 5, "animated: lands on the last face asked (%d)" % d6.up_slot())
	var q := d6.set_face(3, false)
	check(d6.faces.quaternion.is_equal_approx(q) and d6.up_slot() == 3, "snap: returns the final faces rotation")
	print("die_set_face: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)
