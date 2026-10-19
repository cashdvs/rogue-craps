## QA full-run pass 1 fixes, screens (qa/full_run_pass_1.md; seeds 4242 /
## 31337): end screens with reason, summary and Quit to title; the seed on
## the bar; the map key; "Your dice" with Seals from Lv1; per-die mod prices
## in the picker; the shop label; the table preview; EMBERS = run balance.
##   godot --headless --path . --script res://tests/test_run_playtest_1_ui.gd
extends SceneTree

const S := MapRun.Screen
const NT := MapGenData.NodeType

var _passed: int = 0
var _failed: int = 0


func _initialize() -> void:
	var scene: RunScreen = (load("res://scenes/run.tscn") as PackedScene).instantiate()
	scene.run_seed = 4242
	root.add_child(scene)
	await process_frame
	_test_bar_and_key(scene)
	_test_dice_view(scene)
	_test_shop_prices(scene)
	_test_table_preview(scene)
	_test_end_screen(scene)
	scene.queue_free()
	await process_frame
	await _test_embers_hud()
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _check(c: bool, name: String) -> void:
	if c:
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


func _texts(node: Node, out: Array[String] = []) -> Array[String]:
	for c in node.get_children():
		if c is Label:
			out.append((c as Label).text)
		_texts(c, out)
	return out


func _enter(scene: RunScreen, type: int) -> void:
	for n: MapNode in scene.run.map.nodes.values():
		if n.type == type:
			scene.run.map.current_id = n.prev[0] if not n.prev.is_empty() else -1
			scene.run.screen = S.MAP
			scene.run.choose_node(n.id)
			return


func _key(scene: RunScreen, code: Key) -> void:
	var k := InputEventKey.new()
	k.keycode = code
	k.pressed = true
	scene._unhandled_input(k)


func _test_bar_and_key(scene: RunScreen) -> void:
	_check(scene._bar.text.contains("Seed 4242") and scene._bar.text.contains("Seals 0") and not scene._bar.text.contains("Lv"),
		"seed: shown on the run bar; Seals as a count (%s)" % scene._bar.text)
	_check(scene.map_key.visible and scene.key_button.visible and scene.bag_button.visible, "key: open on Floor 1's map, with Key / Your dice buttons")
	var lines := _texts(scene.map_key)
	_check(lines.size() == 9 and lines[0] == "Map key" and MapKey.all_lines().size() == 8 and lines[1].ends_with(MapKey.LINES[NT.TABLE]),
		"key: a row per node type + path and re-sit lines (strings_v1)")
	_key(scene, KEY_K)
	_check(not scene.map_key.visible, "key: K collapses it")
	scene.key_button.pressed.emit()
	_check(scene.map_key.visible, "key: the Key button opens it")
	scene.run._start_floor(1)
	_check(not scene.map_key.visible, "key: collapsed on later floors")
	scene.run._start_floor(0)


func _test_dice_view(scene: RunScreen) -> void:
	_key(scene, KEY_D)
	var t := _texts(scene._panel_box)
	_check(scene._panel_root.visible and t.has("Your dice · 5/7") and t.has("Your Seals") and t.has(DicePanel.NO_SEALS),
		"dice view: D opens 'Your dice' with the Seals strip")
	var faces := 0
	for b in _buttons(scene._panel_box):
		faces += 1 if b.disabled and b.tooltip_text.begins_with("Face ") else 0
	_check(faces == 30, "dice view: every face of the 5 dice, read-only (%d)" % faces)
	_check(t.any(func(s: String) -> bool: return s.contains(DicePanel.BONE_LINE)), "dice view: plain dice say 'Bone die: plain faces 1 to 6.'")
	scene.refresh()
	scene.run.progress.add_seal_levels(&"trips", 1)
	scene.run.progress.set_face(0, 0, &"wild")
	scene.show_dice()
	t = _texts(scene._panel_box)
	var lv1 := t.any(func(s: String) -> bool: return s.begins_with("Trips Lv1: +"))
	_check(lv1 and not t.has(DicePanel.NO_SEALS), "seals: the first Trips Seal shows Lv1 with its +base / +mult")
	var wild := _buttons(scene._panel_box).any(func(b: Button) -> bool: return b.text == "1 Wild")
	_check(wild, "dice view: a modded face shows its number and mod")
	scene.refresh()
	_check(scene.map_view.visible, "dice view: Close / refresh goes back to the map")


