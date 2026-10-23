## Headless tests for NerveSpentFx (the Nerve "spent" cue): has_signal guard,
## one flat warm glint on the camera-side bevel (off the pips), <= 0.3 s,
## still under reduced motion, leftover nudge FX cleared, sound via TableAudio
## (nerve_spent method, else cue, else nothing), die untouched, hooked once.
##
## Run:
##   godot --headless --path . --script res://tests/test_nerve_spent_fx.gd
extends SceneTree


class FakeSfx extends Node:
	var events: Array[StringName] = []
	var played: Array[StringName] = []
	func has_event(e: StringName) -> bool:
		return events.has(e)
	func play(e: StringName, _p: float = 1.0, _v: float = 0.0, _j: float = 0.0) -> void:
		played.append(e)


class SpentAudio extends Node:
	var n: int = 0
	func nerve_spent() -> void:
		n += 1


class FakeTurn extends Node:
	var cleared: Array = []
	func clear(die: Node3D = null) -> void:
		cleared.append(die)


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
	print("=== Dice of the Damned: nerve spent fx tests ===")
	_run.call_deferred()


func _run() -> void:
	await _test_guard()
	await _test_glint()
	await _test_reduced()
	await _test_audio()
	await _test_clear()
	_test_hook()
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _check(condition: bool, name: String) -> void:
	if condition:
		_passed += 1
	else:
		_failed += 1
		print("FAIL: ", name)


## Table whose events carry nerve_spent (as #143 adds it) unless `with_signal` is false.
func _make(with_signal: bool = true) -> Array:
	var t := FakeTable.new()
	root.add_child(t)
	t.add_child(t.events)
	if with_signal and not t.events.has_signal(&"nerve_spent"):
		t.events.add_user_signal("nerve_spent", [
			{"name": "die_id", "type": TYPE_INT}, {"name": "from_face", "type": TYPE_INT},
			{"name": "to_face", "type": TYPE_INT}])
	var d := DieVisual.new(0.08)
	t.add_child(d)
	d.global_position = Vector3(0.2, 0.04, 0.1)
	t.dice = [d] as Array[DieVisual]
	var turn := FakeTurn.new()
	turn.name = "NerveTurnFx"
	t.add_child(turn)
	var fx := NerveSpentFx.new()
	t.add_child(fx)
	return [t, d, fx, turn, fx.bind(t.events, t)]


func _test_guard() -> void:
	if TableEvents.new().has_signal(&"nerve_spent"):
		_check(true, "TableEvents already has nerve_spent (#143 landed)")
		return
	var m := _make(false)
	_check(not m[4], "no nerve_spent signal: bind() returns false, nothing connected")
	(m[0] as Node).queue_free()
	await process_frame


func _test_glint() -> void:
	var m := _make()
	var t: FakeTable = m[0]
	var d: DieVisual = m[1]
	var fx: NerveSpentFx = m[2]
	var turn: FakeTurn = m[3]
	_check(m[4], "binds to nerve_spent")
	var before := d.global_transform
	var mat_before: Variant = d.get("material_override")
	t.events.emit_signal(&"nerve_spent", 0, 2, 3)
	_check(fx.calls.size() == 1 and fx.calls[0] == "0:2>3", "one cue per spend (%s)" % str(fx.calls))
	_check(turn.cleared.size() == 1 and turn.cleared[0] == d, "leftover nudge FX cleared for that die")
	_check(fx.pieces.size() == 1, "one glint piece (%d)" % fx.pieces.size())
	var s: Sprite3D = fx.pieces[0]
	_check(s.billboard == BaseMaterial3D.BILLBOARD_DISABLED and s.axis == Vector3.AXIS_Y, "glint lies flat on the top")
	var top := d.global_position.y + 0.04
	_check(s.global_position.y > top and s.global_position.y < top + 0.005, "glint just above the top face")
	var local := s.global_position - d.global_position
	var depth := Vector2(local.x, local.z).length() / 0.08
	_check(absf(depth - NerveSpentFx.EDGE_Z) < 0.01, "glint centred on the camera-side bevel (%.3f)" % depth)
	_check(NerveSpentFx.min_depth() >= NerveSpentFx.PIP_REACH, "glint never reaches the pips (%.3f)" % NerveSpentFx.min_depth())
	var width := s.pixel_size * float(s.texture.get_height()) * s.scale.z
	_check(absf(width - 0.08 * NerveSpentFx.THICK) < 1e-5, "thin band (%.4f m)" % width)
	var c := NerveSpentFx.COLOR
	_check(c.r >= c.g and c.g > c.b and c.r - c.b > 0.4 and maxf(c.r, maxf(c.g, c.b)) * NerveSpentFx.PEAK <= 1.0, "saturated warm gold, no HDR clip, never violet/cyan")
	_check(NerveSpentFx.GLINT_TIME <= NerveSpentFx.TOTAL_TIME and NerveSpentFx.TOTAL_TIME <= 0.3, "<= 0.3 s")
	t.events.emit_signal(&"nerve_spent", 0, 3, 4)
	_check(fx.pieces.size() == 1, "a second spend replaces, never stacks")
	t.events.emit_signal(&"nerve_spent", 7, 1, 2)
	_check(fx.calls.size() == 2, "unknown die id: nothing")
	await create_timer(NerveSpentFx.TOTAL_TIME + 0.1).timeout
	_check(fx.pieces.is_empty(), "glint freed by 0.3 s")
	_check(d.global_transform == before and d.get("material_override") == mat_before, "die untouched")
	var n := fx.calls.size()
	t.events.emit_signal(&"die_nudged", 0, 3, 2, NerveState.DOWN)
	_check(fx.calls.size() == n, "undo (die_nudged) plays no spent cue")
	t.queue_free()
	await process_frame


