## Sounds per gameplay moment on the real Bonfire table (from QA's
## qa/pr72_scratch/events_count.gd). The throw, impact, Hot Hand, no_score
## and table_cleared sounds belong to the feel layer (scripts/fx/
## TableAudio, #72), which plays them from table.events. This checks:
## - with TableAudio: each moment plays its cue exactly ONCE (no doubles);
## - with TableAudio unbound: the table itself plays NONE of them;
## - the table's own _refuse() (a refused Bank / Throw) still plays
##   chip_refuse, once.
##   godot --headless --path . --script res://tests/test_table_sound_counts.gd
extends SceneTree

## The cues the table must never play itself (TableAudio's, with fallbacks
## and every play_throw / play_impact layer). rim_hit isn't listed: the
## table keeps its own soft rim_hit as the lit dice settle (not an impact).
const FEEL_CUES: Array[StringName] = [&"dice_shake", &"throw_fwip", &"throw_fwip_whump", &"throw_fwip_tail",
	&"throw_rattle_soft", &"throw_rattle_medium", &"throw_rattle_hard", &"dice_hit", &"impact_wood",
	&"impact_click", &"no_score", &"hot_hand", &"win_big", &"table_cleared"]

var _passed: int = 0
var _failed: int = 0
## Every SfxManager event played since the last clear (name -> count).
var played: Dictionary = {}


func _initialize() -> void:
	_run.call_deferred()


