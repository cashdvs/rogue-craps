## QA #201: the table-rules plaque (Powder Barrel row) never covers a thrown
## die: each die in turn is parked under it, and the plaque moves off it and
## stays on screen. A HUD-moved plaque keeps its new home (dodges from there
## and returns there). Real Bonfire HUD on
## PC 16:9, phone landscape and phone portrait.
##   godot --headless --path . --script res://tests/test_rules_plaque_die_clear.gd
extends SceneTree

const PHONE := Vector2(390, 844)

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
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
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


## Screen rect of a die: bounds of its 8 corners, independent of the code's.
func _die_rect(cam: Camera3D, d: DieVisual) -> Rect2:
	var r := Rect2(cam.unproject_position(d.global_position), Vector2.ZERO)
	for c in 8:
		var o := Vector3(1 if c & 1 else -1, 1 if c & 2 else -1, 1 if c & 4 else -1) * d.edge * 0.6
		r = r.expand(cam.unproject_position(d.global_position + o))
	return r


func _check_layout(s: Bonfire3D, label: String, shot: String) -> void:
	for k in 600:
		if s.phase == Table3D.Phase.BET and s.run.state == BonfireRun.State.AIM and not s.hand_moving():
			break
		await process_frame
	s.rig_faces([1, 1, 5, 2, 3] as Array[int])
	s.quick_throw()
	await s.sequence_finished
	s._refresh_hud()
	s.nerve_ui.refresh()
	await process_frame
	var h := s.bhud
	check(h.rules_panel.is_visible_in_tree(), "%s: rules plaque shown" % label)
	var cam := s.camera.cam
	var view := Rect2(Vector2.ZERO, s.get_viewport().get_visible_rect().size)
	# Clear the felt under the plaque first: its home is where it sits then.
	var away := Vector2(view.size.x * 0.15, view.size.y * 0.85)
	for d: DieVisual in s.throw_dice:
		_park(cam, d, away)
	for k in 3:
		await process_frame
	var home := h.rules_panel.get_global_rect()
	# Park each thrown die in turn under the plaque's home centre.
	for i in s.throw_dice.size():
		var d: DieVisual = s.throw_dice[i]
		check(_park(cam, d, home.get_center()), "%s: plaque centre is over the table" % label)
		for k in 3:
			await process_frame
		var a := h.rules_panel.get_global_rect()
		var b := _die_rect(cam, d)
		check(not a.intersects(b), "%s: plaque %s clear of die %d %s" % [label, str(a), i, str(b)])
		check(view.encloses(a), "%s: plaque %s on screen %s (die %d)" % [label, str(a), str(view), i])
		_park(cam, d, away)
	# The HUD moves the plaque (overridden home): it stays there while clear,
	# dodges a die from there, and comes back there, not to the old spot.
	for k in 3:
		await process_frame
	check(h.rules_panel.get_global_rect().position.is_equal_approx(home.position), "%s: plaque %s back home %s with no die under it" % [label, str(h.rules_panel.get_global_rect()), str(home)])
	var moved := home.position + Vector2(-home.size.x * 0.6, home.size.y * 0.5)
	h.rules_panel.global_position = moved
	for k in 3:
		await process_frame
	check(h.rules_panel.global_position.is_equal_approx(moved), "%s: HUD-moved plaque %s stays at %s" % [label, str(h.rules_panel.global_position), str(moved)])
	var d0: DieVisual = s.throw_dice[0]
	_park(cam, d0, Rect2(moved, home.size).get_center())
	for k in 3:
		await process_frame
	check(not h.rules_panel.get_global_rect().intersects(_die_rect(cam, d0)), "%s: moved plaque clear of its die" % label)
	_park(cam, d0, away)
	for k in 3:
		await process_frame
	check(h.rules_panel.global_position.is_equal_approx(moved), "%s: plaque returns to the new home %s, not the old (%s)" % [label, str(moved), str(h.rules_panel.global_position)])
	var a := h.rules_panel.get_global_rect()
	var pip := s.nerve_ui.pip_box
	check(not pip.is_visible_in_tree() or not pip.get_global_rect().intersects(a), "%s: Nerve pip still clear of the plaque" % label)
	if shot != "" and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		s.get_viewport().get_texture().get_image().save_png(shot % label.replace(" ", "_"))


## Puts [param d] where screen point [param at] meets its own table plane.
func _park(cam: Camera3D, d: DieVisual, at: Vector2) -> bool:
	var hit = Plane(Vector3.UP, d.global_position.y).intersects_ray(cam.project_ray_origin(at), cam.project_ray_normal(at))
	if hit != null:
		d.global_position = hit
	return hit != null


## place() alone: no room left of a wide die row, so it goes below it,
## never off screen.
func _check_place() -> void:
	var view := Rect2(0, 0, 844, 390)
	var r := Rect2(700, 100, 140, 50)
	var die := Rect2(10, 90, 820, 80)
	var at := RulesPlaqueDodge.place(r, [die] as Array[Rect2], view)
	var q := Rect2(at, r.size)
	check(view.encloses(q) and not q.intersects(die), "place: %s on screen, clear of %s" % [str(q), str(die)])
	check(RulesPlaqueDodge.place(r, [] as Array[Rect2], view) == r.position, "place: no die under it, stays put")


func _run() -> void:
	_check_place()
	var shot := OS.get_environment("PLAQUE_SHOT")
	var made: Array = await _make(Vector2i(1920, 1080))
	await _check_layout(made[1], "PC 16:9", shot)
	(made[0] as Node).queue_free()
	await process_frame
	made = await _make(Vector2i(2337, 1080))
	(made[1] as Bonfire3D).fit_phone(Vector2(844, 390))
	await _check_layout(made[1], "phone landscape", shot)
	(made[0] as Node).queue_free()
	await process_frame
	made = await _make(Vector2i(1920, int(round(1920.0 * PHONE.y / PHONE.x))))
	var s: Bonfire3D = made[1]
	s.camera.cam.current = true
	s.fit_phone(PHONE)
	s.camera.snap_home()
	await _check_layout(s, "phone portrait", shot)
	(made[0] as Node).queue_free()
	await process_frame
	print("test_rules_plaque_die_clear: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)
