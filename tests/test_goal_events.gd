## TableEvents goal signals for the Sound Designer's stings (#222):
##   - goal_reached() fires on the bank that reaches a target table's goal,
##     just before table_cleared (and never on a bounty table);
##   - goal_missed(soul_loss) fires when a target table ends FAILED, with the
##     real Soul the miss cost (the Bloodletter doubles it), once.
## Drives the real 3D Bonfire table (throws, picks, banks, forfeit).
##   godot --headless --path . --script res://tests/test_goal_events.gd
extends SceneTree

var _passed: int = 0
var _failed: int = 0
var t: BonfireTuning
## Every TableEvents signal we care about, in the order it fired.
var log: Array = []


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


## Builds a fresh table with this goal (and rules), listening from the start.
func make_table(sv: SubViewport, g: TableGoal, rules: Array[StringName] = []) -> Bonfire3D:
	log.clear()
	var st := TableSetup.sandbox(t, 3)
	st.goal = g
	st.rules = rules
	st.table_seed = 5
	st.nerve_uses = 0  # a plain end: no Nerve rescue pause
	var s := (load("res://scenes/bonfire.tscn") as PackedScene).instantiate() as Bonfire3D
	s.setup = st
	s.tutorial_override = 0
	s.test_speed = 10.0
	s.child_entered_tree.connect(func(n: Node) -> void:
		if n is TableEvents:
			for sig in [&"goal_reached", &"table_cleared", &"table_started"]:
				n.connect(sig, func() -> void: log.append([sig]))
			n.connect(&"goal_missed", func(soul_loss: int) -> void: log.append([&"goal_missed", soul_loss])))
	sv.add_child(s)
	await process_frame
	await process_frame
	return s


func wait_bet(s: Bonfire3D) -> void:
	for k in 600:
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
	for i in pick:
		s.pick_die(i)
	await s.bank()
	await wait_bet(s)


func names() -> Array:
	return log.map(func(e: Array) -> StringName: return e[0])


func _run() -> void:
	t = load("res://resources/tuning/bonfire_tuning.tres") as BonfireTuning
	var sv := SubViewport.new()
	sv.size = Vector2i(1920, 1080)
	root.add_child(sv)
	var s := await make_table(sv, target_goal(10, 3))
	check(s.events.has_signal(&"goal_reached") and s.events.has_signal(&"goal_missed"), "TableEvents has goal_reached / goal_missed")
	# 1) Reached: the bank passes the target 10.
	await bank_hand(s, [5, 5, 1] as Array[int], 2)
	var n := names()
	var gr := n.find(&"goal_reached")
	check(s.run.cleared, "the bank passed the target (%d >= 10)" % s.run.points)
	check(n.count(&"goal_reached") == 1 and gr >= 0 and gr + 1 < n.size() and n[gr + 1] == &"table_cleared",
		"goal_reached fires once, just before table_cleared: %s" % str(n))
	check(not n.has(&"goal_missed"), "a passed table sends no goal_missed")
	check(s.leave() and names().count(&"goal_reached") == 1 and not names().has(&"goal_missed"), "Leave after the pass: no second goal_reached, no miss")
	s.queue_free()
	# 2) A bounty table (no target) clears without goal_reached.
	s = await make_table(sv, bounty_goal())
	await bank_hand(s, [4, 4, 4] as Array[int], 3)
	check(names().has(&"table_cleared") and not names().has(&"goal_reached"), "a bounty table: table_cleared only, no goal_reached: %s" % str(names()))
	s.queue_free()
	# 3) Missed: one hand, the Bloodletter doubles the miss Soul (5 -> 10).
	s = await make_table(sv, target_goal(99999, 1), [&"bloodletter"] as Array[StringName])
	var soul0 := s.run.soul
	await bank_hand(s, [5, 5, 1] as Array[int], 2)
	var misses := log.filter(func(e: Array) -> bool: return e[0] == &"goal_missed")
	check(s.run.state == BonfireRun.State.FAILED, "out of hands short of the target: FAILED (%s)" % s.run.state)
	check(misses.size() == 1 and int(misses[0][1]) == 10, "goal_missed(10) once: the real cost, 5 x2 (%s)" % str(misses))
	check(misses.size() == 1 and soul0 - s.run.soul == int(misses[0][1]), "soul_loss matches the Soul lost (%d -> %d)" % [soul0, s.run.soul])
	check(not names().has(&"goal_reached") and not names().has(&"table_cleared"), "a missed table: no goal_reached / table_cleared")
	s.queue_free()
	# 4) Giving up a target table is a miss too (plain 5 Soul).
	s = await make_table(sv, target_goal(99999, 3))
	await wait_bet(s)
	check(s.run.forfeit(), "forfeit the target table")
	misses = log.filter(func(e: Array) -> bool: return e[0] == &"goal_missed")
	check(misses.size() == 1 and int(misses[0][1]) == 5, "forfeit: goal_missed(5) (%s)" % str(misses))
	s.queue_free()
	# 5) A bounty table that runs out of hands is not a goal miss.
	s = await make_table(sv, bounty_goal(1))
	await bank_hand(s, [5, 5, 1] as Array[int], 2)
	check(s.run.state == BonfireRun.State.FAILED and not names().has(&"goal_missed"), "bounty table out of hands: no goal_missed (%s)" % str(names()))
	s.queue_free()
	await process_frame
	print("test_goal_events: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)
