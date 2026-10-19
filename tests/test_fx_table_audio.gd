## Headless test: TableAudio (scripts/fx/table_audio.gd), the feel-layer
## listener that turns table.events signals into the Sound Designer's cues.
## Uses a stand-in TableEvents (the agreed signals, added as user signals)
## so it runs before Godot Dev's TableEvents lands, plus the real SfxManager
## and the real Bonfire table.
##
## Run:
##   godot --headless --path . --script res://tests/test_fx_table_audio.gd
extends SceneTree

var _passed: int = 0
var _failed: int = 0


## A stand-in SfxManager that records every call (event names, hooks).
class StubSfx:
	extends Node
	var events: Array[StringName] = []
	var log: Array[String] = []
	var known: Array[StringName] = []

	func play(event: StringName, _pitch: float = 1.0, _volume_db: float = 0.0, _jitter: float = 0.06) -> void:
		log.append(String(event))

	func has_event(event: StringName) -> bool:
		return known.has(event)

	func play_throw(speed: float) -> float:
		log.append("play_throw:%d" % int(speed))
		return 0.5

	func play_impact(kind: StringName, speed: float, material: StringName, die_id: int) -> bool:
		log.append("play_impact:%s:%.1f:%s:%d" % [kind, speed, material, die_id])
		return true


## Only play() / has_event(): the old stand-in shape.
class BareSfx:
	extends Node
	var log: Array[String] = []

	func play(event: StringName, _pitch: float = 1.0, _volume_db: float = 0.0, _jitter: float = 0.06) -> void:
		log.append(String(event))

	func has_event(event: StringName) -> bool:
		return event == &"dice_shake" or event == &"chip_refuse"


func _initialize() -> void:
	_run.call_deferred()


