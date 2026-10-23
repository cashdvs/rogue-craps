## Floor 3 boss signs (BossSign + RunRuleData sign fields): Baron Vig and
## Odds Bodkin carry their sign / icon textures and they load; the boss
## intro shows the sign as its header (@2x at 1080 px, @1x below, >=
## 600x210 units, centred) and so does the table's pause menu; the table
## HUD shows the icon + a bounty-card tooltip with the rule line (hover /
## focus, hidden while paused) for both; a rule that states a cost keeps
## its line visible; a boss without art (Mister Wick) or the Elite Greedy
## Pot twist keeps today's text row.
##   godot --headless --path . --script res://tests/test_boss_signs.gd
extends SceneTree

const S := MapRun.Screen
const NT := MapGenData.NodeType
const RULES := "res://resources/map/rules/"

var _passed: int = 0
var _failed: int = 0


func _check(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		print("FAIL: ", what)


func _initialize() -> void:
	print("=== Dice of the Damned: boss sign tests ===")
	_test_data()
	_test_lookup()
	_test_hand_pill()
	await _test_intro()
	_test_hud()
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _test_data() -> void:
	for n in ["baron_vig", "odds_bodkin"]:
		var r := load(RULES + n + ".tres") as RunRuleData
		_check(r != null and BossSign.has_sign(r), "%s: has sign art" % n)
		_check(r.sign_texture != null and r.sign_texture.get_size() == Vector2(600, 210), "%s: @1x sign loads at 600x210" % n)
		_check(r.sign_texture_2x != null and r.sign_texture_2x.get_size() == Vector2(1200, 420), "%s: @2x sign loads at 1200x420" % n)
		_check(r.rule_icon != null and r.rule_icon.get_size() == Vector2(128, 128), "%s: 128 px rule icon loads" % n)
		_check(r.tooltip_text != "" and r.sign_alt().contains(r.sign_tooltip().get_slice(" · ", 0)), "%s: tooltip + alt text" % n)
		for tex: Texture2D in [r.sign_texture, r.sign_texture_2x, r.rule_icon]:
			var imp := FileAccess.get_file_as_string(tex.resource_path + ".import")
			_check(imp.contains("mipmaps/generate=true"), "%s: mipmaps on for %s" % [n, tex.resource_path.get_file()])
	var vig := load(RULES + "baron_vig.tres") as RunRuleData
	var bod := load(RULES + "odds_bodkin.tres") as RunRuleData
	_check(vig.sign_tooltip() == "Pot at least 3 dice every throw; -1 hand." and vig.sign_tooltip() == vig.description and vig.sign_alt().contains("FLOOR 3 · THE HOUSE MINIMUM") and vig.sign_alt().contains("MIN 3") and vig.sign_alt().contains("-1 HAND"), "vig: sign wording")
	_check(vig.sign_hand_pill and not vig.tooltip_text.contains("hand") and not vig.sign_alt_text.contains("HAND"), "vig: no hardcoded hands text in the data")
	_check(not bod.sign_hand_pill and bod.sign_tooltip() == bod.tooltip_text, "bodkin: unchanged (pill baked in its art)")
	_check(bod.tooltip_text.contains("BOUNTIES COUNT ON 1ST THROW ONLY") and bod.tooltip_text.contains("+1 HAND")
		and bod.sign_alt_text.contains("FLOOR 3 · FIRST SHOT OR NOTHING") and bod.sign_alt_text.contains("1ST"), "bodkin: sign wording")
	var wick := load(RULES + "mister_wick.tres") as RunRuleData
	_check(not BossSign.has_sign(wick) and wick.rule_icon == null and BossSign.sign_texture(wick, 1080) == null, "wick: no art, null fields")
	_check(BossSign.sign_texture(vig, 1080) == vig.sign_texture_2x and BossSign.sign_texture(vig, 1440) == vig.sign_texture_2x, "sign: @2x at 1080 px and up")
	_check(BossSign.sign_texture(vig, 720) == vig.sign_texture, "sign: @1x below 1080 px")
	var sz := BossSign.sign_size(1920.0)
	_check(sz.x >= 600.0 and sz.y >= 210.0 and absf(sz.x - 640.0) < 1.0, "sign: a third of 1920 (640), never under 600x210")
	_check(BossSign.sign_size(1200.0).x == 600.0 and BossSign.sign_size(2400.0).x <= BossSign.MAX_WIDTH, "sign: clamped 600..720 (phone landscape ~600)")


func _test_lookup() -> void:
	_check(BossSign.for_table_rule(&"greedy_pot", {"min_pot": 3}) != null
		and BossSign.for_table_rule(&"greedy_pot", {"min_pot": 3}).display_name == "Baron Vig", "lookup: greedy_pot min 3 = Baron Vig")
	_check(BossSign.for_table_rule(&"first_throw", {"throws": 1}).display_name == "Odds Bodkin", "lookup: first_throw 1 = Odds Bodkin")
	_check(BossSign.for_table_rule(&"baron_vig").display_name == "Baron Vig" and BossSign.for_table_rule(&"odds_bodkin").display_name == "Odds Bodkin",
		"lookup: boss ids baron_vig / odds_bodkin")
	_check(BossSign.for_table_rule(&"greedy_pot", {"min_pot": 2}) == null and BossSign.for_table_rule(&"first_throw", {"throws": 2}) == null,
		"lookup: Elite Greedy Pot / First Throw twists get no boss art")
	_check(BossSign.for_table_rule(&"cold_sixes", {"face": 6}) == null and BossSign.for_table_rule(&"mister_wick") == null, "lookup: Mister Wick has none")


func _boss_table(scene: RunScreen, boss_file: String) -> void:
	var run := scene.run
	run.boss = load(RULES + boss_file + ".tres") as RunRuleData
	run.boss_twist = null
	run.table_type = NT.BOSS
	run.goal = run.make_goal(NT.BOSS)
	run._set_screen(S.TABLE)


func _test_intro() -> void:
	var scene: RunScreen = (load("res://scenes/run.tscn") as PackedScene).instantiate()
	scene.run_seed = 5
	root.add_child(scene)
	await process_frame
	scene.sign_px_height = 1080
	for n in ["baron_vig", "odds_bodkin"]:
		_boss_table(scene, n)
		var r := scene.run.boss
		var s := scene.boss_sign
		_check(s != null and s.get_parent() == scene._panel_box and s.get_index() == 0, "%s intro: the sign is the header" % n)
		var names := 0
		var cheat := false
		for c in scene._panel_box.get_children():
			if c is Label and not c.is_queued_for_deletion():
				names += 1 if (c as Label).text == r.display_name else 0
				cheat = cheat or (c as Label).text.begins_with("Cheat: %s" % r.display_name)
		_check(names == 0 and cheat, "%s intro: no orange name title; Cheat: line kept" % n)
		_check(s.texture == r.sign_texture_2x, "%s intro: @2x at 1080p" % n)
		_check(s.custom_minimum_size.x >= 600.0 and s.custom_minimum_size.y >= 210.0, "%s intro: >= 600x210 units" % n)
		_check(s.size_flags_horizontal == Control.SIZE_SHRINK_CENTER and s.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS, "%s intro: centred, linear + mipmaps" % n)
	scene.sign_px_height = 720
	_boss_table(scene, "baron_vig")
	_check(scene.boss_sign.texture == scene.run.boss.sign_texture, "intro: @1x at 720p")
	_boss_table(scene, "mister_wick")
	_check(scene.boss_sign == null and scene._panel_box.get_child(0) is Label
		and (scene._panel_box.get_child(0) as Label).text == "Mister Wick", "wick intro: no sign, text panel as before")
	var titles := 0
	for c in scene._panel_box.get_children():
		titles += 1 if c is TextureRect else 0
	_check(titles == 0, "wick intro: no texture in the panel")
	# Pause menu at the table: the sign under PAUSED.
	scene.sign_px_height = 1080
	_boss_table(scene, "odds_bodkin")
	scene._play_table()
	await process_frame
	var pm: PauseMenu = scene._table.pause_menu
	var ps := pm.panel.find_child("BossSign", true, false) as TextureRect
	_check(ps != null and ps.texture == scene.run.boss.sign_texture_2x and ps.get_index() == 1, "bodkin pause: @2x sign under PAUSED")
	_check(not BossSign.attach_to_pause(pm, load(RULES + "mister_wick.tres"), 1080), "wick pause: no sign attached")
	scene.queue_free()
	await process_frame


func _hud_row(entries: Array) -> Control:
	var t := load("res://resources/tuning/bonfire_tuning.tres") as BonfireTuning
	var run := BonfireRun.new(t, null, -1, 5)
	run.set_rules(TableRules.build(entries), 3)
	var hud := BonfireHud.new()
	root.add_child(hud)
	hud._refresh_rules(run)
	var row := hud.rules_box.get_child(0) as Control
	hud.set_meta("row", row)
	return row


func _test_hud() -> void:
	for n in ["baron_vig", "odds_bodkin"]:
		var r := load(RULES + n + ".tres") as RunRuleData
		var rts := RunTableSetup.new()
		rts.rules = [r] as Array[RunRuleData]
		var row := _hud_row(rts.rule_entries())
		var icon := row.find_child("RuleIcon", true, false) as TextureRect
		_check(icon != null and icon.texture == r.rule_icon, "%s HUD: 128 rule icon in the row" % n)
		_check(icon.custom_minimum_size.y >= 48 and icon.custom_minimum_size.y <= 64, "%s HUD: icon at 48-64 px" % n)
		var name_l := icon.get_parent().get_child(1) as Label
		_check(name_l.text == r.display_name.to_upper(), "%s HUD: shows the boss name" % n)
		_check(not BossSign.states_cost(r), "%s: states no cost" % n)
		var line := row.get_child(1) as Label
		_check(not line.visible and line.text == r.description, "%s HUD: rule line hidden (tooltip only)" % n)
		var tip := row.find_child("RuleTip", true, false) as BossRuleTip
		_check(tip != null and tip.label.text == r.description and row.tooltip_text == "", "%s HUD: tooltip is only the full rule line" % n)
		_check(tip.top_level and tip.label.label_settings.font_color == Palette.BONE, "%s HUD: tooltip top-level, cream text" % n)
		var sb := tip.get_theme_stylebox("panel") as StyleBoxFlat
		_check(sb != null and sb.bg_color == Color(Palette.FELT_DARK, 0.9) and sb.border_color == Palette.BRASS and sb.border_width_left == 2,
			"%s HUD: tooltip uses the bounty card box (FELT_DARK, 2 px BRASS)" % n)
		_check(row.focus_mode == Control.FOCUS_ALL and row.mouse_filter != Control.MOUSE_FILTER_IGNORE, "%s HUD: hover / focus / tap reachable" % n)
		_check(not tip.wanted(), "%s HUD: tooltip hidden until hover" % n)
		tip._on_enter()
		tip._process(0.1)
		_check(not tip.visible, "%s HUD: tooltip waits for the hover delay" % n)
		tip._process(BossRuleTip.DELAY)
		_check(tip.visible, "%s HUD: hover shows the tooltip" % n)
		paused = true
		tip._process(0.1)
		_check(not tip.visible, "%s HUD: tooltip hidden while paused" % n)
		paused = false
		tip._on_exit()
		tip._process(0.1)
		_check(not tip.visible, "%s HUD: tooltip hides on mouse exit" % n)
		row.grab_focus()
		tip._process(0.0)
		_check(tip.visible, "%s HUD: focus (pad / tap) shows the tooltip" % n)
		row.release_focus()
		_check(row.find_child("BossSign", true, false) == null, "%s HUD: never the whole sign" % n)
		row.get_parent().get_parent().get_parent().queue_free()
	for e in [{"id": &"cold_sixes", "params": {"face": 6}}, {"id": &"greedy_pot", "params": {"min_pot": 2}}]:
		var row := _hud_row([e])
		_check(row.find_child("RuleIcon", true, false) == null and row.get_child(0) is Label and row.find_child("RuleTip", true, false) == null
			and (row.get_child(1) as Label).visible, "fallback HUD (%s): today's text row" % e["id"])
		row.get_parent().get_parent().get_parent().queue_free()
	_test_cost_line()


## A rule that states a cost keeps its line under the name (Godot Dev).
func _test_cost_line() -> void:
	var vig := load(RULES + "baron_vig.tres") as RunRuleData
	for f in ["mister_wick", "bloodletter"]:
		_check(BossSign.states_cost(load(RULES + f + ".tres")), "%s: states a cost (bust / Soul)" % f)
	var cases := {}
	var a := vig.duplicate() as RunRuleData
	a.bust_soul_loss = 2
	cases["bust_soul_loss"] = a
	var b := vig.duplicate() as RunRuleData
	b.description = "A bust costs 2 Soul."
	cases["Soul in description"] = b
	var c := vig.duplicate() as RunRuleData
	c.params = {"min_pot": 3, "ember_cost": 5}
	cases["ember param"] = c
	var d := vig.duplicate() as RunRuleData
	d.hud_always_show_line = true
	cases["hud_always_show_line"] = d
	for k in cases:
		var r: RunRuleData = cases[k]
		var row := VBoxContainer.new()
		var name_l := Label.new()
		var line := Label.new()
		row.add_child(name_l)
		row.add_child(line)
		root.add_child(row)
		_check(BossSign.decorate_with(row, name_l, line, r) and row.find_child("RuleIcon", true, false) != null, "cost (%s): icon row" % k)
		_check(line.visible and line.text == r.description and row.find_child("RuleTip", true, false) == null, "cost (%s): line stays visible, no tooltip" % k)
		row.queue_free()
	var row2 := VBoxContainer.new()
	var nl := Label.new()
	row2.add_child(nl)
	_check(not BossSign.decorate_with(row2, nl, null, load(RULES + "mister_wick.tres")) and row2.get_child(0) == nl, "no icon: row untouched")
	row2.free()


## The Vig "-1 HAND" pill is a Label from hands_delta (not baked art), and
## the tooltip / alt text follow hands_delta too (QA, #136).
func _test_hand_pill() -> void:
	var vig := (load(RULES + "baron_vig.tres") as RunRuleData).duplicate() as RunRuleData
	var s := BossSign.make_sign(vig, 1080)
	var pill := s.get_node_or_null("HandPill") as Label
	_check(pill != null and pill.visible and pill.text == "-1 HAND", "pill: Label reads -1 HAND from hands_delta")
	var sb := pill.get_theme_stylebox("normal") as StyleBoxFlat
	_check(sb != null and sb.bg_color == Palette.BRASS, "pill: brass pill box")
	for d in [-2, 1]:
		vig.hands_delta = d
		BossSign.update_hand_pill(s, vig)
		var want := "%+d HAND" % d
		_check(pill.visible and pill.text == want, "pill: hands_delta %d -> %s" % [d, want])
		_check(vig.sign_tooltip() == "Pot at least 3 dice every throw; %+d hand." % d, "tooltip: follows hands_delta %d" % d)
		_check(vig.sign_alt().contains("Pill: " + want) and vig.sign_alt().contains(vig.sign_tooltip()), "alt text: follows hands_delta %d" % d)
		if "accessibility_name" in s:
			_check(s.get("accessibility_name") == vig.sign_alt(), "alt text: on the sign node (%d)" % d)
	vig.hands_delta = 0
	BossSign.update_hand_pill(s, vig)
	_check(not pill.visible and vig.hand_pill_text() == "" and not vig.sign_tooltip().contains("hand"), "pill: hidden at hands_delta 0")
	vig.hands_delta = -2
	s.free()
