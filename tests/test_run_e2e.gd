## One seeded run end to end through the real Bonfire3D: RunScreen opens
## every table in run mode with the run's dice (some carrying face mods),
## an auto-player rigs throws that make the next required bounty, pots it
## and banks, CONTINUE emits finished(TableOutcome), and the run applies it,
## through all 3 floors to Run won / Run over.
##   godot --headless --path . --script res://tests/test_run_e2e.gd
extends SceneTree

const S := MapRun.Screen

var _passed: int = 0
var _failed: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _check(cond: bool, name: String) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		print("FAIL: ", name)


## Values that make bounty b (and a legal pot) under the table's rules:
## no 6s (Cold Sixes; and 6s are Madame Shuffle's decoys), never the Pit
## Boss's locked value, runs as 1-5 / 2-6 (Straight Man counts only those).
func _pattern(b: BountyData, r: BonfireRun) -> Array[int]:
	var bad: Array[int] = [6]
	for rule in r.rules:
		if rule is RulePitBoss:
			bad.append((rule as RulePitBoss).locked)
	var good: Array[int] = []
	for v in [5, 4, 3, 2, 1]:
		if not bad.has(v):
			good.append(v)
	var out: Array[int] = []
	match b.kind:
		BountyData.Kind.N_OF_A_KIND:
			for i in b.n:
				out.append(b.face if b.face > 0 else good[0])
		BountyData.Kind.RUN, BountyData.Kind.STRAIGHT_5:
			var start := 2 if bad.slice(1).any(func(v: int) -> bool: return v >= 1 and v <= 5) else 1
			for v in range(start, start + 5):
				out.append(v)
		BountyData.Kind.TWO_PAIR:
			out = [good[0], good[0], good[1], good[1]] as Array[int]
		BountyData.Kind.FULL_HOUSE:
			out = [good[0], good[0], good[0], good[1], good[1]] as Array[int]
	return out


## Rig slots so the pattern lands on plain faces; returns [slots, pot indices].
func _plan(t: Bonfire3D, values: Array[int]) -> Array:
	var n := t.dice.size()
	var slots: Array[int] = []
	slots.resize(n)
	slots.fill(0)
	var pot: Array[int] = []
	for v in values:
		for i in n:
			if slots[i] != 0:
				continue
			var td := t.table_die(t.dice[i])
			var k := td.slot_for_value(v)
			if k > 0 and td.mod_at(k) == null:
				slots[i] = k
				pot.append(i)
				break
	for i in n:
		if slots[i] == 0:
			var td := t.table_die(t.dice[i])
			slots[i] = maxi(td.slot_for_value(6), 1)
	return [slots, pot]


var forfeits := 0


func _play_table(t: Bonfire3D) -> TableOutcome:
	var got: Array = []
	t.finished.connect(func(o: TableOutcome) -> void: got.append(o))
	var r := t.run
	for hand in 20:
		if r.is_over():
			break
		for k in 300:
			if t.phase == Table3D.Phase.BET:
				break
			await process_frame
		var want: BountyData = null
		for b: BountyData in r.goal.required:
			if not r.is_ticked(b):
				want = b
				break
		var p := _plan(t, _pattern(want, r))
		t.rig_slots(p[0])
		if not t.quick_throw():
			print("  quick_throw refused: phase %d, can_throw '%s', rules %s" % [t.phase, t.can_throw(), str(t.setup.rules)])
			break
		await t.sequence_finished
		for i: int in p[1]:
			t.pick_die(i)
		if not r.can_continue():
			# The table's rules spoiled the rig (e.g. Madame Shuffle with no decoy): give up this table.
			forfeits += 1
			t.forfeit()
			break
		await t.bank()
	for k in 300:
		if r.is_over() and t.bhud.continue_button.visible:
			break
		await process_frame
	if not r.is_over():
		print("  table not over: hands_left %d, phase %d, rules %s" % [r.hands_left, t.phase, str(t.setup.rules)])
	t.bhud.continue_pressed.emit()
	await process_frame
	return got[0] if got.size() == 1 else null


func _run() -> void:
	var scene: RunScreen = (load("res://scenes/run.tscn") as PackedScene).instantiate()
	scene.run_seed = 4242
	root.add_child(scene)
	await process_frame
	var run := scene.run
	run.progress.set_face(0, 3, &"hellfire")
	run.progress.set_face(1, 5, &"wild")
	run.progress.set_face(2, 1, &"twin")
	run.progress.set_face(3, 0, RunDie.BLANK)
	var tables := 0
	var outcomes_ok := true
	var mods_on_table := false
	var floors_seen: Array[int] = []
	for step in 400:
		await process_frame
		if not floors_seen.has(run.floor_index):
			floors_seen.append(run.floor_index)
		match run.screen:
			S.MAP:
				run.choose_node(run.map.reachable()[0])
			S.TABLE:
				scene._play_table()
				var t: Bonfire3D = scene._table
				t.test_speed = 10.0
				await process_frame
				await process_frame
				mods_on_table = mods_on_table or (t.table_die(t.all_dice[0]).mod_at(4) != null
					and t.all_dice[0].faces.get_node("FaceMods").get_child_count() > 0)
				var soul_before := run.progress.soul
				var o := await _play_table(t)
				tables += 1
				outcomes_ok = outcomes_ok and o != null and scene._table == null and run.progress.soul >= mini(o.soul_after, run.progress.max_soul) \
					and (o.cleared or run.screen != S.REWARD)
				if o == null:
					break
				print("table %d (%s): cleared=%s soul %d -> %d, +%d Embers, hands %d" % [tables, o.cleared, o.cleared, soul_before, o.soul_after, o.embers, o.hands_used])
			S.REWARD:
				if not run.take_seal(0):
					run.take_seal(-1)
			S.EVENT:
				var done := false
				for i in run.event.choices.size():
					var c := run.event.choices[i]
					if done or not EventApplier.can_choose(c, run.progress):
						continue
					var picks: Array[Vector2i] = []
					for k in EventApplier.picks_needed(c):
						picks.append(run.progress.modded_faces()[0] if c.requires_face_mod else Vector2i(4, k))
					done = not run.choose_event(i, picks).is_empty() and run.screen != S.EVENT
				if not done:
					run.screen = S.MAP
			S.REST:
				run.rest_heal()
			S.SHOP:
				run.leave()
			_:
				break
	print("forfeited tables: %d" % forfeits)
	print("run ended: %s on floor %d after %d tables, contract %d" % [S.keys()[run.screen], run.floor_index + 1, tables, run.progress.contract_pieces])
	_check(mods_on_table, "the run's face mods are on the 3D table's dice (decals)")
	_check(tables >= 3 and outcomes_ok, "every table played on Bonfire3D; finished(TableOutcome) applied, table freed")
	_check(run.screen == S.RUN_WON or run.screen == S.RUN_OVER, "the run reaches an end screen")
	_check(run.screen != S.RUN_WON or (run.progress.contract_pieces == 3 and floors_seen.size() == 3), "Run won only with all 3 contract pieces")
	_check(floors_seen.size() == 3, "played into floor 3")
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	scene.queue_free()
	await process_frame
	quit(1 if _failed > 0 else 0)
