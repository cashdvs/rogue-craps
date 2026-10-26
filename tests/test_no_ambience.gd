## Headless test: no background ambience. The looping crowd bed was removed
## (Oct 25, by request), so when a table runs no AudioStreamPlayer anywhere in
## the scene has a looping stream, and nothing is playing before the first
## throw or once a throw's one-shots have died away. Checked on the 3D table
## (scenes/table_3d.tscn) and a sandbox Bonfire table (scenes/bonfire.tscn),
## with crowd_start() called as the Bonfire scene does.
##
## Run:
##   godot --headless --path . --script res://tests/test_no_ambience.gd
extends SceneTree

var _passed: int = 0
var _failed: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _check(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		print("FAIL  ", what)


func _run() -> void:
	print("=== Dice of the Damned: no ambience tests ===")
	var t := (load("res://scenes/table_3d.tscn") as PackedScene).instantiate() as Table3D
	t.rng_seed = 42
	t.test_speed = 10.0
	await _table_check(t, "table_3d")
	var tuning := load("res://resources/tuning/bonfire_tuning.tres") as BonfireTuning
	var st := TableSetup.sandbox(tuning, 5)
	st.run_mode = true
	st.table_seed = 5
	var b := (load("res://scenes/bonfire.tscn") as PackedScene).instantiate() as Bonfire3D
	b.setup = st
	b.test_speed = 10.0
	b.tutorial_override = 0
	await _table_check(b, "bonfire")
	Engine.time_scale = 1.0
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


## Adds the table, starts its crowd (Bonfire), throws once and checks the players.
func _table_check(s: Table3D, label: String) -> void:
	root.add_child(s)
	for k in 5:
		await process_frame
	if s is Bonfire3D:
		(s as Bonfire3D).juice.crowd_start()
		_check((s as Bonfire3D).juice.crowd.get_child_count() == 0, "%s: the crowd node owns no players" % label)
	await process_frame
	_check(_players(s).size() > 0, "%s: the scene has audio players to check (%d)" % [label, _players(s).size()])
	_check(_looping(s).is_empty(), "%s: no looping stream at start %s" % [label, _looping(s)])
	_check(_playing(s).is_empty(), "%s: nothing plays before the first throw %s" % [label, _playing(s)])
	for k in 600:
		if s.phase == Table3D.Phase.BET:
			break
		await process_frame
	if not s is Bonfire3D:
		s.place()  # a Pass Line bet, as test_table_3d does
	var looped: Array = []
	if s.quick_throw():
		var done := [false]
		s.sequence_finished.connect(func() -> void: done[0] = true, CONNECT_ONE_SHOT)
		var until := Time.get_ticks_msec() + 20000
		while not done[0] and Time.get_ticks_msec() < until:
			for n in _looping(s):
				if n not in looped: looped.append(n)
			await process_frame
		_check(done[0], "%s: the throw finishes" % label)
	else:
		_check(false, "%s: throw starts" % label)
	_check(looped.is_empty(), "%s: no looping stream during the throw %s" % [label, looped])
	var quiet_until := Time.get_ticks_msec() + 4000  # one-shots end; a bed never would
	while not _playing(s).is_empty() and Time.get_ticks_msec() < quiet_until:
		await process_frame
	_check(_playing(s).is_empty(), "%s: nothing keeps playing after the throw %s" % [label, _playing(s)])
	s.queue_free()
	await process_frame


func _players(n: Node) -> Array[Node]:
	var out: Array[Node] = []
	for c in n.find_children("*", "", true, false):
		if c is AudioStreamPlayer or c is AudioStreamPlayer2D or c is AudioStreamPlayer3D:
			out.append(c)
	return out


func _looping(n: Node) -> Array:
	return _players(n).filter(func(p: Node) -> bool: return _loops(p.get("stream"))).map(func(p: Node) -> String: return str(p.get_path()))


func _playing(n: Node) -> Array:
	return _players(n).filter(func(p: Node) -> bool: return p.get("playing")).map(func(p: Node) -> String: return "%s %s" % [p.get_path(), p.get("stream").resource_path if p.get("stream") else ""])


static func _loops(stream: AudioStream) -> bool:
	if stream is AudioStreamWAV:
		return (stream as AudioStreamWAV).loop_mode != AudioStreamWAV.LOOP_DISABLED
	return stream != null and "loop" in stream and bool(stream.get("loop"))
