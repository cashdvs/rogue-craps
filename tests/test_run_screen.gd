## Headless scene test for the run screens: the map shows and forwards
## clicks, events render with greyed choices and resolve through their
## buttons (incl. the face picker), shop/rest/reward panels work, the 3D
## table opens with the run's goal and Soul, and a floor can be played
## end to end through the UI with stub tables.
##
## Run:
##   godot --headless --path . --script res://tests/test_run_screen.gd
extends SceneTree

const S := MapRun.Screen
const NT := MapGenData.NodeType

var _passed: int = 0
var _failed: int = 0


func _initialize() -> void:
	print("=== Dice of the Damned: run screen tests ===")
	var guard := ProfileGuard.begin("run_screen")
	var scene: RunScreen = (load("res://scenes/run.tscn") as PackedScene).instantiate()
	scene.run_seed = 21
	root.add_child(scene)
	await process_frame
	await _test_map(scene)
	await _test_event(scene)
	await _test_panels(scene)
	await _test_table(scene)
	await _test_floor(scene)
	scene.queue_free()
	await process_frame
	_check(guard.end(), "profile: the real user://profile.cfg is untouched")
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _check(condition: bool, name: String) -> void:
	if condition:
		_passed += 1
	else:
		_failed += 1
		print("FAIL: ", name)


func _buttons(node: Node, out: Array[Button] = []) -> Array[Button]:
	for c in node.get_children():
		if c is Button:
			out.append(c)
		_buttons(c, out)
	return out


func _press(node: Node, prefix: String) -> bool:
	for b in _buttons(node):
		if b.text.begins_with(prefix) and not b.disabled and b.is_visible_in_tree():
			b.pressed.emit()
			return true
	return false


func _enter(scene: RunScreen, type: int) -> void:
	for n: MapNode in scene.run.map.nodes.values():
		if n.type == type:
			scene.run.map.current_id = n.prev[0] if not n.prev.is_empty() else -1
			scene.run.screen = S.MAP
			scene.run.choose_node(n.id)
			return


func _test_map(scene: RunScreen) -> void:
	_check(scene.map_view.visible and scene.map_view.map == scene.run.map, "map: shown at the start")
	var first: int = scene.run.map.reachable()[0]
	var p := scene.map_view.node_pos(scene.run.map.node(first))
	_check(scene.map_view.node_at(p) == first, "map: node hit-test finds the node under the cursor")
	_check(scene.map_view.node_pos(scene.run.map.node(scene.run.map.boss_id)).y < p.y, "map: boss drawn at the top")
	scene.map_view.node_pressed.emit(first)
	await process_frame
	_check(scene.run.map.current_id == first and scene.run.screen == S.TABLE and scene._panel_root.visible, "map: click -> table screen")
	var stub_shown := false
	var note_shown := false
	for b in _buttons(scene):
		stub_shown = stub_shown or (b.text.begins_with("Stub") and b.is_visible_in_tree())
	for l in scene._panel_box.get_children():
		note_shown = note_shown or (l is Label and (l as Label).text.contains("Godot Dev"))
	_check(not stub_shown and not note_shown, "table: no Stub buttons and no dev note by default")
	scene.debug_table_stubs = true
	scene.refresh()
	await process_frame
	_press(scene, "Stub: clear")
	await process_frame
	_check(scene.run.screen == S.REWARD, "table: stub clear -> Seal reward")
	_press(scene, "Skip")
	await process_frame
	_check(scene.run.screen == S.MAP and scene.map_view.visible, "reward: skip -> back to the map")


func _test_event(scene: RunScreen) -> void:
	scene.run.progress.embers = 10
	scene.run._events_seen.clear()
	var devil: EventData = load("res://resources/events/devils_deal.tres")
	_enter(scene, NT.EVENT)
	scene.run.event = devil
	scene.refresh()
	await process_frame
	_check(scene.event_view.visible, "event: event screen shown")
	var greyed: bool = false
	for b in _buttons(scene.event_view):
		if b.text.begins_with("Pay in coin"):
			greyed = b.disabled and b.tooltip_text == "Not enough Embers."
	_check(greyed, "event: unaffordable choice greyed with a reason")
	_press(scene.event_view, "Sign in blood")
	await process_frame
	_check(_buttons(scene.event_view).size() > 30, "event: face picker opens for a picked target")
	_press(scene.event_view, "1")
	await process_frame
	await process_frame
	_check(scene.run.progress.soul == 27 and scene.run.progress.dice[0].faces[0] == &"hellfire", "event: picked face gets the Hellfire, -8 Soul")
	_press(scene.event_view, "Back to the map")
	await process_frame
	_check(scene.map_view.visible and scene.run.screen == S.MAP, "event: result -> back to the map")


