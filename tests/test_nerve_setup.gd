## Headless test: Nerve setup plumbing (RunData -> MapRun -> RunTableSetup ->
## TableSetup), the Knucklebone seal_steps hand-off, and that Nerve never
## costs Soul or Embers. Split from test_nerve.gd (logic rules).
##
## Run:
##   godot --headless --path . --script res://tests/test_nerve_setup.gd
extends SceneTree

var _passed: int = 0
var _failed: int = 0


func check(ok: bool, msg: String) -> void:
	if ok:
		_passed += 1
	else:
		_failed += 1
		print("FAIL: ", msg)


func _initialize() -> void:
	_test_setup_plumbing()
	_test_map_run_e2e()
	_test_no_soul_or_embers()
	_test_seal_steps()
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _bones(count: int) -> Array[TableDie]:
	var out: Array[TableDie] = []
	for i in count:
		out.append(TableDie.new())
	return out


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


## RunData seal_base_step / seal_mult_step -> TableSetup.seal_steps (#116's
## {combo id: Vector2i(base, mult)} shape, NonStdDice.seal_steps).
func _test_seal_steps() -> void:
	var rd := load("res://resources/map/bonfire_run.tres") as RunData
	var ts := _table_setup_from_run(rd)
	check(not ts.seal_steps.is_empty() and ts.seal_steps == NonStdDice.seal_steps(rd), "seal_steps from the run's RunData")
	check(ts.seal_steps.get(&"quads") == Vector2i(int(rd.seal_base_step[&"quads"]), int(rd.seal_mult_step[&"quads"])), "quads step = (base, mult)")
	var rd2 := rd.duplicate() as RunData
	var b := rd2.seal_base_step.duplicate()
	var m := rd2.seal_mult_step.duplicate()
	b[&"pair"] = 11
	m[&"pair"] = 4
	rd2.seal_base_step = b
	rd2.seal_mult_step = m
	check(_table_setup_from_run(rd2).seal_steps.get(&"pair") == Vector2i(11, 4), "custom RunData steps reach the table")
	var rts := RunTableSetup.new()
	rts.goal = TableGoal.new()
	rts.seal_steps = {&"pair": Vector2i(1, 2)}
	var out := rts.to_table_setup(load("res://resources/tuning/bonfire_tuning.tres") as BonfireTuning)
	rts.seal_steps[&"pair"] = Vector2i(9, 9)
	check(out.seal_steps == {&"pair": Vector2i(1, 2)}, "to_table_setup copies seal_steps")
	check(RunTableSetup.new().seal_steps.is_empty(), "default empty (table falls back to RunData)")