func check(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		print("FAIL  ", what)


## A sandbox table: one hand, only the Triple required (so a bank clears it).
func _table(table_seed: int) -> Bonfire3D:
	var t := load("res://resources/tuning/bonfire_tuning.tres") as BonfireTuning
	var st := TableSetup.sandbox(t, 5)
	var goal := t.table_goal.duplicate() as TableGoal
	goal.hands = 2
	goal.bonus = []
	goal.required = goal.required.slice(0, 1)
	st.goal = goal
	st.table_seed = table_seed
	var s := (load("res://scenes/bonfire.tscn") as PackedScene).instantiate() as Bonfire3D
	s.setup = st
	s.tutorial_override = 0
	s.test_speed = 10.0
	root.add_child(s)
	for k in 3:
		await process_frame
	s.sfx.played.connect(func(e: StringName) -> void: played[e] = int(played.get(e, 0)) + 1)
	return s


## TableAudio's own record of what it played since `from` (its calls list).
func audio_calls(s: Bonfire3D, from: int) -> Array:
	var a := s.get_node_or_null("TableAudio")
	return (a.get("calls") as Array).slice(from) if a != null else []


func n_calls(s: Bonfire3D, from: int, names: Array) -> int:
	return audio_calls(s, from).filter(func(c: String) -> bool: return names.has(c)).size()


func calls_now(s: Bonfire3D) -> int:
	var a := s.get_node_or_null("TableAudio")
	return (a.get("calls") as Array).size() if a != null else 0


func _throw(s: Bonfire3D, faces: Array[int]) -> void:
	for k in 600:
		if s.phase == Table3D.Phase.BET and s.run.state == BonfireRun.State.AIM and not s.hand_moving() and not s.bhud.countup.is_playing():
			break
		await process_frame
	s.rig_faces(faces)
	s.quick_throw()
	await s.throw_resolved
	await s.sequence_finished


func _run() -> void:
	var s: Bonfire3D = await _table(42)
	var fx := s.get_node_or_null("TableAudio")
	check(fx != null and fx.get("events") != null, "TableAudio (#72) is on the table and bound to table.events")
	if fx == null:
		print("test_table_sound_counts: %d passed, %d failed" % [_passed, _failed])
		quit(1)
		return
	# One throw: one throw cue, and every throw layer played once.
	var impacts: Array = []
	s.events.die_impact.connect(func(_k: StringName, _v: float, _m: StringName, _i: int) -> void: impacts.append(1))
	played.clear()
	var c0 := calls_now(s)
	await _throw(s, [3, 3, 3, 2, 6] as Array[int])
	check(n_calls(s, c0, ["throw", "dice_shake"]) == 1, "one throw: ONE throw cue (%s)" % str(audio_calls(s, c0)))
	for e: StringName in played:
		if String(e).begins_with("throw_") or e == &"dice_shake":
			check(int(played[e]) == 1, "throw layer %s plays once (x%d)" % [e, played[e]])
	# Impacts: at most one sound per die_impact event (play_impact may stay
	# silent for soft taps or rate-limit), and at least one.
	var imp := n_calls(s, c0, ["impact"])
	check(imp >= 1 and imp <= impacts.size(), "impacts: %d sounds for %d contacts (never more)" % [imp, impacts.size()])
	# A refused pick plays no_score specifically (VFX Dev, #72): never the
	# chip_refuse fallback, which is for the table's disabled buttons.
	c0 = calls_now(s)
	played.clear()
	check(not s.pick_die(3), "the 2 is refused (no combo)")
	await create_timer(0.2).timeout
	check(n_calls(s, c0, ["no_score"]) == 1 and n_calls(s, c0, ["chip_refuse(fb)"]) == 0, "a refused pick: ONE no_score cue, no fallback (%s)" % str(audio_calls(s, c0)))
	check(int(played.get(&"no_score", 0)) == 1 and int(played.get(&"chip_refuse", 0)) == 0, "...and the SfxManager played no_score once, chip_refuse never (%s)" % str(played))
	# The table's own _refuse(): Bank with nothing potted plays chip_refuse once.
	played.clear()
	s.bank()
	await process_frame
	check(int(played.get(&"chip_refuse", 0)) == 1, "_refuse (Bank, nothing potted) still plays chip_refuse once (%s)" % str(played))
	# Bank the Triple: the table clears, ONE table_cleared cue.
	for i in 3:
		s.pick_die(i)
	c0 = calls_now(s)
	played.clear()
	await s.bank()
	await create_timer(0.5).timeout
	check(s.run.cleared, "the Triple clears the table")
	check(n_calls(s, c0, ["table_cleared", "win_big(fb)"]) == 1, "table cleared: ONE cue (%s)" % str(audio_calls(s, c0)))
	check(int(played.get(&"table_cleared", 0)) + int(played.get(&"win_big", 0)) == 1, "...and one sound in the SfxManager (%s)" % str(played))
	s.queue_free()
	await create_timer(0.3).timeout
	# Hot Hand: ONE hot_hand cue when the dice arrive.
	var h: Bonfire3D = await _table(43)
	await _throw(h, [3, 3, 3, 5, 5] as Array[int])
	for i in 5:
		h.pick_die(i)
	var hh: Array = []
	h.events.hot_hand.connect(func(_c: int) -> void: hh.append(1))
	c0 = calls_now(h)
	played.clear()
	check(h.throw_again(), "pot all five: Hot Hand")
	await create_timer(2.0).timeout
	check(hh.size() == 1, "one hot_hand event (%d)" % hh.size())
	check(n_calls(h, c0, ["hot_hand", "win_big(fb)"]) == 1, "Hot Hand: ONE cue (%s)" % str(audio_calls(h, c0)))
	check(int(played.get(&"hot_hand", 0)) + int(played.get(&"win_big", 0)) == 1, "...and one sound in the SfxManager (%s)" % str(played))
	# TableAudio unbound: the table plays none of the feel cues itself.
	(h.get_node("TableAudio")).call("unbind")
	played.clear()
	await _throw(h, [4, 4, 4, 5, 2] as Array[int])
	h.pick_die(4)
	await create_timer(0.3).timeout
	var own: Array = FEEL_CUES.filter(func(e: StringName) -> bool: return played.has(e))
	check(own.is_empty(), "unbound: the table itself plays none of TableAudio's cues (%s)" % str(own))
	h.queue_free()
	await create_timer(0.3).timeout
	print("test_table_sound_counts: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)
