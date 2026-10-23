## Headless tests for NerveTurnFx (the Nerve "die turns" accent): binds to
## die_nudged (and skips an events node without it), flick in the nudge
## direction, pale-glass glint beside the die (never over its face centre,
## never rising), still under reduced motion, sound via TableAudio with a
## fallback, die untouched, pieces freed; plus the real Bonfire table path.
##
## Run:
##   godot --headless --path . --script res://tests/test_nerve_turn_fx.gd
extends SceneTree


class FakeSfx extends Node:
	var events: Array[StringName] = []
	var played: Array[StringName] = []
	func has_event(e: StringName) -> bool:
		return events.has(e)
	func play(e: StringName, _p: float = 1.0, _v: float = 0.0, _j: float = 0.0) -> void:
		played.append(e)


class FakeTable extends Node3D:
	var events := TableEvents.new()
	var dice: Array[DieVisual] = []
	var reduced_motion: bool = false
	var speed_mode: int = 0
	func is_reduced_motion() -> bool:
		return reduced_motion
	func die_by_id(id: int) -> DieVisual:
		return dice[id] if id >= 0 and id < dice.size() else null


var _passed: int = 0
var _failed: int = 0


func _initialize() -> void:
	print("=== Dice of the Damned: nerve turn fx tests ===")
	_run.call_deferred()


func _run() -> void:
	await _test_unit()
	await _test_bonfire()
	_test_hook()
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _check(condition: bool, name: String) -> void:
	if condition:
		_passed += 1
	else:
		_failed += 1
		print("FAIL: ", name)


func _make() -> Array:
	var t := FakeTable.new()
	root.add_child(t)
	t.add_child(t.events)
	var d := DieVisual.new(0.08)
	t.add_child(d)
	d.global_position = Vector3(0.2, 0.04, 0.1)
	t.dice = [d] as Array[DieVisual]
	var sfx := FakeSfx.new()
	t.add_child(sfx)
	var audio := TableAudio.new()
	t.add_child(audio)
	audio.bind(t.events, sfx)
	var fx := NerveTurnFx.new()
	t.add_child(fx)
	_check(fx.bind(t.events, t), "binds to die_nudged")
	fx.audio = audio
	return [t, d, sfx, audio, fx]


func _check_pieces(fx: NerveTurnFx, d: DieVisual, dir: int, tag: String, still: bool) -> void:
	_check(fx.pieces.size() == 1 + NerveTurnFx.MOTES, tag + ": flick + 3 motes")
	var side_ok := true
	var no_rise := true
	var glass := true
	for s in fx.pieces:
		var o: Vector3 = s.get_meta("origin")
		var m: Vector3 = s.get_meta("move")
		side_ok = side_ok and absf(o.x - d.global_position.x) >= d.edge * NerveTurnFx.SIDE_MIN - 1e-5 and absf((o + m).x - d.global_position.x) >= d.edge * NerveTurnFx.SIDE_MIN - 1e-5
		no_rise = no_rise and m.y <= 0.0 and o.y <= d.global_position.y + 1e-5
		glass = glass and s.modulate.r == NerveTurnFx.GLASS.r and s.modulate.g == NerveTurnFx.GLASS.g and s.modulate.b == NerveTurnFx.GLASS.b
	_check(side_ok, tag + ": every piece beside the die, never over the face centre")
	_check(no_rise, tag + ": nothing rises (no upward sparks)")
	_check(glass, tag + ": pale glass #F2EEE2")
	var flick: Vector3 = fx.pieces[0].get_meta("move")
	if still:
		_check(flick == Vector3.ZERO, tag + ": no slide when still")
		var all_still := true
		for s in fx.pieces:
			all_still = all_still and (s.get_meta("move") as Vector3) == Vector3.ZERO
		_check(all_still, tag + ": no drift when still")
	else:
		_check(signf(flick.z) == (-1.0 if dir == NerveState.UP else 1.0) and is_equal_approx(flick.length(), NerveTurnFx.FLICK_SLIDE), tag + ": flick slides in dir")
	_check(fx.pieces[0].texture == TriggerShapes.texture(&"glint_streak", NerveTurnFx.GLASS), tag + ": flick uses glint_streak art")
	_check(fx.pieces[1].texture == TriggerShapes.texture(&"spark_dot_soft", NerveTurnFx.GLASS), tag + ": motes use spark_dot_soft art")