func _test_reduced() -> void:
	var m := _make()
	var t: FakeTable = m[0]
	var fx: NerveSpentFx = m[2]
	fx.hold = true
	t.reduced_motion = true
	t.events.emit_signal(&"nerve_spent", 0, 4, 5)
	var s: Sprite3D = fx.pieces[0]
	var p := s.global_position
	var sc := s.scale
	fx.advance(0.15)
	_check(s.global_position == p and s.scale == sc, "reduced motion: no motion, only a fade")
	_check(s.modulate.a < 1.0 and s.modulate.a > 0.0, "reduced motion: still fades")
	fx.advance(0.2)
	_check(fx.pieces.is_empty(), "reduced motion: gone by 0.3 s")
	t.reduced_motion = false
	t.speed_mode = 2
	t.events.emit_signal(&"nerve_spent", 0, 4, 5)
	sc = fx.pieces[0].scale
	fx.advance(0.15)
	_check(fx.pieces[0].scale == sc, "Instant speed: no motion")
	fx.clear()
	t.queue_free()
	await process_frame


func _test_audio() -> void:
	var m := _make()
	var t: FakeTable = m[0]
	var fx: NerveSpentFx = m[2]
	var sa := SpentAudio.new()
	t.add_child(sa)
	fx.audio = sa
	t.events.emit_signal(&"nerve_spent", 0, 1, 2)
	_check(sa.n == 1, "TableAudio.nerve_spent() used when present")
	var sfx := FakeSfx.new()
	t.add_child(sfx)
	var audio := TableAudio.new()
	t.add_child(audio)
	audio.bind(t.events, sfx)
	fx.audio = audio
	t.events.emit_signal(&"nerve_spent", 0, 2, 3)
	_check(sfx.played.is_empty(), "no nerve_spent sfx: plays nothing")
	sfx.events.append(&"nerve_spent")
	t.events.emit_signal(&"nerve_spent", 0, 3, 4)
	_check(sfx.played.count(&"nerve_spent") <= 1, "a nerve_spent sfx plays at most once")
	fx.clear()
	t.queue_free()
	await process_frame


func _test_hook() -> void:
	var src := FileAccess.get_file_as_string("res://scripts/table3d/table_3d.gd")
	_check(src.count("add_child(NerveSpentFx.new())") == 1, "hooked once in table_3d.gd")


func _test_clear() -> void:
	var m := _make()
	var t: FakeTable = m[0]
	var d: DieVisual = m[1]
	var fx: NerveSpentFx = m[2]
	var d2 := DieVisual.new(0.08)
	t.add_child(d2)
	d2.global_position = Vector3(-0.2, 0.04, 0.1)
	t.dice.append(d2)
	for sig: StringName in [&"rethrow", &"close_throw"]:
		if not t.events.has_signal(sig):
			t.events.add_user_signal(sig)
	fx.bind(t.events, t)
	var cases := [
		[&"dice_thrown", [600.0]], [&"rethrow", []], [&"close_throw", []], [&"table_cleared", []]]
	for cs: Array in cases:
		t.events.emit_signal(&"nerve_spent", 0, 2, 3)
		_check(fx.pieces.size() == 1, "%s: glint live before" % cs[0])
		t.events.callv(&"emit_signal", [cs[0]] + cs[1])
		_check(fx.pieces.is_empty(), "%s clears the spent glint" % cs[0])
	t.events.emit_signal(&"nerve_spent", 0, 2, 3)
	t.events.emit_signal(&"nerve_spent", 1, 5, 4)
	t.events.emit_signal(&"die_nudged", 0, 3, 2, NerveState.DOWN)
	_check(fx.pieces.size() == 1 and fx.pieces[0].get_meta("die") == d2, "undo on die 0 clears only die 0's glint")
	t.events.emit_signal(&"die_nudged", 1, 4, 5, NerveState.UP)
	_check(fx.pieces.is_empty(), "re-nudge clears that die's glint")
	t.queue_free()
	await process_frame