func _check(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		print("FAIL  ", what)


## The signals agreed with Godot Dev for scripts/bonfire/table_events.gd.
func _fake_events() -> Node:
	var ev := Node.new()
	ev.add_user_signal("dice_thrown", [{"name": "flick_speed_px_s", "type": TYPE_FLOAT}])
	ev.add_user_signal("die_impact", [{"name": "kind", "type": TYPE_STRING_NAME}, {"name": "speed_mps", "type": TYPE_FLOAT},
			{"name": "material", "type": TYPE_STRING_NAME}, {"name": "die_id", "type": TYPE_INT}])
	ev.add_user_signal("dice_settled")
	ev.add_user_signal("hot_hand", [{"name": "count", "type": TYPE_INT}])
	ev.add_user_signal("no_score")
	ev.add_user_signal("bust", [{"name": "soul_loss", "type": TYPE_INT}])
	ev.add_user_signal("table_cleared")
	return ev


func _run() -> void:
	print("=== Dice of the Damned: fx TableAudio tests ===")
	_test_stub()
	_test_fallbacks()
	_test_bare()
	_test_calls_trim()
	_test_real_sfx()
	await _test_bonfire_table()
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _test_stub() -> void:
	var ev := _fake_events()
	var sfx := StubSfx.new()
	sfx.known = [&"hot_hand", &"no_score", &"table_cleared", &"chip_refuse", &"win_big", &"dice_shake"]
	var a := TableAudio.new()
	root.add_child(ev)
	root.add_child(sfx)
	root.add_child(a)
	_check(a.bind(ev, sfx) == 5, "binds the 5 audio signals the stand-in has")
	# Throw: #26's momentum layers, never the old fixed dice_shake.
	for speed: float in [850.0, 2000.0, 4300.0]:
		ev.emit_signal("dice_thrown", speed)
	_check(sfx.log == ["play_throw:850", "play_throw:2000", "play_throw:4300"], "dice_thrown -> play_throw(speed) for soft/medium/hard: %s" % [sfx.log])
	_check(not sfx.log.has("dice_shake"), "no dice_shake on release when play_throw exists")
	# Impacts at the real contact speeds (soft ~2, medium 3.5, hard ~6 m/s).
	sfx.log.clear()
	ev.emit_signal("die_impact", &"felt", 2.0, &"bone", 0)
	ev.emit_signal("die_impact", &"rail", 3.5, &"bone", 1)
	ev.emit_signal("die_impact", "backboard", 6.0, "iron", 2)
	_check(sfx.log == ["play_impact:felt:2.0:bone:0", "play_impact:rail:3.5:bone:1", "play_impact:backboard:6.0:iron:2"],
			"die_impact -> play_impact(kind, speed, material, die_id), String or StringName: %s" % [sfx.log])
	# Hot Hand: the rev-2 bone clacks, nothing fiery.
	sfx.log.clear()
	ev.emit_signal("hot_hand", 1)
	_check(sfx.log == ["hot_hand"], "hot_hand -> exactly the hot_hand cue: %s" % [sfx.log])
	for e: String in sfx.log:
		_check(not ("ignite" in e or "fire" in e or "trail" in e or "crackle" in e), "Hot Hand plays no ignite / fire-trail sound (%s)" % e)
	# No score: no_score replaces chip_refuse.
	sfx.log.clear()
	ev.emit_signal("no_score")
	_check(sfx.log == ["no_score"], "no_score -> no_score, not chip_refuse: %s" % [sfx.log])
	# TABLE CLEARED once, even if the table reports it twice.
	sfx.log.clear()
	ev.emit_signal("table_cleared")
	ev.emit_signal("table_cleared")
	_check(sfx.log == ["table_cleared"], "table_cleared plays once per table: %s" % [sfx.log])
	a.reset()
	ev.emit_signal("table_cleared")
	_check(sfx.log.size() == 2, "reset() (a new table) allows TABLE CLEARED again")
	ev.add_user_signal("table_started")
	a.bind(ev, sfx)
	ev.emit_signal("table_cleared")
	var n := sfx.log.size()
	ev.emit_signal("table_cleared")
	ev.emit_signal("table_started")
	ev.emit_signal("table_cleared")
	_check(sfx.log.size() == n + 1, "table_started (#91) resets the TABLE CLEARED guard")
	a.unbind()
	a.bind(ev, sfx)
	sfx.log.clear()
	# Signals the audio layer doesn't use stay silent.
	sfx.log.clear()
	ev.emit_signal("dice_settled")
	ev.emit_signal("bust", 3)
	_check(sfx.log.is_empty(), "dice_settled / bust aren't handled by TableAudio (yet)")
	# Unbind: nothing more plays.
	a.unbind()
	ev.emit_signal("hot_hand", 1)
	ev.emit_signal("dice_thrown", 2000.0)
	_check(sfx.log.is_empty(), "unbind() disconnects every signal")
	a.free()
	sfx.free()
	ev.free()


func _test_fallbacks() -> void:
	# An SfxManager without the rev-2 cues: hot_hand / no_score / table_cleared fall back.
	var ev := _fake_events()
	var sfx := StubSfx.new()
	sfx.known = [&"chip_refuse", &"win_big"]
	var a := TableAudio.new()
	a.bind(ev, sfx)
	ev.emit_signal("no_score")
	ev.emit_signal("hot_hand", 2)
	ev.emit_signal("table_cleared")
	_check(sfx.log == ["chip_refuse", "win_big", "win_big"], "missing cues fall back to existing sounds: %s" % [sfx.log])
	_check(a.calls == ["chip_refuse(fb)", "win_big(fb)", "win_big(fb)"], "fallbacks are logged as (fb)")
	a.free()
	sfx.free()
	ev.free()


func _test_bare() -> void:
	# A stand-in SfxManager without play_throw / play_impact.
	var ev := _fake_events()
	var sfx := BareSfx.new()
	var a := TableAudio.new()
	a.bind(ev, sfx)
	ev.emit_signal("dice_thrown", 2000.0)
	ev.emit_signal("die_impact", &"felt", 3.5, &"bone", 0)
	_check(sfx.log == ["dice_shake"], "without play_throw: dice_shake on release, impacts silent: %s" % [sfx.log])
	# An events node that has none of the signals binds to nothing.
	var empty := Node.new()
	_check(a.bind(empty, sfx) == 0, "an events node without the signals binds nothing")
	a.free()
	sfx.free()
	ev.free()
	empty.free()


func _test_calls_trim() -> void:
	# calls grows on every impact/cue; trim like BonfireJuice past 400.
	var sfx := StubSfx.new()
	sfx.known = [&"hot_hand"]
	var a := TableAudio.new()
	a.sfx = sfx
	for _i in 401:
		a.cue(&"hot_hand")
	_check(a.calls.size() == 201, "calls trims to slice(200) after growing past 400: %d" % a.calls.size())
	a.free()
	sfx.free()


func _test_real_sfx() -> void:
	var ev := _fake_events()
	var sfx := SfxManager.new()
	root.add_child(sfx)
	var played: Array[StringName] = []
	sfx.played.connect(func(e: StringName) -> void: played.append(e))
	var a := TableAudio.new()
	a.bind(ev, sfx)
	ev.emit_signal("dice_thrown", 4300.0)
	_check(played.size() == 4 and not played.has(&"dice_shake"), "real SfxManager: a hard throw plays #26's 3 fwip layers + rattle: %s" % [played])
	played.clear()
	ev.emit_signal("die_impact", &"felt", 3.5, &"bone", 0)
	_check(not played.is_empty(), "real SfxManager: a 3.5 m/s felt hit plays: %s" % [played])
	played.clear()
	ev.emit_signal("die_impact", &"felt", 0.1, &"bone", 1)
	_check(played.is_empty(), "real SfxManager: a 0.1 m/s touch is silent (play_impact floor)")
	played.clear()
	ev.emit_signal("no_score")
	ev.emit_signal("hot_hand", 1)
	ev.emit_signal("table_cleared")
	_check(played.size() == 3, "real SfxManager: no_score / hot_hand / table_cleared each play one sound (cue or fallback): %s" % [played])
	for e: StringName in played:
		_check(sfx.has_event(e), "played event %s exists (no SfxManager warning)" % e)
	a.free()
	sfx.free()
	ev.free()


func _test_bonfire_table() -> void:
	# The real table: TableAudio is attached, and stays unbound (silent)
	# until the table has an `events` node, so nothing plays twice.
	var t := (load("res://scenes/bonfire.tscn") as PackedScene).instantiate() as Bonfire3D
	root.add_child(t)
	await process_frame
	await process_frame
	var a := t.get_node_or_null("TableAudio") as TableAudio
	_check(a != null, "the 3D table has a TableAudio child")
	if a != null:
		var has_events := t.get("events") is Object
		_check(a.events != null if has_events else a.events == null, "TableAudio binds to table.events only if it exists (has events: %s)" % has_events)
		if has_events:
			_check(a.sfx == t.sfx, "TableAudio uses the table's SfxManager")
	t.queue_free()
	# Let the table's timers and tweens finish so nothing leaks at exit.
	await create_timer(1.5).timeout
