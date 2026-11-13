## A target-table miss plays one Soul sound. goal_missed's sting
## (table_goal_missed, or soul_burn when that sting is missing) already
## carries the drain, so Table3D._burn_soul stays quiet for that miss only.
## A bounty miss and a mid-table bust still play soul_burn.
##
##   godot --headless --path . --script res://tests/test_goal_miss_soul.gd
extends SceneTree

var _passed: int = 0
var _failed: int = 0
var t: BonfireTuning
## SfxManager events since the last mark().
var log: Array[StringName] = []


func _initialize() -> void:
	_run.call_deferred()


func check(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		print("FAIL  ", what)


## A target table: bank `target` points to pass it within `hands` hands.
func target_goal(target: int, hands: int) -> TableGoal:
	var g := TableGoal.new()
	g.target = target
	g.hands = hands
	g.clear_embers = 14
	g.miss_soul = 5
	return g


## A bounty table (no target): clear it by rolling a Triple.
func bounty_goal(hands: int = 3) -> TableGoal:
	var g := TableGoal.new()
	g.hands = hands
	var b := BountyData.new()
	b.id = &"triple"
	b.display_name = "triple"
	b.kind = BountyData.Kind.N_OF_A_KIND
	b.n = 3
	g.required.append(b)
	return g


## The shared miss check, without a scene: the same numbers goal_missed uses.
func _check_helper() -> void:
	var run := BonfireRun.new(t, target_goal(10, 3), 35, 3)
	run.state = BonfireRun.State.FAILED
	run.table_summary = {"timeout_soul": 5}
	check(TableEvents.is_goal_miss(run, BonfireRun.State.FAILED), "FAILED target table is a goal miss")
	run.state = BonfireRun.State.RUN_OVER
	check(TableEvents.is_goal_miss(run, BonfireRun.State.RUN_OVER), "RUN_OVER with timeout Soul is a goal miss")
	run.table_summary = {"timeout_soul": 0}
	check(not TableEvents.is_goal_miss(run, BonfireRun.State.RUN_OVER), "a bust that spends the last Soul is not a goal miss")
	run.state = BonfireRun.State.FAILED
	run.table_summary = {}
	check(TableEvents.is_goal_miss(run, BonfireRun.State.FAILED), "FAILED with no timeout key is still a miss")
	var bounty := BonfireRun.new(t, bounty_goal(), 35, 3)
	bounty.state = BonfireRun.State.FAILED
	bounty.table_summary = {"timeout_soul": 3}
	check(not TableEvents.is_goal_miss(bounty, BonfireRun.State.FAILED), "a bounty table is not a goal miss")
	check(not TableEvents.is_goal_miss(null, BonfireRun.State.FAILED), "no run is not a miss")


## Builds a fresh table with this goal, listening from the start.
func make_table(sv: SubViewport, g: TableGoal, soul: int = -1) -> Bonfire3D:
	var st := TableSetup.sandbox(t, 3)
	st.goal = g
	st.table_seed = 5
	st.nerve_uses = 0  # a plain end: no Nerve rescue pause
	if soul >= 0:
		st.starting_soul = soul
	var s := (load("res://scenes/bonfire.tscn") as PackedScene).instantiate() as Bonfire3D
	s.setup = st
	s.tutorial_override = 0
	s.test_speed = 10.0
	sv.add_child(s)
	for _i: int in 8:
		await process_frame
		var audio := s.get_node_or_null("TableAudio") as TableAudio
		if audio != null and audio.events != null:
			break
	log.clear()
	s.sfx.played.connect(func(e: StringName) -> void: log.append(e))
	return s


func wait_bet(s: Bonfire3D) -> void:
	for _k: int in 600:
		if s.run.is_over() or (s.phase == Table3D.Phase.BET and not s.bhud.countup.is_playing() and not s.hand_moving()):
			return
		await process_frame


## One hand: throw these faces, pick the first `pick` dice, bank.
func bank_hand(s: Bonfire3D, faces: Array[int], pick: int) -> void:
	await wait_bet(s)
	s.rig_faces(faces)
	check(s.quick_throw(), "throw %s starts" % str(faces))
	await s.throw_resolved
	await s.sequence_finished
	for i: int in pick:
		s.pick_die(i)
	await s.bank()
	await wait_bet(s)


func soul_sounds() -> Array[StringName]:
	var out: Array[StringName] = []
	for e: StringName in log:
		if e == &"table_goal_missed" or e == &"soul_burn":
			out.append(e)
	return out


## goal_missed cues TableAudio played since `from` (the sting, or its fallback).
func miss_cues(s: Bonfire3D, from: int) -> Array:
	var audio := s.get_node_or_null("TableAudio") as TableAudio
	if audio == null:
		return []
	var out: Array = []
	for c: String in audio.calls.slice(from):
		if c == "table_goal_missed" or c == "soul_burn(fb)":
			out.append(c)
	return out


func calls_from(s: Bonfire3D) -> int:
	var audio := s.get_node_or_null("TableAudio") as TableAudio
	return audio.calls.size() if audio != null else 0


## One Soul sound, and it is the miss sting (or the soul_burn fallback).
func check_one_miss(s: Bonfire3D, from: int, soul_before: int, label: String) -> void:
	var sounds := soul_sounds()
	var cues := miss_cues(s, from)
	check(cues.size() == 1, "%s: goal_missed plays one sting (or its fallback): %s" % [label, str(cues)])
	check(sounds.size() == 1, "%s: exactly one Soul sound, not the sting and soul_burn: %s" % [label, str(sounds)])
	check(s.soul_meter.soul == s.run.soul and s.run.soul < soul_before, "%s: the meter still drains (%d -> %d, shown %d)" % [label, soul_before, s.run.soul, s.soul_meter.soul])
	check(TableEvents.is_goal_miss(s.run, int(s.run.state)), "%s: the shared miss check agrees")


func _run() -> void:
	t = load("res://resources/tuning/bonfire_tuning.tres") as BonfireTuning
	_check_helper()
	var sv := SubViewport.new()
	sv.size = Vector2i(1280, 720)
	root.add_child(sv)
	# 1) Out of hands short of the target. Soul is left, so the end is FAILED.
	var s := await make_table(sv, target_goal(99999, 1))
	var audio := s.get_node_or_null("TableAudio") as TableAudio
	check(audio != null and audio.events != null, "TableAudio is listening for goal_missed")
	var soul_before := s.run.soul
	var from := calls_from(s)
	log.clear()
	await bank_hand(s, [5, 5, 1] as Array[int], 2)
	check(s.run.state == BonfireRun.State.FAILED, "out of hands short of the target: FAILED")
	check_one_miss(s, from, soul_before, "missed target")
	s.queue_free()
	# 2) Giving up a target table is the same single Soul sound.
	s = await make_table(sv, target_goal(99999, 3))
	await wait_bet(s)
	soul_before = s.run.soul
	from = calls_from(s)
	log.clear()
	check(s.forfeit(), "forfeit the target table")
	check(s.run.state == BonfireRun.State.FAILED, "forfeit with Soul left: FAILED")
	check_one_miss(s, from, soul_before, "forfeited target")
	s.queue_free()
	# 3) The miss that spends the last Soul ends RUN_OVER, and is still one sound.
	s = await make_table(sv, target_goal(99999, 3), 5)
	await wait_bet(s)
	soul_before = s.run.soul
	from = calls_from(s)
	log.clear()
	check(s.forfeit(), "forfeit the target table on its last Soul")
	check(s.run.state == BonfireRun.State.RUN_OVER, "the miss took the last Soul: RUN_OVER")
	check_one_miss(s, from, soul_before, "run-ending miss")
	s.queue_free()
	# 4) A bounty table that runs out of hands is not a goal miss: soul_burn stays.
	s = await make_table(sv, bounty_goal(1))
	soul_before = s.run.soul
	from = calls_from(s)
	log.clear()
	await bank_hand(s, [5, 5, 1] as Array[int], 2)
	check(s.run.state == BonfireRun.State.FAILED, "bounty table out of hands: FAILED")
	check(miss_cues(s, from).is_empty(), "bounty miss plays no goal sting: %s" % str(miss_cues(s, from)))
	check(soul_sounds() == [&"soul_burn"], "missed bounty table still logs soul_burn: %s" % str(soul_sounds()))
	check(s.soul_meter.soul == s.run.soul and s.run.soul < soul_before, "bounty miss still drains the meter")
	check(not TableEvents.is_goal_miss(s.run, int(s.run.state)), "bounty miss: the shared check says no")
	s.queue_free()
	# 5) A bust with hands left is its own soul_burn, not a goal miss.
	s = await make_table(sv, target_goal(10, 3))
	await wait_bet(s)
	soul_before = s.run.soul
	from = calls_from(s)
	log.clear()
	s.rig_faces([2, 4, 6] as Array[int])
	check(s.quick_throw(), "bust throw starts")
	await s.throw_resolved
	await s.sequence_finished
	check(not s.run.is_over() and s.run.state == BonfireRun.State.AIM, "mid-table bust: the table continues")
	check(miss_cues(s, from).is_empty(), "a bust plays no goal sting: %s" % str(miss_cues(s, from)))
	check(soul_sounds() == [&"soul_burn"], "mid-table bust still logs soul_burn: %s" % str(soul_sounds()))
	check(s.soul_meter.soul == s.run.soul and s.run.soul < soul_before, "the bust still drains the meter")
	check(not TableEvents.is_goal_miss(s.run, int(s.run.state)), "a mid-table bust is not a goal miss")
	s.queue_free()
	await process_frame
	print("test_goal_miss_soul: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)
