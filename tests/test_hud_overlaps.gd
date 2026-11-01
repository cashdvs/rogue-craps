## Two HUD overlaps on the real Bonfire scene, on PC 1600x900-style,
## phone landscape 844x390 and portrait 390x844:
##   - the goal plate never covers the boss rules card (QA #231: MADAME
##     SHUFFLE showed under the plate on phone), also after the plate grows;
##   - the first-table controls text starts right of the "?" button, by its
##     width + 8 px (#218: "...the dice and flick" was under the button);
##   - the EMBERS / points lines never touch the plate (QA Oct 31: on phone
##     "points ..." sat on the plate's top edge), >= 4 pt apart on phone.
## Checks use the live global rects.
##   godot --headless --path . --script res://tests/test_hud_overlaps.gd
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


func _frames(n: int) -> void:
	for i in n:
		await process_frame


## A boss-ruled first table (Madame Shuffle), fitted to `screen` (or PC).
func _make(canvas: Vector2i, screen: Vector2) -> Array:
	var sv := SubViewport.new()
	sv.size = canvas
	root.add_child(sv)
	var t := load("res://resources/tuning/bonfire_tuning.tres") as BonfireTuning
	var s := (load("res://scenes/bonfire.tscn") as PackedScene).instantiate() as Bonfire3D
	s.setup = TableSetup.sandbox(t, 5)
	s.setup.rules = [&"madame_shuffle"]
	s.setup.first_table = true
	s.tutorial_override = 0
	sv.add_child(s)
	await _frames(2)
	if screen != Vector2.ZERO:
		s.fit_phone(screen)
		s._refresh_hud()  # what the game does after a fit: turns on phone mode
	await _frames(4)
	return [sv, s]


func _check(canvas: Vector2i, screen: Vector2, tag: String) -> void:
	var m: Array = await _make(canvas, screen)
	var s: Bonfire3D = m[1]
	var h := s.bhud
	var plate := h.target_plate.get_global_rect()
	var rules := h.rules_panel.get_global_rect()
	check(h.rules_panel.visible and h.rule_rows().size() > 0, "%s: the boss rules card shows (%s)" % [tag, str(h.rule_rows())])
	check(not plate.intersects(rules), "%s: plate %s does not cover the rules card %s" % [tag, plate, rules])
	check(rules.position.y >= plate.end.y + BonfireHud.RULES_GAP - 0.5 or rules.end.y <= plate.position.y,
		"%s: rules card sits >= %d px under the plate (%.1f vs %.1f)" % [tag, BonfireHud.RULES_GAP, rules.position.y, plate.end.y])
	check(rules.end.y <= h.get_viewport_rect().size.y and rules.end.x <= h.get_viewport_rect().size.x + 0.5, "%s: rules card stays on screen %s" % [tag, rules])
	check(h.is_phone_land == (screen.x > screen.y), "%s: phone landscape mode is %s" % [tag, h.is_phone_land])
	var gap := BonfireHud.EMBERS_GAP_PT * h.ui_pt_px if h.is_phone_land else 0.0
	for l: Label in [h.coin_label, h.points_label]:
		var r := l.get_global_rect()
		check(not r.grow(gap - 0.5).intersects(plate), "%s: '%s' %s clear of the plate %s by >= %.0f px" % [tag, l.text, r, plate, gap])
		check(not r.intersects(rules), "%s: '%s' clear of the rules card %s" % [tag, l.text, rules])
		if h.is_phone_land:  # room above the plate here, so that's where they go
			check(r.end.y <= plate.position.y - gap + 0.5 and r.end.x <= plate.end.x + 0.5, "%s: '%s' above the plate, right-aligned with it" % [tag, l.text])
		check(r.position.y >= 0.0 and r.end.x <= h.get_viewport_rect().size.x + 0.5, "%s: '%s' on screen %s" % [tag, l.text, r])
	# The plate grows (a taller goal row): the rules card follows it.
	var grow := 30.0
	h.target_plate.custom_minimum_size.y = h.target_plate.size.y + grow
	await _frames(2)
	plate = h.target_plate.get_global_rect()
	rules = h.rules_panel.get_global_rect()
	check(not plate.intersects(rules), "%s: after the plate grows %d px, still no overlap (%s / %s)" % [tag, grow, plate, rules])
	h.target_plate.custom_minimum_size.y = 0
	# The controls text vs the "?" button.
	var lab := s.help_label.get_global_rect()
	var btn := s.help_corner.button.get_global_rect()
	check(s.help_label.visible, "%s: first table shows the controls text" % tag)
	check(not lab.intersects(btn), "%s: controls text %s clear of the ? button %s" % [tag, lab, btn])
	check(lab.position.x >= btn.end.x + 8.0 - 0.5, "%s: text starts at button end + 8 (%.1f >= %.1f)" % [tag, lab.position.x, btn.end.x + 8])
	m[0].queue_free()
	await process_frame


func _run() -> void:
	await _check(Vector2i(1920, 1080), Vector2.ZERO, "PC")
	await _check(Vector2i(2337, 1080), Vector2(844, 390), "phone landscape")
	await _check(Vector2i(1920, 4155), Vector2(390, 844), "portrait")
	print("test_hud_overlaps: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)
