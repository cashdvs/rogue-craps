## TableEvents (scripts/bonfire/table_events.gd): the plain-signal surface
## the VFX / audio side listens to. Drives one pot, a bank and a bust on the
## 3D Bonfire table and checks which signals fire, in what order, and with
## what payloads.
##   godot --headless --path . --script res://tests/test_table_events.gd
extends SceneTree

var _passed: int = 0
var _failed: int = 0
var t: BonfireTuning
var log: Array = []


func _initialize() -> void:
	# The sandbox table_1 is a real F1 target table now; this suite tests bounties.
	var sandbox_tuning := load("res://resources/tuning/bonfire_tuning.tres") as BonfireTuning
	sandbox_tuning.table_goal = preload("res://tests/bounty_fixture.gd").goal(self)
	if sandbox_tuning.table_goal == null:
		return  # fixture missing: goal() printed why and quits
	set_meta(&"sandbox_tuning", sandbox_tuning)  # keep it cached so every load sees the fixture
	_run.call_deferred()


func check(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		print("FAIL  ", what)


func throw_faces(s: Bonfire3D, faces: Array[int]) -> void:
	for k in 400:
		if s.phase == Table3D.Phase.BET and not s.bhud.countup.is_playing() and not s.hand_moving():
			break
		await process_frame
	s.rig_faces(faces)
	if not s.quick_throw():
		check(false, "throw %s starts" % str(faces))
		return
	await s.throw_resolved
	await s.sequence_finished


func wait_bet(s: Bonfire3D) -> void:
	for k in 400:
		if s.phase == Table3D.Phase.BET and not s.bhud.countup.is_playing():
			return
		await process_frame


## The log without the die-level noise (impacts, lit changes).
func main_order() -> Array:
	return log.filter(func(e: Array) -> bool: return not [&"die_impact", &"die_lit_changed", &"selection_changed"].has(e[0])).map(func(e: Array) -> StringName: return e[0])


func first(name: StringName, from: int = 0) -> int:
	for i in range(from, log.size()):
		if log[i][0] == name:
			return i
	return -1


func listen(ev: TableEvents) -> void:
	for sig in ev.get_signal_list():
		var n := StringName(sig["name"])
		if ev.get_script().get_script_signal_list().all(func(d: Dictionary) -> bool: return d["name"] != n):
			continue
		var argc: int = (sig["args"] as Array).size()
		match argc:
			0: ev.connect(n, func() -> void: log.append([n]))
			1: ev.connect(n, func(a: Variant) -> void: log.append([n, a]))
			2: ev.connect(n, func(a: Variant, b: Variant) -> void: log.append([n, a, b]))
			4: ev.connect(n, func(a: Variant, b: Variant, c: Variant, d: Variant) -> void: log.append([n, a, b, c, d]))
			5: ev.connect(n, func(a: Variant, b: Variant, c: Variant, d: Variant, e: Variant) -> void: log.append([n, a, b, c, d, e]))
			7: ev.connect(n, func(a: Variant, b: Variant, c: Variant, d: Variant, e: Variant, f: Variant, g: Variant) -> void: log.append([n, a, b, c, d, e, f, g, Time.get_ticks_msec()]))


func _run() -> void:
	t = load("res://resources/tuning/bonfire_tuning.tres") as BonfireTuning
	var sv := SubViewport.new()
	sv.size = Vector2i(1920, 1080)
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(sv)
	var st := TableSetup.sandbox(t, 3)  # 3 dice: a Hot Hand rethrow can bust
	st.table_seed = 5
	var s := (load("res://scenes/bonfire.tscn") as PackedScene).instantiate() as Bonfire3D
	s.setup = st
	s.setup.nerve_uses = 0  # these checks expect a plain bust (no Nerve rescue pause)
	s.tutorial_override = 0
	s.test_speed = 10.0
	sv.add_child(s)
	await process_frame
	await process_frame
	var ev: TableEvents = s.events
	check(ev != null and ev.get_parent() == s and ev is TableEvents, "the table owns a TableEvents node (table.events)")
	var names: Array = []
	for d in ev.get_script().get_script_signal_list():
		names.append(String(d["name"]))
	for want in ["dice_thrown", "die_impact", "dice_settled", "die_lit_changed", "combo_potted", "hot_hand", "no_score",
			"bust", "banked", "bounty_claimed", "table_cleared", "boss_cheat", "mod_triggered",
			"hot_hand_fly", "table_started", "triggers_resolved"]:
		check(names.has(want), "signal %s" % want)
	check(s.has_method("get_speed_mode") and s.get_speed_mode() == s.speed_mode and s.has_method("is_reduced_motion") and s.is_reduced_motion() == s.reduced_motion,
		"read-only speed_mode / reduced_motion getters on the table")
	listen(ev)
	# The table no longer plays the sounds the feel layer (scripts/fx/) owns.
	# With the feel layer merged (TableAudio, PR #72) it plays them from the
	# signals; count only the table's own calls here.
	var fx := s.get_node_or_null("TableAudio")
	if fx != null and fx.has_method("unbind"):
		fx.call("unbind")
	var played: Array = []
	s.sfx.played.connect(func(e: StringName) -> void: played.append(e))
	# Hand 1: throw 4-4-4, pot the Triple (every die: Hot Hand, rethrow).
	await throw_faces(s, [4, 4, 4] as Array[int])
	for i in 3:
		s.pick_die(i)
	check(s.throw_again(), "pot the Triple: Hot Hand")
	await wait_bet(s)
	# Throw all 3 again: 5-5-2, a refused pick, pot the Pair by banking.
	await throw_faces(s, [5, 5, 2] as Array[int])
	check(not s.pick_die(2), "the cold 2 is refused")
	s.pick_die(0)
	s.pick_die(1)
	await s.bank()
	await wait_bet(s)
	# Hand 2: pot the Triple again (Hot Hand), then all 3 dice burn (2-4-6).
	await throw_faces(s, [4, 4, 4] as Array[int])
	for i in 3:
		s.pick_die(i)
	check(s.throw_again(), "hand 2: pot the Triple: Hot Hand")
	await wait_bet(s)
	await throw_faces(s, [2, 4, 6] as Array[int])
	for k in 60:
		await process_frame
	var order := main_order()
	var want: Array[StringName] = [&"dice_thrown", &"dice_settled", &"triggers_resolved", &"combo_potted", &"triggers_resolved", &"hot_hand_fly", &"hot_hand",
		&"dice_thrown", &"dice_settled", &"triggers_resolved", &"no_score", &"combo_potted", &"triggers_resolved", &"banked", &"bounty_claimed",
		&"dice_thrown", &"dice_settled", &"triggers_resolved", &"combo_potted", &"triggers_resolved", &"hot_hand_fly", &"hot_hand",
		&"dice_thrown", &"dice_settled", &"triggers_resolved", &"bust"]
	check(order == want, "signal order: pot, bank, bust (%s)" % str(order))
	# Payloads.
	var p1 := first(&"combo_potted")
	check(p1 >= 0 and log[p1][1] == &"trips" and (log[p1][2] as Array).size() == 3 and log[p1][3] == 126 and log[p1][4] == 3 and log[p1][5] == JuicePlan.tier(126, t),
		"combo_potted(trips, 3 dice, 126, x3, score tier) (%s)" % str(log[p1] if p1 >= 0 else []))
	var thrown := first(&"dice_thrown")
	check(thrown >= 0 and float(log[thrown][1]) > 0.0, "dice_thrown carries the flick speed (%s)" % str(log[thrown] if thrown >= 0 else []))
	var lit := first(&"die_lit_changed")
	check(lit > first(&"dice_settled") and lit < p1 and log[lit][2] == true, "dice light after they settle, before the pot")
	var lit_ids: Array = []
	for e: Array in log.slice(0, p1):
		if e[0] == &"die_lit_changed" and e[2]:
			lit_ids.append(e[1])
	lit_ids.sort()
	check(lit_ids == [0, 1, 2], "the 4-4-4 light (handful ids %s)" % str(lit_ids))
	var p2 := first(&"combo_potted", p1 + 1)
	check(p2 >= 0 and log[p2][1] == &"pair" and log[p2][2] == [0, 1], "bank pots the Pair: the Hot Hand dice keep their handful ids 0, 1 (%s)" % str(log[p2] if p2 >= 0 else []))
	var bk := first(&"banked")
	check(bk >= 0 and p2 >= 0 and int(log[bk][1]) == 126 + int(log[p2][3]), "banked(points) = Triple 126 + the Pair (%s)" % str(log[bk] if bk >= 0 else []))
	var cl := first(&"bounty_claimed")
	check(cl >= 0 and log[cl][1] == &"triple", "bounty_claimed(triple)")
	var bu := first(&"bust")
	check(bu >= 0 and int(log[bu][1]) == t.bust_soul_loss and log[bu][2] == [0, 1, 2], "bust(soul_loss = %d, the 3 busted dice 0, 1, 2) (%s)" % [t.bust_soul_loss, str(log[bu] if bu >= 0 else [])])
	# selection_changed (empty: not picking) may sit between them.
	var tb := bu - 1
	while tb > 0 and log[tb][0] == &"selection_changed":
		tb -= 1
	var tr_bust: Array = log[tb][1] if bu > 0 and log[tb][0] == &"triggers_resolved" else []
	check(tr_bust.size() == 1 and tr_bust[0]["stage"] == &"lit" and tr_bust[0]["row_id"] == &"bust" and tr_bust[0]["ctx"]["die_ids"] == [0, 1, 2],
		"the bust throw's triggers: one lit-check entry, bust (%s)" % str(tr_bust))
	var plain_scoring := log.filter(func(e: Array) -> bool: return e[0] == &"triggers_resolved" and not (e[1] as Array).is_empty())
	check(plain_scoring.size() == 1, "plain dice: only the bust has triggers (%d lists)" % plain_scoring.size())
	for bad: StringName in [&"dice_shake", &"chip_refuse", &"hot_hand", &"dice_hit"]:
		check(not played.has(bad), "the table itself never plays %s (scripts/fx/ does)" % bad)
	check(log.slice(p2).any(func(e: Array) -> bool: return e[0] == &"die_lit_changed" and not e[2]), "banked dice go back off (die_lit_changed false)")
	for e: Array in log:
		if e[0] == &"die_impact":
			check(e[1] is StringName and e[2] is float and e[3] is StringName and e[4] is int, "die_impact payload types")
			break
	s = await modded_table(s)
	s = await cleared_table(s)
	s = await landing_table(s)
	sv.queue_free()
	await process_frame
	print("test_table_events: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func goal(required: Array[StringName], hands: int = 5) -> TableGoal:
	var g := TableGoal.new()
	g.hands = hands
	for id in required:
		var b := BountyData.new()
		b.id = id
		b.display_name = String(id)
		b.kind = BountyData.Kind.N_OF_A_KIND
		b.n = 3
		g.required.append(b)
	var hard := BountyData.new()
	hard.id = &"five"
	hard.kind = BountyData.Kind.N_OF_A_KIND
	hard.n = 5
	g.bonus.append(hard)
	return g


## A fresh table scene for `st` (replaces `old`), listened to from its start.
func new_table(old: Bonfire3D, st: TableSetup) -> Bonfire3D:
	var sv := old.get_parent()
	old.queue_free()
	await process_frame
	log.clear()
	st.table_seed = 5
	var s := (load("res://scenes/bonfire.tscn") as PackedScene).instantiate() as Bonfire3D
	s.setup = st
	s.setup.nerve_uses = 0  # these checks expect a plain bust (no Nerve rescue pause)
	s.tutorial_override = 0
	s.test_speed = 10.0
	# TableEvents exists from the start of _ready: listen before new_run runs.
	s.child_entered_tree.connect(func(n: Node) -> void:
		if n is TableEvents:
			listen(n as TableEvents))
	sv.add_child(s)
	await process_frame
	await process_frame
	return s


## A pot with face mods: the scoring triggers come out before the count-up,
## in pip order, with start times that match when mod_triggered fires.
func modded_table(s: Bonfire3D) -> Bonfire3D:
	var st := TableSetup.sandbox(t, 5)
	var hell := load("res://resources/mods/hellfire.tres") as FaceModData
	var twin := load("res://resources/mods/twin.tres") as FaceModData
	(st.dice[0] as TableDie).mods[3] = hell
	(st.dice[1] as TableDie).mods[3] = twin
	s = await new_table(s, st)
	check(log.size() > 0 and log[0][0] == &"table_started", "a table opens with table_started (%s)" % str(log.slice(0, 1)))
	s.test_speed = 1.0
	await throw_faces(s, [4, 4, 4, 5, 2] as Array[int])
	for i in 3:
		s.pick_die(i)
	var t0 := 0
	var cp := -1
	check(s.throw_again(), "modded: pot the Triple")
	t0 = Time.get_ticks_msec()
	cp = first(&"combo_potted")
	var tr: Array = log[cp + 1][1] if cp >= 0 and cp + 1 < log.size() and log[cp + 1][0] == &"triggers_resolved" else []
	check(tr.size() == 2, "two scoring triggers: Hellfire, Twin (%s)" % str(tr))
	if tr.size() == 2:
		check(tr[0]["stage"] == &"scoring" and tr[0]["row_id"] == hell.id and tr[0]["die_id"] == 0 and tr[1]["row_id"] == twin.id and tr[1]["die_id"] == 1,
			"in pip order, with die ids")
		check(tr[0]["anchor"] == &"pip" and tr[0]["ctx"]["flavor"] == &"mult_factor" and tr[1]["ctx"]["count"] == 2 and tr[1]["ctx"]["target_die"] == 1,
			"anchor pip; ctx flavor / count / target_die (%s)" % str(tr[1]["ctx"]))
		var plan := JuicePlan.timeline(4, 0, JuicePlan.tier(int(log[cp][3]), t), 0, t)
		for e: Dictionary in tr:
			var pip_i := 0 if e["die_id"] == 0 else 1
			var want_pip := float(plan["pips"][pip_i])
			check(absf(float(e["pip_s"]) - want_pip) < 0.001 and absf(float(e["start_s"]) - maxf(want_pip - TableEvents.PIP_LEAD, 0.0)) < 0.001,
				"%s: pip_s %.3f, start_s = pip_s - 0.167 (>= 0) %.3f" % [e["row_id"], e["pip_s"], e["start_s"]])
		check(float(tr[1]["pip_s"]) > float(tr[0]["pip_s"]) and float(tr[1]["start_s"]) <= float(tr[1]["pip_s"]), "the Twin's pip comes later; each starts on or before its pip")
	await wait_bet(s)
	var mods := log.filter(func(e: Array) -> bool: return e[0] == &"mod_triggered")
	check(mods.size() == 2, "mod_triggered once per mod die (%d)" % mods.size())
	if mods.size() == 2 and tr.size() == 2:
		check(mods[0][6] == &"pip" and (mods[0][7] as Dictionary).has("direction") and mods[1][7] == tr[1]["ctx"], "mod_triggered(..., anchor, ctx) matches the trigger list")
		for k in 2:
			var at := (int(mods[k][8]) - t0) / 1000.0
			check(absf(at - float(tr[k]["pip_s"])) < 0.08, "%s fires at its pip (%.3f s vs pip_s %.3f)" % [mods[k][1], at, tr[k]["pip_s"]])
	s.test_speed = 10.0
	return s


## TABLE CLEARED: once per table, even with Leave after the clearing bank;
## a new table resets it. Also Hot Hand: fly start, then the arrival.
func cleared_table(s: Bonfire3D) -> Bonfire3D:
	var st := TableSetup.sandbox(t, 3)
	st.goal = goal([&"triple"])
	s = await new_table(s, st)
	# 4-4-4: all three score, Hot Hand.
	await throw_faces(s, [4, 4, 4] as Array[int])
	for i in 3:
		s.pick_die(i)
	var fly_ms := Time.get_ticks_msec()
	check(s.throw_again(), "hot: pot all three")
	for k in 600:
		if first(&"hot_hand") >= 0:
			break
		await process_frame
	var hf := first(&"hot_hand_fly")
	var hh := first(&"hot_hand")
	check(hf >= 0 and hh > hf and log[hf][1] == [0, 1, 2] and float(log[hf][2]) > 0.0, "hot_hand_fly(die ids, seconds) before hot_hand (%s)" % str(log.slice(hf, hf + 1) if hf >= 0 else []))
	check(hh >= 0 and int(log[hh][1]) == 1, "hot_hand(count 1) when the dice arrive")
	await wait_bet(s)
	await throw_faces(s, [5, 1, 2] as Array[int])
	s.pick_die(0)
	s.pick_die(1)
	await s.bank()
	await wait_bet(s)
	var cl := log.filter(func(e: Array) -> bool: return e[0] == &"table_cleared")
	check(cl.size() == 1, "the clearing bank sends table_cleared (%d)" % cl.size())
	check(s.leave(), "leave the cleared table")
	cl = log.filter(func(e: Array) -> bool: return e[0] == &"table_cleared")
	check(cl.size() == 1, "Leave after the clear: still exactly one table_cleared (%d)" % cl.size())
	await wait_bet(s)
	log.clear()
	s.new_run(9)
	check(log.size() > 0 and log[0][0] == &"table_started", "new_run (same node) emits table_started")
	s._emit_table_cleared()
	s._emit_table_cleared()
	cl = log.filter(func(e: Array) -> bool: return e[0] == &"table_cleared")
	check(cl.size() == 1, "a new table may clear once again (%d)" % cl.size())
	return s


## The settle half: boss face changes, then the lit check (dice a rule keeps dark).
func landing_table(s: Bonfire3D) -> Bonfire3D:
	var st := TableSetup.sandbox(t, 5)
	st.rules = [&"madame_shuffle", &"cold_sixes"]
	s = await new_table(s, st)
	await throw_faces(s, [6, 6, 1, 5, 2] as Array[int])
	var tr_i := first(&"triggers_resolved")
	var tr: Array = log[tr_i][1] if tr_i >= 0 else []
	var stages: Array = tr.map(func(e: Dictionary) -> StringName: return e["stage"])
	var boss := stages.find(&"boss")
	var lit := stages.find(&"lit")
	check(lit >= 0, "a lit-check entry for the 6 Cold Sixes keeps dark (%s)" % str(stages))
	check(boss >= 0, "Madame Shuffle's reroll is a boss trigger (%s)" % str(stages))
	var sorted := stages.duplicate()
	var order := [&"land", &"copies", &"boss", &"lit", &"scoring"]
	sorted.sort_custom(func(a: StringName, b: StringName) -> bool: return order.find(a) < order.find(b))
	check(stages == sorted, "triggers in resolve order (%s)" % str(stages))
	if boss >= 0:
		check(tr[boss]["row_id"] == &"madame_shuffle" and tr[boss]["start_s"] == 0.0 and tr[boss]["ctx"].has("from"), "boss entry: rule id, starts at 0, from / to")
	if lit >= 0:
		check(float(tr[lit]["start_s"]) == (Bonfire3D.FLIP_TIME + 0.08 if boss >= 0 else 0.0) and tr[lit]["row_id"] == &"cold_sixes",
			"lit check after the flips: a 6 kept dark by Cold Sixes (%s)" % str(tr[lit]))
	var bc := first(&"boss_cheat")
	check(bc > tr_i, "triggers_resolved comes before the face flips (boss_cheat)")
	return s
