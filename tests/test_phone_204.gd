## #204 on the real Bonfire scene: phone landscape 844x390 shows the bottom
## bar (SEALS at its right end) and no felt combo print or slot numbers;
## portrait shows no felt print either; PC keeps the felt print, and a combo
## with no Seal reads "30x3" (no "Lv1") while a sealed one reads "Lv3 30x3".
## The camera framing itself is in test_bonfire_camera.gd.
##   godot --headless --path . --script res://tests/test_phone_204.gd
extends SceneTree

var _passed: int = 0
var _failed: int = 0


func _initialize() -> void:
	_run.call_deferred()


func check(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		print("FAIL  ", what)


func _make(canvas: Vector2i) -> Array:
	var sv := SubViewport.new()
	sv.size = canvas
	root.add_child(sv)
	var t := load("res://resources/tuning/bonfire_tuning.tres") as BonfireTuning
	var s := (load("res://scenes/bonfire.tscn") as PackedScene).instantiate() as Bonfire3D
	s.setup = TableSetup.sandbox(t, 5)
	s.tutorial_override = 0
	s.bonfire_seed = 5
	sv.add_child(s)
	await process_frame
	await process_frame
	return [sv, s]


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	await _check_pc()
	await _check_phone(Vector2i(2337, 1080), Vector2(844, 390), "phone landscape")
	await _check_phone(Vector2i(1920, 4155), Vector2(390, 844), "portrait")
	print("test_phone_204: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


## True while the felt shader shows the combo print.
func _print_on(s: Bonfire3D) -> bool:
	return bool(s.felt_combos.felt_material.get_shader_parameter("use_overlay"))


func _check_pc() -> void:
	var m: Array = await _make(Vector2i(1920, 1080))
	var s: Bonfire3D = m[1]
	var fc := s.felt_combos
	check(not fc.off and _print_on(s) and not fc.labels.is_empty(), "PC: felt combo print and numbers on")
	check(not s.bhud.bottom_bar.visible, "PC: no phone bottom bar")
	var c: BonfireCombo = null
	for k in s.bonfire_tuning.combos:
		if (k as BonfireCombo).id in fc.labels:
			c = k
			break
	check(c != null and fc.slot_text(c) == "%dx%d" % [c.base, c.mult], "no Seal: no 'Lv1' (%s)" % (fc.slot_text(c) if c else "?"))
	check(c != null and (fc.labels[c.id] as Label3D).text.begins_with("%d" % c.base), "the felt label shows it too")
	fc.set_combos(s.bonfire_tuning, {c.id: 3})
	check(fc.slot_text(c) == "Lv3 %dx%d" % [c.base, c.mult] and fc.slot_text(c, true).begins_with("L3 "), "sealed: Lv3 / L3")
	m[0].queue_free()
	await process_frame


func _check_phone(canvas: Vector2i, screen: Vector2, tag: String) -> void:
	var m: Array = await _make(canvas)
	var s: Bonfire3D = m[1]
	s.fit_phone(screen)
	s._refresh_hud()
	await _frames(2)
	var fc := s.felt_combos
	check(fc.off and not _print_on(s), "%s: felt combo print off" % tag)
	await _frames(1)
	check(fc.labels.is_empty() and fc.find_children("*", "Label3D", false, false).is_empty(), "%s: no felt slot numbers" % tag)
	var h := s.bhud
	var land := screen.x > screen.y
	check(h.bottom_bar.visible == land, "%s: bottom bar %s" % [tag, "shown" if land else "hidden"])
	if land:
		var pt := h.ui_pt_px
		var bar := h.bottom_bar.get_global_rect()
		check(absf(bar.size.y - PhoneBottomBar.HEIGHT_PT * pt) < 1 and absf(bar.end.y - canvas.y) < 1 and absf(bar.size.x - canvas.x) < 1, "bar: full width, 44 pt, on the bottom edge %s" % bar)
		check(h.bottom_bar.get_index() == 0 and h.bottom_bar.z_index < 0, "bar drawn behind the other HUD nodes (why_label too)")
		h.goal_state.set_for_test(300, 0, h.goal_state.hands_left, null, 2)
		await _frames(2)
		var sc := h.target_plate.seals_chip.get_global_rect()
		check(h.target_plate.seals_chip.visible and bar.encloses(sc), "SEALS sits in the bar %s" % sc)
		check(absf(sc.end.x - (canvas.x - PhoneBottomBar.SEALS_RIGHT_PT * pt)) < 1.5, "SEALS at the bar's right end")
	m[0].queue_free()
	await process_frame
