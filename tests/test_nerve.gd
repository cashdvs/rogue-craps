## Headless test: NerveState (scripts/core/nerve_state.gd), the logic side of
## design/nerve_v1.md: one nudge per table, adjacent face on the die's own
## face list with no wrap, undo until pot / rethrow / bank, refills per table,
## copy dice excluded, bust rescue via lit_fn, Wild / mods stay on their faces,
## and the run -> TableSetup.nerve_uses plumbing.
##
## Run:
##   godot --headless --path . --script res://tests/test_nerve.gd
extends SceneTree

var _passed: int = 0
var _failed: int = 0
var _wild: FaceModData
var _blank: FaceModData


func check(ok: bool, msg: String) -> void:
	if ok:
		_passed += 1
	else:
		_failed += 1
		print("FAIL: ", msg)


func _initialize() -> void:
	_wild = load("res://resources/mods/wild.tres")
	_blank = load("res://resources/mods/blank.tres")
	_test_steps()
	_test_once_and_undo()
	_test_commit_points()
	_test_refill()
	_test_exclusions()
	_test_ui_states()
	_test_mods()
	_test_rescue()
	_test_duplicates()
	_test_throw_lifecycle()
	_test_setup_plumbing()
	_test_map_run_e2e()
	_test_no_soul_or_embers()
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	_wild = null
	_blank = null
	quit(1 if _failed > 0 else 0)


func _die(id: StringName, shape: StringName, faces: Array = []) -> TableDie:
	var d := TableDie.new(id, String(id), shape)
	if not faces.is_empty():
		d.faces.assign(faces)
	return d


func _nerve(dice: Array[TableDie], slots: Array[int]) -> NerveState:
	var n := NerveState.new()
	n.setup(dice)
	n.begin_throw(slots)
	return n


func _bones(count: int) -> Array[TableDie]:
	var out: Array[TableDie] = []
	for i in count:
		out.append(TableDie.new())
	return out


func _test_steps() -> void:
	var up := NerveState.UP
	var dn := NerveState.DOWN
	var bone := TableDie.new()
	check(NerveState.target_slot(bone, 3, up) == 4 and NerveState.target_slot(bone, 3, dn) == 2, "Bone: 3 -> 4 / 2")
	check(NerveState.target_slot(bone, 6, up) == 0 and NerveState.target_slot(bone, 1, dn) == 0, "Bone: no wrap (6 up, 1 down)")
	var cal := _die(DiceIds.DIE_CALTROP, DiceIds.SHAPE_D4)
	check(NerveState.target_slot(cal, 4, up) == 0 and NerveState.target_slot(cal, 4, dn) == 3, "Caltrop d4: 4 can't go up, 4 -> 3")
	var lan := _die(DiceIds.DIE_LANTERN, DiceIds.SHAPE_D8)
	check(NerveState.target_slot(lan, 7, up) == 8 and NerveState.target_slot(lan, 8, up) == 0, "Lantern d8: 7 -> 8, no 8 -> 1")
	var tithe := _die(DiceIds.DIE_TITHE, DiceIds.SHAPE_D10)
	check(NerveState.target_slot(tithe, 9, up) == 10 and NerveState.target_slot(tithe, 10, up) == 0, "Tithe d10: 9 -> 10, no wrap")
	var mid := _die(DiceIds.DIE_MIDNIGHT, DiceIds.SHAPE_D12)
	check(NerveState.target_slot(mid, 11, up) == 12 and NerveState.target_slot(mid, 12, up) == 0, "Midnight d12: 11 -> 12, no wrap")
	var ver := _die(DiceIds.DIE_VERDICT, DiceIds.SHAPE_D20)
	check(NerveState.target_slot(ver, 19, up) == 20 and NerveState.target_slot(ver, 2, dn) == 1 and NerveState.target_slot(ver, 1, dn) == 0, "Verdict d20: 19 -> 20, 2 -> 1, no 1 -> 20")
	var keg := _die(DiceIds.DIE_POWDER_KEG, DiceIds.SHAPE_D6, [1, 1, 2, 2, 3, 3])
	var k_up := NerveState.target_slot(keg, 3, up)
	check(keg.value_at(k_up) == 3 and keg.value_at(NerveState.target_slot(keg, 2, up)) == 2, "Powder Keg: steps by value (2 -> 3, 1 -> 2)")
	check(NerveState.target_slot(keg, 6, up) == 0 and NerveState.target_slot(keg, 1, dn) == 0, "Powder Keg: 3 can't go up, 1 can't go down")
	var kb := _die(DiceIds.DIE_KNUCKLEBONE, DiceIds.SHAPE_TALUS)
	check(kb.faces == ([1, 3, 4, 6] as Array[int]), "Knucklebone faces 1/3/4/6")
	check(kb.value_at(NerveState.target_slot(kb, 3, up)) == 6 and kb.value_at(NerveState.target_slot(kb, 2, dn)) == 1, "Knucklebone: 4 -> 6, 3 -> 1 (never 2 or 5)")
	check(kb.value_at(NerveState.target_slot(kb, 1, up)) == 3 and NerveState.target_slot(kb, 4, up) == 0, "Knucklebone: 1 -> 3, 6 can't go up")
	check(NerveState.target_slot(bone, 3, 0) == 0 and NerveState.target_slot(bone, 0, up) == 0 and NerveState.target_slot(bone, 7, dn) == 0, "bad dir / slot -> 0")


