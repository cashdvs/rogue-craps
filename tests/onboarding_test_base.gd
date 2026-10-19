## Shared helpers for the onboarding hint tests (not a test itself: the
## test_onboarding_*.gd files extend it).
extends SceneTree

var _passed: int = 0
var _failed: int = 0
var t: BonfireTuning


func check(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		print("FAIL  ", what)


func make_table(tutorial: int = 1, setup: TableSetup = null) -> Bonfire3D:
	var st := setup if setup != null else TableSetup.sandbox(t, 5)
	st.table_seed = 7
	var s := (load("res://scenes/bonfire.tscn") as PackedScene).instantiate() as Bonfire3D
	s.setup = st
	s.tutorial_override = tutorial
	s.test_speed = 10.0
	root.add_child(s)
	await process_frame
	await process_frame
	return s


func ready_to_throw(s: Bonfire3D) -> void:
	for k in 600:
		if s.phase == Table3D.Phase.BET and not s.bhud.countup.is_playing() and not s.hand_moving() and s.run.state == BonfireRun.State.AIM:
			return
		await process_frame


## Throws (rigged if faces is given, else whatever the seeds say).
func throw(s: Bonfire3D, faces: Array[int] = []) -> Array[int]:
	await ready_to_throw(s)
	if not faces.is_empty():
		s.rig_faces(faces)
	if not s.quick_throw():
		check(false, "throw starts")
		return []
	await s.throw_resolved
	await s.sequence_finished
	return s.run.throw_faces.duplicate()


func wait_bet(s: Bonfire3D) -> void:
	for k in 600:
		if s.phase == Table3D.Phase.BET and not s.bhud.countup.is_playing():
			return
		await process_frame


func pick_faces(s: Bonfire3D, want: Array) -> void:
	var left := want.duplicate()
	for i in s.run.throw_faces.size():
		var v := int(s.run.throw_faces[i])
		if left.has(v):
			left.erase(v)
			s.pick_die(i)


func close_all(s: Bonfire3D) -> void:
	for k in 20:
		if s.bhud.tutorial.current == &"":
			return
		s.bhud.tutorial.dismiss()


## A hints-only table (not the run's first: no TH flow, JIT / HB / HS only).
func hints_table(st: TableSetup) -> Bonfire3D:
	st.first_table = false
	return await make_table(1, st)