func _test_panels(scene: RunScreen) -> void:
	_enter(scene, NT.SHOP)
	await process_frame
	scene.run.progress.embers = 50
	scene.shop_list = true  # The old text list (Sell / Swap) until shop PR C.
	scene._show_shop()
	_check(_press(scene, "Reroll - 3") and scene.run.progress.embers == 47, "shop: reroll button")
	await process_frame
	scene.run.progress.add_die(&"mirror")
	scene.shop_list = true  # The old text list (Sell / Swap) until shop PR C.
	scene._show_shop()
	_check(_press(scene, "Sell your Mirror") and scene.run.progress.dice.size() == 5 and scene.run.progress.embers == 56, "shop: sell button (half of 18)")
	await process_frame
	scene.run.progress.add_seal_levels(&"pair", 1)
	scene.run.shop_seals[0] = &"ashen"
	scene.shop_list = true  # The old text list (Sell / Swap) until shop PR C.
	scene._show_shop()
	_check(_press(scene, "Ashen Seal") and _press(scene, "Pair") and _press(scene, "Trips")
		and scene.run.progress.seal_level(&"trips") == 1 and scene.run.progress.seal_level(&"pair") == 0, "shop: Ashen Seal asks from / to")
	await process_frame
	scene.run.rules = [load("res://resources/map/rules/short_table.tres")] as Array[RunRuleData]
	scene._show_table()
	var shown := false
	for l in scene._panel_box.get_children():
		shown = shown or (l is Label and (l as Label).text.begins_with("Twist: Short Table"))
	_check(shown, "table: the node's twist is listed at table entry")
	scene.run.rules.clear()
	scene.shop_list = true  # The old text list (Sell / Swap) until shop PR C.
	scene._show_shop()
	var hell: FaceModData = load("res://resources/mods/hellfire.tres")
	scene.run.shop_mods[0] = hell
	for d in scene.run.progress.dice.size():
		scene.run.progress.set_face(d, 5, &"twin")
	scene.run.progress.embers = hell.price
	scene.shop_list = true  # The old text list (Sell / Swap) until shop PR C.
	scene._show_shop()
	var greyed := false
	for b in _buttons(scene):
		if b.text.begins_with("Hellfire Face - %d" % scene.run.cheapest_mod_price(0)):
			greyed = b.disabled
	_check(greyed and scene.run.cheapest_mod_price(0) > hell.price, "shop: mod button greys out on the escalated price, and shows it")
	for d in scene.run.progress.dice.size():
		scene.run.progress.set_face(d, 5, &"")
	scene.shop_list = true  # The old text list (Sell / Swap) until shop PR C.
	scene._show_shop()
	_check(_press(scene, "Leave") and scene.run.screen == S.MAP, "shop: leave")
	await process_frame
	_check(scene.quit_button.visible, "map: Quit to title shown on the map")
	_check(_press(scene, "Quit to title") and scene._panel_root.visible and not scene.map_view.visible, "map: Quit to title asks to confirm first")
	_check(_press(scene, "Keep playing") and scene.map_view.visible and scene.run.screen == S.MAP, "map: Keep playing goes back to the map")
	_enter(scene, NT.REST)
	await process_frame
	var soul: int = scene.run.progress.soul
	_check(_press(scene, "Heal 12") and scene.run.progress.soul == mini(soul + 12, 35), "rest: heal button")


func _test_table(scene: RunScreen) -> void:
	_enter(scene, NT.TABLE)
	await process_frame
	scene.run.progress.add_seal_levels(&"pair", 1)
	_press(scene, "Play at the table")
	await process_frame
	var br: BonfireRun = scene._table.get("run")
	_check(br != null and br.goal == scene.run.goal and br.soul == scene.run.progress.soul, "table: 3D Bonfire opens with this node's goal and the run's Soul")
	var pair_mult: int = 0
	for c in br.tuning.combos:
		if c.id == &"pair":
			pair_mult = c.mult
	_check(pair_mult == 3, "table: Seal levels reach the table's combos (Pair Lv2 mult 3)")
	var t: Bonfire3D = scene._table
	_check(t.is_run_mode() and t.all_dice.size() == scene.run.progress.dice.size() and t.soul_meter.soul_max == scene.run.progress.max_soul,
		"table: run mode with the run's dice and max Soul")
	_check(t.pause_menu.forfeit_button.visible and not t.pause_menu.quit_button.visible, "table: run-mode pause menu offers Forfeit, not Quit to title")
	var unticked := br.unticked_required()
	var soul0: int = scene.run.progress.soul
	var embers0: int = scene.run.progress.embers
	_check(t.forfeit(), "table: forfeit")
	t.bhud.continue_pressed.emit()
	await process_frame
	_check(scene._table == null and not is_instance_valid(t) or t.is_queued_for_deletion(), "table: freed after finished")
	_check(scene.run.screen == S.MAP and scene.map_view.visible and scene.run.progress.soul == soul0 - unticked * scene.run.goal.timeout_soul_per_bounty
		and scene.run.progress.embers >= embers0, "table: forfeit outcome applied (timeout Soul), back to the map")
	await process_frame


func _test_floor(scene: RunScreen) -> void:
	scene.new_run(5)
	var floor_start: int = scene.run.floor_index
	for step in 60:
		await process_frame
		match scene.run.screen:
			S.MAP:
				scene.map_view.node_pressed.emit(scene.run.map.reachable()[0])
			S.TABLE:
				_press(scene, "Stub: clear")
			S.REWARD:
				_press(scene, "Skip")
			S.REST:
				_press(scene, "Heal")
			S.SHOP:
				_press(scene, "Leave")
			S.EVENT:
				if not _press(scene.event_view, "Back to the map"):
					var bs := _buttons(scene.event_view)
					_press(scene.event_view, bs[bs.size() - 1].text)
		if scene.run.floor_index > floor_start:
			break
	_check(scene.run.floor_index == floor_start + 1 and scene.run.screen == S.MAP, "floor: played through the UI to the boss and on to floor 2")
