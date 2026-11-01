## Headless tests for the one-floor build (one_floor_v1): F1 map rules
## (pre-boss Shop / Rest mix, shops by row 4), F1 targets, the run ending at
## the F1 boss on RUN COMPLETE, and the final score.
##
## Run:
##   godot --headless --path . --script res://tests/test_one_floor.gd
extends SceneTree

const NT := MapGenData.NodeType
const S := MapRun.Screen

var _passed: int = 0
var _failed: int = 0


func _initialize() -> void:
	print("=== Dice of the Damned: one-floor tests ===")
	var data := load("res://resources/map/bonfire_run.tres") as RunData
	_test_map(data.floors[0].map)
	_test_f2_map_unchanged(data.floors[1].map)
	_test_targets(data.floors[0])
	_test_run_complete(data)
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _test_map(m: MapGenData) -> void:
	_check(m.rows == 7 and m.pre_boss_mix and m.shop_guarantee_to == 4, "F1 map: 7 rows, pre-boss mix, shops by row 4")
	_check(m.type_weights == PackedFloat32Array([41, 12, 22, 16, 9, 0]), "F1 map: weights 41/12/22/16/9")
	var mixed := true
	var shops := true
	var valid := true
	for s in 200:
		var rm := MapGenerator.generate(m, s)
		var types: Array = rm.row_nodes(m.rows - 1).map(func(n: MapNode) -> int: return n.type)
		mixed = mixed and types.has(NT.SHOP) and types.has(NT.REST)
		valid = valid and MapGenerator.violations(m, rm).is_empty()
		shops = shops and MapGenerator.shopless_path(m, rm).is_empty()
	_check(mixed, "F1 map: every pre-boss row has a Shop and a Rest (200 seeds)")
	_check(shops, "F1 map: every path meets a Shop on rows 2-4 (200 seeds)")
	_check(valid, "F1 map: no rule violations (200 seeds)")


func _test_f2_map_unchanged(m: MapGenData) -> void:
	_check(not m.pre_boss_mix and m.rest_before_boss, "F2 map: pre-boss row stays all Rest")
	var rm := MapGenerator.generate(m, 7)
	var all_rest := true
	for n in rm.row_nodes(m.rows - 1):
		all_rest = all_rest and n.type == NT.REST
	_check(all_rest, "F2 map: generated pre-boss row is all Rest")


func _test_targets(f: FloorData) -> void:
	_check(f.target_table == 350 and f.target_elite == 500 and f.target_boss == 2200, "F1 targets are 350/500/2200")


func _test_run_complete(data: RunData) -> void:
	_check(data.floors_in_run == 1 and data.floors.size() == 3, "run: 1 floor played, F2/F3 data kept")
	var run := MapRun.new(data, 4242)
	var boss_embers_before := -1
	for step in 300:
		match run.screen:
			S.MAP:
				run.choose_node(run.map.reachable()[0])
			S.TABLE:
				if run.table_type == NT.BOSS:
					boss_embers_before = run.progress.embers
				var o := TableOutcome.new()
				o.cleared = true
				o.soul_after = run.progress.soul
				o.embers = run.goal.clear_embers
				o.points = run.goal.target
				o.banked_combos = [&"pair", &"full_house", &"trips"]
				run.apply_outcome(o)
			S.REWARD:
				if not run.take_seal(0):
					run.take_seal(-1)
			S.EVENT:
				run.choose_event(run.event.choices.size() - 1)
				if run.screen == S.EVENT:
					run.choose_event(0)
			S.SHOP:
				run.leave()
			S.REST:
				run.rest_heal()
			_:
				break
	_check(run.screen == S.RUN_WON and run.end_reason == &"complete", "run: F1 boss win -> RUN COMPLETE")
	_check(run.floor_index == 0, "run: no F2 load")
	_check(RunSummary.title(run) == "RUN COMPLETE", "run: title RUN COMPLETE")
	_check(run.progress.embers >= boss_embers_before + data.boss_embers, "run: boss Embers paid before the score")
	_check(RunSummary.final_score(run) == run.run_points + 10 * run.progress.embers and run.progress.embers > 0, "score: points + 10 x Embers left")
	_check(run.best_combo == &"full_house", "score: best hand is the highest combo banked")
	var lines := RunSummary.lines(run)
	_check(lines[0] == "Points banked: %d" % run.run_points and lines[2] == "Final score: %d" % RunSummary.final_score(run), "screen: run_complete rows")
	_check(lines[1] == "Embers left: %d x10 = +%d" % [run.progress.embers, 10 * run.progress.embers], "screen: Embers x10 row")
	_check(RunSummary.reason_line(run) == "You beat %s, and the run is yours." % run.boss_name(), "screen: run_complete_reason by id")
	_check(MapKey.LINES[MapGenData.NodeType.BOSS] == "Boss: beat the cheat to win the run.", "map key: map_key_boss row")
	var md := FileAccess.get_file_as_string("res://design/strings_v1.md")
	var ok := true
	for id in RunSummary.TEXT:
		ok = ok and md.contains("| %s | (new) | %s |" % [id, RunSummary.TEXT[id]])
	_check(ok, "strings: RunSummary.TEXT matches design/strings_v1.md verbatim")


func _check(ok: bool, label: String) -> void:
	if ok:
		_passed += 1
		print("  PASS  " + label)
	else:
		_failed += 1
		print("  FAIL  " + label)
