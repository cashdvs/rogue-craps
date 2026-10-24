## SelectionDimFx (Julian playtest bug): lit dice that can't join the
## selected combo dim to the plain look; joinable ones keep glowing.
##   godot --headless --path . --script res://tests/test_fx_selection_dim.gd
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


class FakeRun:
	extends RefCounted
	var asked: Array = []
	func can_join(i: int) -> bool:
		asked.append(i)
		return i == 1


func _run() -> void:
	var t := load("res://resources/tuning/bonfire_tuning.tres") as BonfireTuning
	# Prefers Godot Dev's run.can_join flag when it exists.
	var fr := FakeRun.new()
	check(SelectionDimFx.joinable(fr, 1) and not SelectionDimFx.joinable(fr, 2), "uses run.can_join")
	check(fr.asked == [1, 2], "can_join asked per die")

	var sv := SubViewport.new()
	sv.size = Vector2i(1280, 720)
	root.add_child(sv)
	var st := TableSetup.sandbox(t, 5)
	st.table_seed = 5
	var s := (load("res://scenes/bonfire.tscn") as PackedScene).instantiate() as Bonfire3D
	s.setup = st
	s.tutorial_override = 0
	s.test_speed = 10.0
	sv.add_child(s)
	await process_frame
	await process_frame
	var fx: SelectionDimFx = null
	for c in s.get_children():
		if c is SelectionDimFx:
			fx = c
	check(fx != null, "table hosts a SelectionDimFx")
	if fx == null:
		_finish()
		return
	var faces: Array[int] = [3, 3, 3, 5, 2]
	s.rig_faces(faces)
	check(s.quick_throw(), "throw starts")
	await s.throw_resolved
	await s.sequence_finished
	for k in 400:
		if s.phase == Table3D.Phase.BET and not s.bhud.countup.is_playing():
			break
		await process_frame
	var five := s.throw_dice[3]
	var three := s.throw_dice[1]
	check(s.is_lit(five) and s.is_lit(three), "3s and the 5 are lit")
	await process_frame
	check(fx.dim_indices().is_empty(), "nothing dims with no selection")
	check(five.glow_lit > 0.5, "the 5 glows before a selection")
	var albedo0: Variant = five.body_material.get_shader_parameter("albedo")
	check(s.pick_die(0), "pot a 3")
	await process_frame
	check(str(fx.dim_indices()) == "[3]", "only the 5 can't join trips: %s" % str(fx.dim_indices()))
	check(fx.is_dimmed(five) and not fx.is_dimmed(three), "5 dimmed, other 3 not")
	for k in 30:
		await process_frame
	check(five.glow_lit == 0.0 and five.glow_cold == 0.0, "dim = plain look, never cold grey")
	check(three.glow_lit > 0.5, "joinable 3 keeps its glow")
	check(s.is_lit(five), "dim is visual only: scoring still says lit")
	check(s.pick_die(0), "unpot the 3")
	await process_frame
	check(not fx.is_dimmed(five), "unselecting relights the 5")
	for k in 30:
		await process_frame
	check(five.glow_lit > 0.5, "5 glows again")
	check(five.body_material.get_shader_parameter("albedo") == albedo0, "body albedo untouched")
	sv.queue_free()
	_finish()


func _finish() -> void:
	print("selection_dim: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)