func _test_once_and_undo() -> void:
	var n := _nerve(_bones(5), [1, 2, 3, 4, 6] as Array[int])
	check(n.uses_left() == 1 and n.can_nudge(0), "fresh table: 1 Nerve")
	check(n.nudge(0, NerveState.DOWN) == -1, "1 can't go down: -1, Nerve kept")
	check(n.uses_left() == 1 and n.can_nudge_dir(0, NerveState.UP) and not n.can_nudge_dir(0, NerveState.DOWN), "down arrow greyed on a 1")
	check(not n.can_nudge_dir(4, NerveState.UP) and n.can_nudge_dir(4, NerveState.DOWN), "up arrow greyed on a 6")
	check(n.nudge(2, NerveState.UP) == 4 and n.slots[2] == 4, "nudge 3 up -> slot 4")
	check(n.uses_left() == 0 and n.nudged_die() == 2, "pending nudge counts as used")
	check(n.nudge(1, NerveState.UP) == -1 and n.refusal(1) == "nerve_used_refusal", "one nudge per table")
	check(n.undo(1) == -1, "undo only the nudged die")
	check(n.undo(2) == 3 and n.slots[2] == 3 and n.uses_left() == 1, "tap again: undo, Nerve returns")
	check(n.undo(2) == -1, "nothing left to undo")
	check(n.nudge(1, NerveState.DOWN) == 1, "after undo, any die can be nudged")


func _test_commit_points() -> void:
	# Pot from the throw.
	var n := _nerve(_bones(3), [2, 3, 4] as Array[int])
	n.nudge(0, NerveState.UP)
	n.mark_potted(0)
	check(n.undo(0) == -1 and n.uses_left() == 0 and n.ui_state() == NerveState.UiState.SPENT, "pot: nudge locked, spent")
	check(n.refusal(0) == "nerve_used_refusal", "potted after use: used refusal first")
	# Rethrow / bank (commit) and a new throw.
	var r := _nerve(_bones(3), [2, 3, 4] as Array[int])
	r.nudge(1, NerveState.DOWN)
	r.commit()
	check(r.undo(1) == -1 and r.uses_left() == 0, "rethrow / bank: spent")
	var b := _nerve(_bones(3), [2, 3, 4] as Array[int])
	b.nudge(1, NerveState.DOWN)
	b.begin_throw([5, 5, 5] as Array[int])
	check(b.uses_left() == 0 and not b.can_nudge(0), "next throw: earlier nudge is spent")
	# Potting without using Nerve keeps it for a later throw, but closes this one.
	var k := _nerve(_bones(3), [2, 3, 4] as Array[int])
	k.mark_potted(0)
	check(k.uses_left() == 1 and k.refusal(0) == "nerve_potted_refusal" and not k.can_nudge(1), "after a pot, this throw is closed (before you pot)")
	k.begin_throw([0, 2, 5] as Array[int])
	check(k.can_nudge(1) and not k.can_nudge(0), "unused Nerve carries to the next throw; set-aside dice (slot 0) are not targets")
	var none := NerveState.new()
	none.setup(_bones(2))
	check(not none.can_nudge(0), "no settled throw: nothing to nudge")


