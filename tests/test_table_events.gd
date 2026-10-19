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
	return log.filter(func(e: Array) -> bool: return not [&"die_impact", &"die_lit_changed"].has(e[0])).map(func(e: Array) -> StringName: return e[0])


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


func _run() -> void:
	t = load("res://resources/tuning/bonfire_tuning.tres") as BonfireTuning
	var sv := SubViewport.new()
	sv.size = Vector2i(1920, 1080)
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(sv)
	var st := TableSetup.sandbox(t, 5)
	st.table_seed = 5
	var s := (load("res://scenes/bonfire.tscn") as PackedScene).instantiate() as Bonfire3D
	s.setup = st
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
			"bust", "banked", "bounty_claimed", "table_cleared", "boss_cheat", "mod_triggered"]:
		check(names.has(want), "signal %s" % want)
	listen(ev)
	# Hand 1: throw 4-4-4-5-2, a refused pick, pot the Triple (rethrow).
	await throw_faces(s, [4, 4, 4, 5, 2] as Array[int])
	check(not s.pick_die(4), "the cold 2 is refused")
	for i in 3:
		s.pick_die(i)
	check(s.throw_again(), "pot the Triple")
	await wait_bet(s)
	# Throw the 2 cold dice: 5-5, pot the Pair by banking.
	await throw_faces(s, [5, 5] as Array[int])
	s.pick_die(0)
	s.pick_die(1)
	await s.bank()
	await wait_bet(s)
	# Hand 2: pot the Triple again, then the 2 cold dice burn (2-3).
	await throw_faces(s, [4, 4, 4, 5, 2] as Array[int])
	for i in 3:
		s.pick_die(i)
	check(s.throw_again(), "hand 2: pot the Triple")
	await wait_bet(s)
	await throw_faces(s, [2, 3] as Array[int])
	for k in 60:
		await process_frame
	var order := main_order()
	var want: Array[StringName] = [&"dice_thrown", &"dice_settled", &"no_score", &"combo_potted",
		&"dice_thrown", &"dice_settled", &"combo_potted", &"banked", &"bounty_claimed",
		&"dice_thrown", &"dice_settled", &"combo_potted",
		&"dice_thrown", &"dice_settled", &"bust"]
	check(order == want, "signal order: pot, bank, bust (%s)" % str(order))
	# Payloads.
	var p1 := first(&"combo_potted")
	check(p1 >= 0 and log[p1][1] == &"trips" and (log[p1][2] as Array).size() == 3 and log[p1][3] == 126 and log[p1][4] == 3,
		"combo_potted(trips, 3 dice, 126, x3) (%s)" % str(log[p1] if p1 >= 0 else []))
	var thrown := first(&"dice_thrown")
	check(thrown >= 0 and float(log[thrown][1]) > 0.0, "dice_thrown carries the flick speed (%s)" % str(log[thrown] if thrown >= 0 else []))
	var lit := first(&"die_lit_changed")
	check(lit > first(&"dice_settled") and lit < p1 and log[lit][2] == true, "dice light after they settle, before the pot")
	var lit_ids: Array = []
	for e: Array in log.slice(0, p1):
		if e[0] == &"die_lit_changed" and e[2]:
			lit_ids.append(e[1])
	lit_ids.sort()
	check(lit_ids == [0, 1, 2, 3], "the 4-4-4-5 light (handful ids %s), the 2 stays off" % str(lit_ids))
	var p2 := first(&"combo_potted", p1 + 1)
	check(p2 >= 0 and log[p2][1] == &"pair" and log[p2][2] == [3, 4], "bank pots the Pair: the 2 cold dice keep their handful ids 3, 4 (%s)" % str(log[p2] if p2 >= 0 else []))
	var bk := first(&"banked")
	check(bk >= 0 and p2 >= 0 and int(log[bk][1]) == 126 + int(log[p2][3]), "banked(points) = Triple 126 + the Pair (%s)" % str(log[bk] if bk >= 0 else []))
	var cl := first(&"bounty_claimed")
	check(cl >= 0 and log[cl][1] == &"triple", "bounty_claimed(triple)")
	var bu := first(&"bust")
	check(bu >= 0 and int(log[bu][1]) == t.bust_soul_loss, "bust(soul_loss = %d) (%s)" % [t.bust_soul_loss, str(log[bu] if bu >= 0 else [])])
	check(log.slice(p2).any(func(e: Array) -> bool: return e[0] == &"die_lit_changed" and not e[2]), "banked dice go back off (die_lit_changed false)")
	for e: Array in log:
		if e[0] == &"die_impact":
			check(e[1] is StringName and e[2] is float and e[3] is StringName and e[4] is int, "die_impact payload types")
			break
	sv.queue_free()
	await process_frame
	print("test_table_events: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)
