## fixed_table_payout_v1: the after-table Seal / die reward is gone, so the
## old reward_choice_cap no longer applies to a cleared table. This file
## now checks that no reward choices appear (cap field is unused after a
## clear; shop stock stays on its own exports).
##
## Run:
##   godot --headless --path . --script res://tests/test_reward_choice_cap.gd
extends SceneTree

const NT := MapGenData.NodeType
const S := MapRun.Screen

var _passed: int = 0
var _failed: int = 0


func _initialize() -> void:
	print("=== Dice of the Damned: reward choice cap ===")
	_test_logic()
	await _test_ui()
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _check(cond: bool, name: String) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		print("FAIL: ", name)


func _enter(run: MapRun, type: int) -> bool:
	for n: MapNode in run.map.nodes.values():
		if n.type == type:
			run.map.current_id = n.prev[0] if not n.prev.is_empty() else -1
			run.screen = S.MAP
			return run.choose_node(n.id)
	return false


func _test_logic() -> void:
	var data := (load("res://resources/map/bonfire_run.tres") as RunData).duplicate() as RunData
	data.seal_pick_options = 8
	data.elite_seal_pick_options = 8
	data.elite_dice_options = 5
	data.floors_in_run = 0
	_check(data.reward_choice_cap == 3, "reward_choice_cap field is still 3 (unused after a clear)")
	for t in [NT.TABLE, NT.ELITE, NT.BOSS]:
		var run := MapRun.new(data, 11 + int(t))
		_check(_enter(run, t), "enter type %d" % t)
		run.quick_resolve(true)
		_check(run.screen == S.REWARD and run.seal_options.is_empty() and run.dice_options.is_empty(),
			"type %d: no Seal or die reward choices after a clear" % t)
		run.confirm_payout()


func _test_ui() -> void:
	var data := (load("res://resources/map/bonfire_run.tres") as RunData).duplicate() as RunData
	var scene := (load("res://scenes/run.tscn") as PackedScene).instantiate() as RunScreen
	scene.run_data = data
	scene.debug_table_stubs = true
	root.add_child(scene)
	await process_frame
	await process_frame
	var run: MapRun = scene.run
	_check(_enter(run, NT.ELITE), "ui: enter Elite")
	run.quick_resolve(true)
	scene.refresh()
	await process_frame
	var labels: Array[String] = []
	var buttons: Array[String] = []
	for c in scene._panel_box.get_children():
		if c is Label:
			labels.append((c as Label).text)
		elif c is Button:
			buttons.append((c as Button).text)
	_check(labels.has("Elite beaten: +42 Embers."), "ui: payout line is shown")
	_check(buttons == [EconomyStrings.TABLE_PAYOUT_CONTINUE], "ui: only Continue, no Seal or die picks")
	scene.queue_free()
	await process_frame