func _test_refill() -> void:
	var n := _nerve(_bones(2), [3, 3] as Array[int])
	n.nudge(0, NerveState.UP)
	n.commit()
	check(n.uses_left() == 0, "spent")
	n.reset_table()
	check(n.uses_left() == 1 and n.ui_state() == NerveState.UiState.READY and not n.can_nudge(0), "new table (or boss re-sit): fresh Nerve, no throw yet")
	n.begin_throw([3, 3] as Array[int])
	check(n.can_nudge(0), "refilled Nerve works")
	var two := NerveState.new()
	two.setup(_bones(2), 2)
	two.begin_throw([3, 3] as Array[int])
	two.nudge(0, NerveState.UP)
	two.commit()
	two.begin_throw([3, 3] as Array[int])
	check(two.uses_left() == 1 and two.nudge(1, NerveState.UP) == 4, "nerve_uses = 2 gives two nudges")
	var zero := NerveState.new()
	zero.setup(_bones(1), 0)
	zero.begin_throw([3] as Array[int])
	check(zero.uses_left() == 0 and not zero.can_nudge(0), "nerve_uses = 0: off")


func _test_exclusions() -> void:
	var dice: Array[TableDie] = [TableDie.new(), _die(DiceIds.DIE_FERRYMAN, DiceIds.SHAPE_COIN), TableDie.new()]
	dice[2].special = DiceIds.DIE_MIRROR
	var n := _nerve(dice, [3, 1, 3] as Array[int])
	check(not n.can_nudge(1) and n.refusal(1) == "nerve_copy_refusal", "Ferryman's Coin can't be nudged")
	check(not n.can_nudge(2) and n.refusal(2) == "nerve_copy_refusal" and n.nudge(2, NerveState.UP) == -1, "Mirror can't be nudged")
	var alone := _nerve([_die(DiceIds.DIE_FERRYMAN, DiceIds.SHAPE_COIN)] as Array[TableDie], [1] as Array[int])
	check(not alone.can_nudge(0), "Coin thrown alone: still not a target")
	check(n.can_nudge(0), "the die they copy can be nudged (table re-runs copies)")
	check(n.refusal(-1) == "not_in_throw" and n.refusal(9) == "not_in_throw", "out-of-range index refused")


func _test_ui_states() -> void:
	var n := _nerve(_bones(2), [3, 3] as Array[int])
	check(n.ui_state() == NerveState.UiState.READY, "Ready")
	check(n.pick(0) and n.ui_state() == NerveState.UiState.PICKING and n.picking_die() == 0, "tap a die: Picking")
	n.cancel_pick()
	check(n.ui_state() == NerveState.UiState.READY, "cancel: Ready")
	n.pick(1)
	n.nudge(1, NerveState.UP)
	check(n.ui_state() == NerveState.UiState.NUDGED and n.picking_die() == -1, "nudge: Nudged (undo shown)")
	n.undo(1)
	check(n.ui_state() == NerveState.UiState.READY, "undo: Ready")
	n.nudge(1, NerveState.UP)
	n.commit()
	check(n.ui_state() == NerveState.UiState.SPENT and not n.pick(0), "commit: Spent, no more picks")


func _test_mods() -> void:
	# Mods stay on physical faces: a Wild on slot 6, a Blank on slot 3.
	var d := TableDie.new()
	d.mods[5] = _wild
	d.mods[2] = _blank
	var n := _nerve([d] as Array[TableDie], [5] as Array[int])
	var to := n.nudge(0, NerveState.UP)
	check(to == 6 and d.mod_at(to) == _wild, "5 -> 6 lands on the Wild face (auto-pick at the lit check)")
	check(d.mod_at(5) == null and d.mods[5] == _wild and d.mods[2] == _blank, "mods never move")
	n.undo(0)
	n.begin_throw([6] as Array[int])
	check(n.nudge(0, NerveState.DOWN) == 5 and d.mod_at(5) == null, "off the Wild face: Wild lost")
	var b := _nerve([d] as Array[TableDie], [3] as Array[int])
	check(b.can_nudge(0) and b.nudge(0, NerveState.UP) == 4, "a Blank face can be nudged off")
	var c := _nerve([d] as Array[TableDie], [2] as Array[int])
	check(c.nudge(0, NerveState.UP) == 3 and d.mod_at(3) == _blank, "nudging onto a Blank is allowed")