func _test_unit() -> void:
	var r := _make()
	var t: FakeTable = r[0]
	var d: DieVisual = r[1]
	var sfx: FakeSfx = r[2]
	var fx: NerveTurnFx = r[4]
	var xf := d.global_transform
	var faces_xf := d.faces.transform
	var mat := d.body_material
	sfx.events = [&"chip_place"] as Array[StringName]
	t.events.die_nudged.emit(0, 2, 3, NerveState.UP)
	_check(Array(fx.calls) == ["0:1"], "nudge recorded")
	_check_pieces(fx, d, NerveState.UP, "UP", false)
	_check(Array(sfx.played) == [&"chip_place"], "no nerve_nudge yet: chip_place fallback through TableAudio")
	_check(d.global_transform == xf and d.faces.transform == faces_xf and d.body_material == mat, "die transform / material untouched")
	await create_timer(0.4).timeout
	_check(fx.pieces.is_empty(), "pieces freed after the glint")
	sfx.events = [&"nerve_nudge", &"chip_place"] as Array[StringName]
	sfx.played.clear()
	t.events.die_nudged.emit(0, 3, 2, NerveState.DOWN)
	_check(Array(sfx.played) == [&"nerve_nudge"], "undo: Sound Designer's nerve_nudge when present")
	_check_pieces(fx, d, NerveState.DOWN, "DOWN (undo)", false)
	await create_timer(0.4).timeout
	t.reduced_motion = true
	t.events.die_nudged.emit(0, 2, 3, NerveState.UP)
	_check_pieces(fx, d, NerveState.UP, "reduced motion", true)
	await create_timer(0.4).timeout
	t.reduced_motion = false
	t.speed_mode = 2
	t.events.die_nudged.emit(0, 2, 3, NerveState.UP)
	_check_pieces(fx, d, NerveState.UP, "instant speed", true)
	t.events.die_nudged.emit(7, 2, 3, NerveState.UP)
	_check(fx.calls.size() == 4, "unknown die id ignored")
	var bare := Node.new()
	var fx2 := NerveTurnFx.new()
	_check(not fx2.bind(bare, t), "no die_nudged signal: has_signal guard, no bind")
	var silent := NerveTurnFx.new()
	t.add_child(silent)
	silent.bind(t.events, t)
	silent.audio = Node.new()
	t.events.die_nudged.emit(0, 2, 3, NerveState.UP)
	_check(silent.calls.size() == 1, "audio without cue(): has_method guard, still plays")
	silent.audio.free()
	bare.free()
	fx2.free()
	t.queue_free()
	await process_frame


func _test_bonfire() -> void:
	var tuning := load("res://resources/tuning/bonfire_tuning.tres") as BonfireTuning
	var st := TableSetup.sandbox(tuning, 5)
	st.table_seed = 5
	var s := (load("res://scenes/bonfire.tscn") as PackedScene).instantiate() as Bonfire3D
	s.setup = st
	s.test_speed = 10.0
	root.add_child(s)
	await process_frame
	await process_frame
	s.reduced_motion = true
	var fx := s.get_node_or_null("NerveTurnFx") as NerveTurnFx
	_check(fx != null and fx.events == s.events, "Bonfire table: NerveTurnFx bound to table.events")
	s.rig_faces([3, 3, 3, 2, 6] as Array[int])
	if s.quick_throw():
		await s.sequence_finished
	await process_frame
	s.nerve.nudge(3, NerveState.UP)
	_check(fx != null and Array(fx.calls) == ["%d:1" % s.event_id(s.throw_dice[3])], "real nudge plays the accent")
	s.nerve.undo(3)
	_check(fx != null and fx.calls.size() == 2 and fx.calls[1].ends_with(":-1"), "undo plays it reversed")
	s.queue_free()
	await process_frame


func _test_hook() -> void:
	var src := FileAccess.get_file_as_string("res://scripts/table3d/table_3d.gd")
	_check(src.count("add_child(NerveTurnFx.new())") == 1, "one add_child hook in table_3d.gd")
