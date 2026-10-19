## Playtest map hints (Game Designer, #106; first_time_clarity_v1 §1): the
## map key opens by itself once per profile (user:// RunProfile), map node
## tooltips on hover and long-press (boss: cheat and re-sit lines), and the
## table preview's mini dice row that opens "Your dice".
##   godot --headless --path . --script res://tests/test_run_map_hints.gd
extends SceneTree

const S := MapRun.Screen
const NT := MapGenData.NodeType

var _passed: int = 0
var _failed: int = 0


func _initialize() -> void:
	RunProfile.path = "user://test_profile_map_hints.cfg"
	_wipe()
	_test_profile_file()
	var scene: RunScreen = (load("res://scenes/run.tscn") as PackedScene).instantiate()
	scene.run_seed = 4242
	root.add_child(scene)
	await process_frame
	_check(scene.map_key.visible, "key: opens by itself on a new profile's first map")
	scene.new_run(4243)
	_check(not scene.map_key.visible, "key: the next run's map keeps it closed")
	var again: RunScreen = (load("res://scenes/run.tscn") as PackedScene).instantiate()
	root.add_child(again)
	await process_frame
	_check(not again.map_key.visible and RunProfile.map_key_seen(), "key: a fresh launch on the same profile keeps it closed")
	again.key_button.pressed.emit()
	_check(again.map_key.visible, "key: the Key button still opens it")
	again.queue_free()
	_test_tooltips(scene)
	_test_long_press(scene)
	_test_mini_dice(scene)
	scene.queue_free()
	await process_frame
	_wipe()
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _check(c: bool, name: String) -> void:
	if c:
		_passed += 1
	else:
		_failed += 1
		print("FAIL: ", name)


func _wipe() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(RunProfile.path))


func _test_profile_file() -> void:
	_check(not RunProfile.map_key_seen(), "profile: a new profile hasn't seen the key")
	var cf := ConfigFile.new()
	cf.set_value("other", "keep", 7)
	cf.save(RunProfile.path)
	_check(RunProfile.mark_map_key_seen() == OK and RunProfile.map_key_seen(), "profile: marking it saves to user://")
	cf = ConfigFile.new()
	cf.load(RunProfile.path)
	_check(int(cf.get_value("other", "keep", 0)) == 7, "profile: marking keeps other keys in the file")
	_wipe()


func _first(scene: RunScreen, type: int) -> MapNode:
	for n: MapNode in scene.run.map.nodes.values():
		if n.type == type:
			return n
	return null


func _test_tooltips(scene: RunScreen) -> void:
	scene.refresh()
	var mv := scene.map_view
	mv.size = Vector2(1920, 1080)
	var table := _first(scene, NT.TABLE)
	var tip := mv.tooltip_for(table.id)
	_check(tip == MapKey.LINES[NT.TABLE], "tooltip: a Table shows its map key line")
	_check(mv._get_tooltip(mv.node_pos(table)) == tip, "tooltip: hovering the node gives that text")
	_check(mv._get_tooltip(Vector2(2, 2)) == "", "tooltip: empty space has none")
	var shop := _first(scene, NT.SHOP)
	_check(shop == null or mv.tooltip_for(shop.id) == MapKey.LINES[NT.SHOP], "tooltip: a Shop shows its line")
	var boss := mv.tooltip_for(scene.run.map.boss_id).split("\n")
	_check(boss.size() == 3 and boss[0] == scene.run.boss_name() and boss[1].contains(scene.run.boss.description)
		and boss[2] == MapKey.FOOTER[1], "tooltip: the boss shows its name, cheat line and the re-sit line (%s)" % [boss])
	scene.run.progress.next_table_twist = load("res://resources/map/rules/cold_hands.tres")
	scene.refresh()
	var reach: MapNode = null
	for id in scene.run.map.reachable():
		if scene.run.map.node(id).type == NT.TABLE:
			reach = scene.run.map.node(id)
	_check(reach == null or mv.tooltip_for(reach.id).ends_with(scene.run.pending_twist_note()), "tooltip: a reachable Table adds the pending twist")
	scene.run.progress.next_table_twist = null
	scene.refresh()


func _touch(mv: MapView, at: Vector2, down: bool) -> void:
	var t := InputEventScreenTouch.new()
	t.position = at
	t.pressed = down
	mv._gui_input(t)


func _test_long_press(scene: RunScreen) -> void:
	var mv := scene.map_view
	var id: int = scene.run.map.reachable()[0]
	var at := mv.node_pos(scene.run.map.node(id))
	var travelled: Array[int] = []
	var hook := func(n: int) -> void: travelled.append(n)
	mv.node_pressed.connect(hook)
	_touch(mv, at, true)
	mv._process(MapView.LONG_PRESS_SEC + 0.05)
	_check(mv.bubble.visible and mv.bubble.text == mv.tooltip_for(id), "long-press: holding a node shows its tooltip bubble")
	_touch(mv, at, false)
	_check(not mv.bubble.visible and travelled.is_empty(), "long-press: lifting hides it and doesn't travel")
	_touch(mv, at, true)
	mv._process(0.1)
	_touch(mv, at, false)
	_check(travelled == ([id] as Array[int]), "long-press: a quick tap still travels")
	mv.node_pressed.disconnect(hook)


func _test_mini_dice(scene: RunScreen) -> void:
	scene.new_run(4242)
	var n := _first(scene, NT.TABLE)
	scene.run.map.current_id = n.prev[0] if not n.prev.is_empty() else -1
	scene.run.choose_node(n.id)
	scene.run.progress.set_face(0, 0, &"wild")
	scene.refresh()
	var row: MiniDiceRow = null
	for c in scene._panel_box.get_children():
		if c is MiniDiceRow:
			row = c
	var tiles: Array = []
	if row != null:
		tiles = row.get_child(1).get_children()
	_check(row != null and tiles.size() == scene.run.progress.dice.size(), "mini dice: the table preview shows a tile per die in the bag")
	_check(tiles.size() > 0 and tiles[0].text == "Bone d6 +1" and tiles[1].text == "Bone d6" and tiles[0].tooltip_text == "Bone",
		"mini dice: tiles show name, faces and mods (%s)" % (tiles[0].text if tiles.size() > 0 else "-"))
	if tiles.size() > 0:
		tiles[0].pressed.emit()
	var dice_open := false
	for c in scene._panel_box.get_children():
		dice_open = dice_open or c is DicePanel
	_check(dice_open and scene.run.screen == S.TABLE, "mini dice: a tile opens 'Your dice'")
	scene.refresh()
	var back := false
	for c in scene._panel_box.get_children():
		back = back or c is MiniDiceRow
	_check(back, "mini dice: Close goes back to the table preview")