## A Bone-pair lit check with a Wick-style filter: 6s never light.
func _pair_lit_no_sixes(dice: Array[TableDie], slots: Array) -> bool:
	var seen := {}
	for i in slots.size():
		if int(slots[i]) <= 0:
			continue
		var v := dice[i].value_at(int(slots[i]))
		if v == 6:
			continue
		if seen.has(v):
			return true
		seen[v] = true
	return false


func _test_rescue() -> void:
	var dice := _bones(3)
	var lit := func(s: Array) -> bool: return _pair_lit_no_sixes(dice, s)
	var n := _nerve(dice, [1, 2, 4] as Array[int])
	check(n.any_nudge_lights(lit), "1-2-4 nothing lit: a nudge makes a pair -> offer Nerve or Bust")
	var opts := n.rescue_options(lit)
	check(opts.size() == 2, "rescue options: 1 up or 2 down (got %d)" % opts.size())
	check(n.uses_left() == 1 and n.slots == ([1, 2, 4] as Array[int]), "the query changes nothing")
	# Wick / Cold Sixes: a 5 nudged up to 6 stays cold, a 6 down to 5 is the counterplay.
	var w := _nerve(dice, [1, 5, 6] as Array[int])
	var wo := w.rescue_options(lit)
	check(wo.size() == 1 and int(wo[0]["die"]) == 2 and int(wo[0]["slot"]) == 5, "Wick: only 6 -> 5 rescues (5 -> 6 stays cold)")
	check(w.nudge(1, NerveState.UP) == 6, "Wick: nudging a 5 up to 6 is still allowed")
	var none := _nerve(dice, [1, 4, 6] as Array[int])
	check(not none.any_nudge_lights(lit), "no nudge lights anything: bust at once")
	var spent := _nerve(dice, [1, 3, 5] as Array[int])
	spent.nudge(0, NerveState.UP)
	spent.commit()
	check(not spent.any_nudge_lights(lit), "Nerve spent: no rescue prompt")
	var copies: Array[TableDie] = [TableDie.new(), TableDie.new()]
	copies[1].special = DiceIds.DIE_MIRROR
	var cn := _nerve(copies, [2, 3] as Array[int])
	var calls: Array = []
	cn.any_nudge_lights(func(s: Array) -> bool:
		calls.append(s.duplicate())
		return false)
	check(calls.size() == 2 and int(calls[0][1]) == 3 and int(calls[1][1]) == 3, "rescue never tries a copy die")


func _test_setup_plumbing() -> void:
	var rd := load("res://resources/map/bonfire_run.tres") as RunData
	check(rd.nerve_uses == 1, "RunData.nerve_uses = 1 in bonfire_run.tres")
	check(TableSetup.new().nerve_uses == 1, "TableSetup.nerve_uses defaults to 1")
	var rts := RunTableSetup.new()
	rts.goal = TableGoal.new()
	rts.nerve_uses = 2
	var base := load("res://resources/tuning/bonfire_tuning.tres") as BonfireTuning
	check(rts.to_table_setup(base).nerve_uses == 2, "RunTableSetup -> TableSetup.nerve_uses")
	check(RunTableSetup.new().nerve_uses == 1, "RunTableSetup default 1")


func _keg() -> TableDie:
	return _die(DiceIds.DIE_POWDER_KEG, DiceIds.SHAPE_D6, [1, 1, 2, 2, 3, 3])


