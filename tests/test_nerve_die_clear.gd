## PM #198: while the Nerve UI is showing, its "Nerve ready" pip and the
## rescue prompt never cover a landed die. QA's phone shot had the Gallows
## d4 hidden under the pip. Here the d4 is parked right under the pip's
## centre after a real throw, and the pip must move off it and stay on
## screen. QA #198: it also never covers other text, e.g. the felt combo
## strip's "Five of a Kind" (3D labels) or HUD labels, right after the
## throw and with the d4 parked. Real Bonfire HUD on PC 16:9 and phone
## landscape (844x390). Nor any bounty card (the pip and the rescue panel), nor the rules plaque.
##   godot --headless --path . --script res://tests/test_nerve_die_clear.gd
extends SceneTree

var _passed: int = 0
var _failed: int = 0


func _initialize() -> void:
	# The sandbox table_1 is a real F1 target table now; this suite tests bounties.
	var sandbox_tuning := load("res://resources/tuning/bonfire_tuning.tres") as BonfireTuning
	sandbox_tuning.table_goal = load("res://tests/fixtures/bounty_table_1.tres") as TableGoal
	set_meta(&"sandbox_tuning", sandbox_tuning)  # keep it cached so every load sees the fixture
	_run.call_deferred()


func check(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		print("FAIL  ", what)


## The real scene in a SubViewport, with Nerve on and a Gallows d4 as the last die.
func _make(canvas: Vector2i) -> Array:
	var sv := SubViewport.new()
	sv.size = canvas
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(sv)
	var t := load("res://resources/tuning/bonfire_tuning.tres") as BonfireTuning
	var st := TableSetup.sandbox(t, 5)
	st.nerve_uses = 1
	st.dice[st.dice.size() - 1] = TableDie.new(DiceIds.DIE_GALLOWS, "Gallows", DiceIds.shape_of(DiceIds.DIE_GALLOWS))
	var s := (load("res://scenes/bonfire.tscn") as PackedScene).instantiate() as Bonfire3D
	s.setup = st
	s.tutorial_override = 0
	s.bonfire_seed = 5
	s.test_speed = 10.0
	sv.add_child(s)
	await process_frame
	await process_frame
	return [sv, s]


## Screen rect of the d4, worked out here (not with the game's own helper):
## the bounds of a box reaching its 0.065 m cap in every direction.
func _d4_rect(cam: Camera3D, d: DieVisual) -> Rect2:
	var h := PolyDie.cap_for(&"d4")
	var r := Rect2(cam.unproject_position(d.global_position), Vector2.ZERO)
	for c in 8:
		var o := Vector3(1 if c & 1 else -1, 1 if c & 2 else -1, 1 if c & 4 else -1) * h
		r = r.expand(cam.unproject_position(d.global_position + o))
	return r


## Every piece of text on screen, worked out here: visible non-empty 2D
## labels / buttons (not the Nerve UI's own, not the bounty cards it hangs
## under) and the felt's 3D labels (combo strip, seal row).
func _text_rects(s: Bonfire3D) -> Array:
	var out := []
	var cam := s.camera.cam
	for n in s.get_viewport().find_children("*", "Control", true, false):
		var c := n as Control
		if not (c is Label or c is Button) or str(c.get("text")).strip_edges() == "" or not c.is_visible_in_tree():
			continue
		var mine := s.nerve_ui.is_ancestor_of(c)
		for card: Control in s.bhud.bounty_cards.values():
			mine = mine or card == c or card.is_ancestor_of(c)
		if not mine and c.modulate.a > 0.05:
			out.append([c.get_global_rect(), str(c.get("text"))])
	for n in s.get_viewport().find_children("*", "Label3D", true, false):
		var l := n as Label3D
		if l.is_visible_in_tree() and l.text.strip_edges() != "" and not l is D4ValueTag:
			var ab := l.get_aabb()
			var r := Rect2(cam.unproject_position(l.global_transform * ab.get_endpoint(0)), Vector2.ZERO)
			for i in 8:
				r = r.expand(cam.unproject_position(l.global_transform * ab.get_endpoint(i)))
			out.append([r, l.text])
	return out


func _check_text_clear(s: Bonfire3D, a: Rect2, label: String) -> void:
	var hits := []
	for t in _text_rects(s):
		if (t[0] as Rect2).intersects(a):
			hits.append(t[1])
	check(hits.is_empty(), "%s: pip %s covers no text %s" % [label, str(a), str(hits)])


## QA #198: neither the pip nor the rescue panel overlaps any bounty card
## showing (the phone pip sat on the FULL HOUSE +5 card).
func _check_cards(s: Bonfire3D, label: String) -> void:
	var cards := []
	for c: Control in s.bhud.bounty_cards.values():
		if c.is_visible_in_tree():
			cards.append(c)
	check(not cards.is_empty(), "%s: bounty cards showing" % label)
	for p: Control in [s.nerve_ui.pip_box, s.nerve_ui.rescue_panel]:
		var hits := []
		for c: Control in cards:
			if p.get_global_rect().intersects(c.get_global_rect()):
				hits.append(c.name)
		check(hits.is_empty(), "%s: %s %s overlaps no bounty card %s" % [label, p.name, str(p.get_global_rect()), str(hits)])


## The rules plaque (e.g. Powder Barrel) blocks the Nerve panels as a whole
## box: shown, it is in NerveUi._blockers and neither panel overlaps it.
func _check_plaque(s: Bonfire3D, label: String) -> void:
	var p := s.bhud.rules_panel
	p.visible = true
	for k in 3:
		await process_frame
	var pr := p.get_global_rect()
	var listed := false
	for b: Rect2 in s.nerve_ui._blockers(s.bhud):
		listed = listed or b.is_equal_approx(pr)
	check(listed, "%s: rules plaque %s is a Nerve blocker" % [label, str(pr)])
	for c: Control in [s.nerve_ui.pip_box, s.nerve_ui.rescue_panel]:
		check(not c.get_global_rect().intersects(pr), "%s: %s clear of the rules plaque" % [label, c.name])
	p.visible = false


func _check_layout(s: Bonfire3D, label: String, shot: String) -> void:
	for k in 600:
		if s.phase == Table3D.Phase.BET and s.run.state == BonfireRun.State.AIM and not s.hand_moving():
			break
		await process_frame
	s.quick_throw()
	await s.sequence_finished
	s._refresh_hud()
	s.nerve_ui.refresh()
	await process_frame
	var pip := s.nerve_ui.pip_box
	check(s.nerve_ui.visible and pip.is_visible_in_tree(), "%s: Nerve pip showing" % label)
	for k in 3:
		await process_frame
	_check_text_clear(s, pip.get_global_rect(), label + " after throw")
	_check_cards(s, label + " after throw")
	var d: DieVisual
	for x: DieVisual in s.throw_dice:
		if x.shape == &"d4":
			d = x
	check(d != null, "%s: the Gallows d4 is on the table" % label)
	if d == null:
		return
	# Park the d4 under the pip's centre, on its own resting plane.
	var cam := s.camera.cam
	var c := pip.get_global_rect().get_center()
	var hit = Plane(Vector3.UP, d.global_position.y).intersects_ray(cam.project_ray_origin(c), cam.project_ray_normal(c))
	check(hit != null, "%s: pip centre is over the table" % label)
	if hit != null:
		d.global_position = hit
	for k in 3:
		await process_frame
	var a := pip.get_global_rect()
	var view := Rect2(Vector2.ZERO, s.get_viewport().get_visible_rect().size)
	check(not a.intersects(_d4_rect(cam, d)), "%s: pip %s clear of the d4 %s" % [label, str(a), str(_d4_rect(cam, d))])
	check(view.encloses(a), "%s: pip %s on screen" % [label, str(a)])
	_check_text_clear(s, a, label + " d4 parked")
	_check_cards(s, label + " d4 parked")
	await _check_plaque(s, label)
	# The game's own die rect must reach the d4's full size (its 0.065 m cap).
	var game := RulesPlaqueDodge.die_rect(cam, d)
	check(game.encloses(_d4_rect(cam, d)), "%s: die_rect %s covers the whole d4 %s" % [label, str(game), str(_d4_rect(cam, d))])
	if shot != "" and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		s.get_viewport().get_texture().get_image().save_png(shot % label.replace(" ", "_"))


func _run() -> void:
	var shot := OS.get_environment("NERVE_SHOT")
	var made: Array = await _make(Vector2i(1920, 1080))
	await _check_layout(made[1], "PC 16:9", shot)
	(made[0] as Node).queue_free()
	await process_frame
	made = await _make(Vector2i(2337, 1080))
	(made[1] as Bonfire3D).fit_phone(Vector2(844, 390))
	await _check_layout(made[1], "phone landscape", shot)
	(made[0] as Node).queue_free()
	await process_frame
	print("test_nerve_die_clear: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)