func _test_shop_prices(scene: RunScreen) -> void:
	_enter(scene, NT.SHOP)
	var twin: FaceModData = load("res://resources/mods/twin.tres")
	scene.run.shop_mods[0] = twin
	scene.run.progress.set_face(1, 0, &"wild")
	scene.run.progress.set_face(1, 1, &"heavy")
	scene.run.progress.embers = 200
	scene._show_shop()
	var p0 := scene.run.progress.mod_price(twin, 2)
	var p1 := scene.run.progress.mod_price(twin, 1)
	var label := scene.mod_offer_text(0)
	_check(label == "Twin Face - %d to %d Embers, by die" % [p0, p1] and p1 > p0, "shop: the mod label shows the real price range (%s)" % label)
	var opened := false
	for b in _buttons(scene._panel_box):
		if b.text == label:
			b.pressed.emit()
			opened = true
			break
	var t := _texts(scene._panel_box)
	_check(opened and t.has(DicePanel.NEXT_MOD % p1) and t.has(DicePanel.NEXT_MOD % p0), "picker: each die shows what its next mod costs before you pay")
	var taken := _buttons(scene._panel_box).any(func(b: Button) -> bool: return b.disabled and b.tooltip_text.ends_with(DicePanel.TAKEN))
	_check(taken, "picker: a face with a mod is greyed with 'This face already has a face mod.'")
	var e0 := scene.run.progress.embers
	var clicked := false
	for b in _buttons(scene._panel_box):
		if not b.disabled and b.tooltip_text.begins_with("Face ") and b.get_parent().get_parent().get_index() == 2:
			b.pressed.emit()
			clicked = true
			break
	_check(clicked and scene.run.progress.embers == e0 - p1, "picker: buying on die 2 charges exactly the shown %d" % p1)
	scene.run.leave()


func _test_table_preview(scene: RunScreen) -> void:
	_enter(scene, NT.TABLE)
	var t := _texts(scene._panel_box)
	_check(t.has("Miss: -%d Soul per unclaimed bounty." % scene.run.goal.timeout_soul_per_bounty), "table preview: shows the miss cost")
	scene.run.rules = [load("res://resources/map/rules/short_table.tres")] as Array[RunRuleData]
	scene.run.goal.hands = 5
	scene.refresh()
	t = _texts(scene._panel_box)
	_check(t.has("Twist: Short Table - 5 hands."), "table preview: Short Table text matches the real hands")


func _test_end_screen(scene: RunScreen) -> void:
	scene.new_run(31337)
	_enter(scene, NT.BOSS)
	scene.run.quick_resolve(false)
	scene.run.quick_resolve(false)
	var t := _texts(scene._panel_box)
	_check(scene.run.screen == S.RUN_OVER and t.has("The Dealer Wins") and not t.has("Your Soul Burns Out"), "end: boss re-sit lost -> 'The Dealer Wins'")
	_check(t.has("Seed: 31337") and t.any(func(s: String) -> bool: return s.begins_with("Tables cleared:")), "end: summary with tables cleared and the seed")
	var names: Array = []
	for b in _buttons(scene._panel_box):
		names.append(b.text)
	_check(names.has("New run") and names.has("Quit to title"), "end: New run and Quit to title")


func _test_embers_hud() -> void:
	var tuning: BonfireTuning = load("res://resources/tuning/bonfire_tuning.tres")
	var st := TableSetup.sandbox(tuning)
	st.run_mode = true
	st.set("run_embers", 49)
	var b := (load("res://scenes/bonfire.tscn") as PackedScene).instantiate() as Bonfire3D
	b.setup = st
	root.add_child(b)
	await process_frame
	await process_frame
	b.bhud.refresh(b.run, true)
	_check(b.bhud.coin_label.text == "EMBERS %d" % (49 + b.run.embers), "EMBERS: the table HUD shows the run balance (%s)" % b.bhud.coin_label.text)
	var ms := MapRun.new(load("res://resources/map/bonfire_run.tres"), 3)
	ms.progress.embers = 77
	_enter_run(ms)
	_check(int(ms.table_setup().to_table_setup(tuning).get("run_embers")) == 77, "EMBERS: the run sends its balance as TableSetup.run_embers")
	b.queue_free()
	await process_frame


func _enter_run(run: MapRun) -> void:
	for n: MapNode in run.map.nodes.values():
		if n.type == NT.TABLE:
			run.map.current_id = n.prev[0] if not n.prev.is_empty() else -1
			run.choose_node(n.id)
			return
