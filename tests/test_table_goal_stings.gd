## Headless test: the table-goal stings (TableGoalSynth). Both files are
## baked, load as 22,050 Hz mono 16-bit one-shots, match a fresh bake, and
## TableAudio plays them on goal_reached / goal_missed (one cue per clear).
## SfxManager registers both events so the live table plays the stings, not
## the table_cleared / soul_burn fallbacks.
##
## Run:
##   godot --headless --path . --script res://tests/test_table_goal_stings.gd
extends SceneTree

var _passed: int = 0
var _failed: int = 0


class StubSfx:
	extends Node
	var log: Array[String] = []
	var known: Array[StringName] = []

	func play(event: StringName, _p: float = 1.0, _v: float = 0.0, _j: float = 0.06) -> void:
		log.append(String(event))

	func has_event(event: StringName) -> bool:
		return known.has(event)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	print("=== Dice of the Damned: table goal stings ===")
	for event: StringName in TableGoalSynth.EVENTS:
		var path := "res://audio/sfx/%s.wav" % event
		_check(ResourceLoader.exists(path), "%s exists" % path)
		var w := load(path) as AudioStreamWAV
		_check(w != null, "%s loads as AudioStreamWAV" % path)
		if w == null:
			continue
		_check(w.loop_mode == AudioStreamWAV.LOOP_DISABLED, "%s does not loop" % event)
		# The file on disk (the import may compress it): RIFF fmt header.
		var raw := FileAccess.get_file_as_bytes(path)
		_check(raw.size() > 44 and raw.decode_u16(22) == 1 and raw.decode_u32(24) == 22050 and raw.decode_u16(34) == 16,
			"%s is 22,050 Hz mono 16-bit on disk" % event)
		var secs := w.get_length()
		_check(secs > 0.5 and secs < 2.0, "%s is a short sting (%.2f s)" % [event, secs])
		_check(TableGoalSynth.make(event).data == TableGoalSynth.make(event).data, "%s bakes deterministically" % event)
	_check(TableGoalSynth.bake_all().size() == 2, "bake_all() owns both files")
	_test_hooks()
	_test_registered()
	print("passed %d, failed %d" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _test_hooks() -> void:
	var ev := Object.new()
	for sig in ["goal_reached", "table_cleared", "table_started"]:
		ev.add_user_signal(sig)
	ev.add_user_signal("goal_missed", [{"name": "soul_loss", "type": TYPE_INT}])
	var sfx := StubSfx.new()
	sfx.known = [&"table_goal_reached", &"table_goal_missed", &"table_cleared", &"soul_burn"]
	var a := TableAudio.new()
	a.bind(ev, sfx)
	ev.emit_signal("goal_reached")
	ev.emit_signal("table_cleared")
	_check(sfx.log == ["table_goal_reached"], "goal_reached plays one sting, table_cleared stays silent: %s" % [sfx.log])
	ev.emit_signal("table_started")
	sfx.log.clear()
	ev.emit_signal("goal_missed", 5)
	_check(sfx.log == ["table_goal_missed"], "goal_missed plays the miss sting: %s" % [sfx.log])
	ev.emit_signal("goal_missed", 5)
	_check(sfx.log == ["table_goal_missed"], "a second goal_missed on the same table stays silent: %s" % [sfx.log])
	ev.emit_signal("table_started")
	ev.emit_signal("goal_missed", 5)
	_check(sfx.log == ["table_goal_missed", "table_goal_missed"], "table_started resets the miss guard: %s" % [sfx.log])
	sfx.known = [&"table_cleared", &"soul_burn"]
	sfx.log.clear()
	a.reset()
	ev.emit_signal("goal_reached")
	ev.emit_signal("goal_missed", 5)
	_check(sfx.log == ["table_cleared", "soul_burn"], "missing stings fall back: %s" % [sfx.log])
	a.free()
	sfx.free()
	ev.free()


## A real SfxManager whose play() only logs, so we can check registration
## and TableAudio's cue choice without starting voices (those leak at exit).
class LoggingSfx:
	extends SfxManager
	var log: Array[String] = []

	func play(event: StringName, _p: float = 1.0, _v: float = 0.0, _j: float = 0.06) -> void:
		log.append(String(event))


## Live SfxManager: both events must be registered, and TableAudio must
## play the real sting (not the fallback) when the TableEvents fire.
func _test_registered() -> void:
	var sfx := LoggingSfx.new()
	root.add_child(sfx)
	for event: StringName in TableGoalSynth.EVENTS:
		_check(sfx.has_event(event), "SfxManager has %s registered" % event)
	var ev := Object.new()
	ev.add_user_signal("goal_reached")
	ev.add_user_signal("goal_missed", [{"name": "soul_loss", "type": TYPE_INT}])
	ev.add_user_signal("table_started")
	var a := TableAudio.new()
	a.bind(ev, sfx)
	ev.emit_signal("goal_reached")
	_check(sfx.log == ["table_goal_reached"], "goal_reached plays the real sting, not the table_cleared fallback: %s" % [sfx.log])
	_check(a.calls == ["table_goal_reached"], "TableAudio records the reached sting, not a fallback: %s" % [a.calls])
	ev.emit_signal("table_started")
	a.calls.clear()
	sfx.log.clear()
	ev.emit_signal("goal_missed", 5)
	_check(sfx.log == ["table_goal_missed"], "goal_missed plays the real sting, not the soul_burn fallback: %s" % [sfx.log])
	_check(a.calls == ["table_goal_missed"], "TableAudio records the missed sting, not a fallback: %s" % [a.calls])
	a.unbind()
	a.free()
	sfx.free()
	ev.free()


func _check(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		print("FAIL  ", what)