func _test_duplicates() -> void:
	var blood: FaceModData = load("res://resources/mods/blood.tres")
	check(_blank.id == &"blank" and blood.id == &"blood", "mod ids: blank / blood")
	var keg := _keg()
	check(NerveState.candidate_slots(keg, 2, NerveState.UP) == ([3, 4] as Array[int]), "Keg 1 up: candidates slots 3, 4 (both 2s)")
	check(NerveState.candidate_slots(keg, 6, NerveState.UP).is_empty(), "Keg 3 up: none")
	# No score_fn: first slot in face-list order.
	var n := _nerve([keg] as Array[TableDie], [1] as Array[int])
	check(n.nudge(0, NerveState.UP) == 3, "no score_fn: first slot (3)")
	# score_fn picks the best; a tie goes to the first slot.
	var k2 := _keg()
	var a := _nerve([k2] as Array[TableDie], [1] as Array[int])
	var calls: Array = []
	var prefer4 := func(sl: Array) -> int:
		calls.append(int(sl[0]))
		return 10 if int(sl[0]) == 4 else 5
	check(a.nudge(0, NerveState.UP, prefer4) == 4 and calls == [3, 4], "score_fn: best face (slot 4) wins")
	var tie := _nerve([_keg()] as Array[TableDie], [1] as Array[int])
	check(tie.nudge(0, NerveState.UP, func(_sl: Array) -> int: return 7) == 3, "score_fn tie: first slot")
	var bone := _nerve(_bones(1), [2] as Array[int])
	var ncalls := [0]
	bone.nudge(0, NerveState.UP, func(_sl: Array) -> int:
		ncalls[0] += 1
		return 0)
	check(ncalls[0] == 0, "one candidate: score_fn not called")
	# Blank / Blood avoided when another face with that value isn't one.
	var kb := _keg()
	kb.mods[2] = _blank
	var b := _nerve([kb] as Array[TableDie], [1] as Array[int])
	check(b.nudge(0, NerveState.UP, func(sl: Array) -> int: return 99 if int(sl[0]) == 3 else 0) == 4, "never a Blank face when the other 2 is plain (even if score_fn prefers it)")
	check(NerveState.target_slot(kb, 1, NerveState.UP) == 4, "no score_fn: first non-Blank slot")
	var kd := _keg()
	kd.mods[2] = blood
	var d := _nerve([kd] as Array[TableDie], [2] as Array[int])
	check(d.nudge(0, NerveState.UP) == 4, "never the opt-in Blood face when the other 2 isn't")
	var ka := _keg()
	ka.mods[2] = _blank
	ka.mods[3] = blood
	var all_bad := _nerve([ka] as Array[TableDie], [1] as Array[int])
	check(all_bad.nudge(0, NerveState.UP) == 3, "every candidate Blank/Blood: first slot")
	var all_bad2 := _nerve([ka] as Array[TableDie], [1] as Array[int])
	check(all_bad2.nudge(0, NerveState.UP, func(sl: Array) -> int: return 5 if int(sl[0]) == 4 else 1) == 4, "every candidate Blank/Blood: score_fn still picks")
	# Down works the same way.
	var dn := _nerve([_keg()] as Array[TableDie], [6] as Array[int])
	check(dn.nudge(0, NerveState.DOWN, func(sl: Array) -> int: return 3 if int(sl[0]) == 4 else 1) == 4, "Keg 3 down: score_fn picks among the 2s")
	# rescue_options reports the slot nudge() would pick.
	var dice: Array[TableDie] = [_keg(), TableDie.new()]
	var r := _nerve(dice, [1, 2] as Array[int])
	var lit := func(sl: Array) -> bool: return int(sl[0]) > 0 and dice[0].value_at(int(sl[0])) == dice[1].value_at(int(sl[1]))
	var opts := r.rescue_options(lit, func(sl: Array) -> int: return 2 if int(sl[0]) == 4 else 1)
	check(opts.size() >= 1 and int(opts[0]["die"]) == 0 and int(opts[0]["slot"]) == 4, "rescue_options uses score_fn's slot")
	check(r.any_nudge_lights(lit, Callable()), "any_nudge_lights without score_fn")


## Confirmed (Game Designer): potting closes Nerve for that throw; unused
## Nerve carries over within the table and resets at the next table.
func _test_throw_lifecycle() -> void:
	var n := _nerve(_bones(4), [2, 3, 4, 5] as Array[int])
	n.mark_potted(0)
	check(not n.can_nudge(1) and not n.can_nudge(0) and n.nudge(1, NerveState.UP) == -1 and n.uses_left() == 1, "pot closes Nerve for this throw (Nerve kept)")
	check(not n.any_nudge_lights(func(_s: Array) -> bool: return true), "pot: no rescue on this throw")
	n.begin_throw([0, 3, 4, 5] as Array[int])
	check(n.can_nudge(1) and n.uses_left() == 1, "unused Nerve carries to the next throw")
	n.commit()
	n.begin_throw([0, 0, 4, 5] as Array[int])
	check(n.can_nudge(2) and n.uses_left() == 1, "still carried after a rethrow with no nudge")
	n.nudge(2, NerveState.UP)
	n.mark_potted(2)
	n.begin_throw([0, 0, 0, 3] as Array[int])
	check(not n.can_nudge(3) and n.uses_left() == 0, "used: spent for the rest of the table")
	n.reset_table()
	n.begin_throw([1, 2, 3, 4] as Array[int])
	check(n.uses_left() == 1 and n.can_nudge(0), "next table: reset to 1")
	var keep := _nerve(_bones(2), [2, 3] as Array[int])
	keep.commit()
	keep.reset_table()
	check(keep.uses_left() == 1, "unused Nerve doesn't stack across tables (still 1)")


