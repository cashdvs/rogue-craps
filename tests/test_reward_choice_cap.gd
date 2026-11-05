## Cash 0.1.6/0.1.7: after a cleared table, show at most reward_choice_cap
## reward picks (default 3). Skip / "Keep my dice" do not count. Shop stock
## stays on its own exports. Mutation: drop the mini(..., cap) clamp in
## MapRun._roll_rewards (or bump the UI loop past the cap) and these checks
## fail when seal_pick_options / elite_seal_pick_options are raised above 3.
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


## Jump into the first node of `type` on the current floor.
func _enter(run: MapRun, type: int) -> bool:
	for n: MapNode in run.map.nodes.values():
		if n.type == type:
			run.map.current_id = n.prev[0] if not n.prev.is_empty() else -1
			run.screen = S.MAP
			return run.choose_node(n.id)
	return false


## RunData copy with pick counts above the cap so the clamp is forced.
func _inflated() -> RunData:
	var data := (load("res://resources/map/bonfire_run.tres") as RunData).duplicate() as RunData
	data.seal_pick_options = 8
	data.elite_seal_pick_options = 8
	data.elite_dice_options = 5
	data.reward_choice_cap = 3
	## Play all floors so a mid-run boss still offers a Seal reward (one_floor_v1
	## skips the pick on the last floor).
	data.floors_in_run = 0
	return data


func _test_logic() -> void:
	var data := _inflated()
	var cap: int = data.reward_choice_cap
	_check(cap == 3, "default reward_choice_cap is 3")
	var table := MapRun.new(data, 11)
	_check(_enter(table, NT.TABLE), "enter a table")
	table.quick_resolve(true)
	_check(table.screen == S.REWARD and table.seal_options.size() <= cap \
		and table.seal_options.size() > 0 and table.dice_options.is_empty(),
		"table: Seal picks capped at %d (got %d) even when seal_pick_options=8" \
		% [cap, table.seal_options.size()])
	var elite := MapRun.new(data, 12)
	_check(_enter(elite, NT.ELITE), "enter an Elite")
	elite.quick_resolve(true)
	_check(elite.seal_options.size() <= cap and elite.dice_options.size() <= cap,
		"elite: Seal (%d) and die (%d) picks each <= %d when asked for 8/5" \
		% [elite.seal_options.size(), elite.dice_options.size(), cap])
	var boss := MapRun.new(data, 13)
	_check(_enter(boss, NT.BOSS), "enter a Boss")
	boss.quick_resolve(true)
	var rare := false
	for id in boss.seal_options:
		rare = rare or boss.is_rare_seal(id)
	_check(boss.seal_options.size() <= cap and rare,
		"boss: Seal picks capped at %d and still include a rare (size=%d rare=%s)" \
		% [cap, boss.seal_options.size(), rare])


## Count reward-choice buttons on the Seal Reward panel (Skip / Keep excluded).
func _choice_buttons(scene: RunScreen) -> Array[Button]:
	var out: Array[Button] = []
	for c in scene._panel_box.get_children():
		if c is Button:
			var t: String = (c as Button).text
			if t.begins_with("Skip") or t == ShopSideCard.SWAP_TEXT.reward_keep_dice:
				continue
			out.append(c as Button)
	return out


func _test_ui() -> void:
	var data := _inflated()
	var scene := (load("res://scenes/run.tscn") as PackedScene).instantiate() as RunScreen
	scene.run_data = data
	scene.debug_table_stubs = true
	root.add_child(scene)
	await process_frame
	await process_frame
	# Force a cleared Elite so both die and Seal panels are exercised.
	var run: MapRun = scene.run
	_check(_enter(run, NT.ELITE), "ui: enter Elite")
	run.quick_resolve(true)
	scene.refresh()
	await process_frame
	var die_btns := _choice_buttons(scene)
	_check(die_btns.size() <= data.reward_choice_cap and not run.dice_options.is_empty(),
		"ui elite dice step: %d choice buttons (<= %d)" % [die_btns.size(), data.reward_choice_cap])
	# Skip the die row and open Seals.
	run.dice_options.clear()
	scene.refresh()
	await process_frame
	var seal_btns := _choice_buttons(scene)
	_check(seal_btns.size() <= data.reward_choice_cap and seal_btns.size() > 0,
		"ui Seal step: %d choice buttons (<= %d)" % [seal_btns.size(), data.reward_choice_cap])
	scene.queue_free()
	await process_frame
