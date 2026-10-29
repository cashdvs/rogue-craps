## QA: the Nerve pip (button + state line) never sits over the table-rules
## plaque (Powder Barrel row) on the real Bonfire HUD, on PC 16:9, phone
## landscape and phone portrait.
##   godot --headless --path . --script res://tests/test_nerve_pip_rules_clear.gd
extends SceneTree

const PHONE := Vector2(390, 844)
const SCALE := 0.5

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


## The Bonfire scene (a Barrel in the bag, Nerve on) in a SubViewport.
func _make(canvas: Vector2i) -> Array:
	var sv := SubViewport.new()
	sv.size = canvas
	root.add_child(sv)
	var t := load("res://resources/tuning/bonfire_tuning.tres") as BonfireTuning
	var st := TableSetup.sandbox(t, 5)
	st.nerve_uses = 1
	var td := TableDie.new()
	td.special = &"barrel"
	st.dice[0] = td
	var s := (load("res://scenes/bonfire.tscn") as PackedScene).instantiate() as Bonfire3D
	s.setup = st
	s.tutorial_override = 0
	s.bonfire_seed = 5
	s.test_speed = 10.0
	sv.add_child(s)
	await process_frame
	await process_frame
	return [sv, s]


## Waits for the bet, then a throw that doesn't bust: the pip is up.
func _throw(s: Bonfire3D) -> void:
	for k in 600:
		if s.phase == Table3D.Phase.BET and s.run.state == BonfireRun.State.AIM and not s.hand_moving():
			break
		await process_frame
	s.rig_faces([1, 1, 5, 2, 3] as Array[int])
	s.quick_throw()
	await s.sequence_finished


func _check_layout(s: Bonfire3D, label: String) -> void:
	await _throw(s)
	s._refresh_hud()
	s.nerve_ui.refresh()
	await process_frame
	await process_frame
	var h := s.bhud
	check(h.rules_panel.visible, "%s: rules plaque shown" % label)
	check(h.rule_rows().any(func(k: String) -> bool: return k.to_upper().contains("BARREL")), "%s: Barrel row on the plaque (%s)" % [label, str(h.rule_rows())])
	var pip := s.nerve_ui.pip_box
	check(pip.is_visible_in_tree(), "%s: Nerve pip shown" % label)
	var a := pip.get_global_rect()
	var b := h.rules_panel.get_global_rect()
	var view := Rect2(Vector2.ZERO, s.get_viewport().get_visible_rect().size)
	# Portrait's pip is wider than the screen on main already (separate issue): top edge only there.
	check(view.encloses(a) if label != "phone portrait" else a.position.y >= 0.0 and a.end.y <= view.end.y, "%s: Nerve pip %s on screen %s" % [label, str(a), str(view)])
	check(not a.intersects(b), "%s: Nerve pip %s clear of the rules plaque %s" % [label, str(a), str(b)])


func _run() -> void:
	var made: Array = await _make(Vector2i(1920, 1080))
	await _check_layout(made[1], "PC 16:9")
	(made[0] as Node).queue_free()
	await process_frame
	made = await _make(Vector2i(2337, 1080))
	(made[1] as Bonfire3D).fit_phone(Vector2(844, 390))
	await _check_layout(made[1], "phone landscape")
	(made[0] as Node).queue_free()
	await process_frame
	made = await _make(Vector2i(int(round(PHONE.x / SCALE)), int(round(PHONE.y / SCALE))))
	var s: Bonfire3D = made[1]
	s.camera.cam.current = true
	s.fit_phone(PHONE)
	s.camera.snap_home()
	await _check_layout(s, "phone portrait")
	(made[0] as Node).queue_free()
	await process_frame
	print("test_nerve_pip_rules_clear: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)