## A MapRun on floor 1 entered at its first Table node; its TableSetup.
func _table_setup_from_run(rd: RunData) -> TableSetup:
	var run := MapRun.new(rd, 7)
	run._start_floor(0)
	for n: MapNode in run.map.nodes.values():
		if n.type == MapGenData.NodeType.TABLE:
			run.map.current_id = n.prev[0] if not n.prev.is_empty() else -1
			run.screen = MapRun.Screen.MAP
			run.choose_node(n.id)
			break
	var base := load("res://resources/tuning/bonfire_tuning.tres") as BonfireTuning
	return run.table_setup().to_table_setup(base)


## QA: RunData.nerve_uses reaches the TableSetup the table gets, end to end
## (a hardcoded value in MapRun.table_setup() fails this).
func _test_map_run_e2e() -> void:
	var rd := load("res://resources/map/bonfire_run.tres") as RunData
	check(_table_setup_from_run(rd).nerve_uses == 1, "e2e: map_run -> TableSetup.nerve_uses = 1 by default")
	var rd2 := rd.duplicate() as RunData
	rd2.nerve_uses = 2
	check(_table_setup_from_run(rd2).nerve_uses == 2, "e2e: RunData.nerve_uses = 2 -> TableSetup.nerve_uses = 2")
	var rd0 := rd.duplicate() as RunData
	rd0.nerve_uses = 0
	check(_table_setup_from_run(rd0).nerve_uses == 0, "e2e: RunData.nerve_uses = 0 -> 0")


## QA: Nerve never costs Soul or Embers (Bloodletter included).
func _test_no_soul_or_embers() -> void:
	var src := FileAccess.get_file_as_string("res://scripts/core/nerve_state.gd")
	check(src.length() > 1000, "nerve_state.gd read")
	var code := ""
	for line in src.split("\n"):
		var t := line.strip_edges()
		if not t.begins_with("#"):
			code += line.get_slice("#", 0) + "\n"
	var low := code.to_lower()
	check(not low.contains("soul") and not low.contains("ember"), "nerve_state.gd code never mentions soul / ember")
	# Run-level: a table's BonfireRun with a settled throw; Nerve cycles around it.
	var t := load("res://resources/tuning/bonfire_tuning.tres") as BonfireTuning
	var g := TableGoal.new()
	g.hands = 3
	var run := BonfireRun.new(t, g)
	var bl := TableRules.make({"id": &"bloodletter", "params": {}})
	check(bl != null, "Bloodletter rule builds")
	run.set_rules([bl] as Array[TableRule], 1)
	run.set_throw([1, 2, 4, 5, 6] as Array[int])
	var before := [run.soul, run.embers, run.points, run.hands_left]
	var dice := _bones(5)
	var n := NerveState.new()
	n.setup(dice)
	n.begin_throw([1, 2, 4, 5, 6] as Array[int])
	n.nudge(1, NerveState.UP)
	n.undo(1)
	n.nudge(2, NerveState.DOWN)
	n.commit()
	check(n.uses_left() == 0 and n.slots[2] == 3, "cycle: nudge, undo, nudge, commit")
	check([run.soul, run.embers, run.points, run.hands_left] == before, "run Soul / Embers / points / hands unchanged by Nerve (Bloodletter on)")
	var rd := load("res://resources/map/bonfire_run.tres") as RunData
	var prog := MapRun.new(rd, 3).progress
	var pb := [prog.soul, prog.embers]
	var n2 := NerveState.new()
	n2.setup(_bones(2))
	n2.begin_throw([3, 3] as Array[int])
	n2.nudge(0, NerveState.UP)
	n2.undo(0)
	n2.nudge(0, NerveState.DOWN)
	n2.commit()
	n2.reset_table()
	check([prog.soul, prog.embers] == pb, "RunProgress Soul / Embers unchanged by Nerve")
