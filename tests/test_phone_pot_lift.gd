## #218 polish: on phone landscape (844x390) the pot block lifts 8 pt, so the
## hint line ("Click lit dice to pot one combo.") no longer touches the
## bottom bar. PC and portrait keep the design spots. Real phone mode is on
## (fit_phone + _refresh_hud, like the game). Checks use live global rects.
##   godot --headless --path . --script res://tests/test_phone_pot_lift.gd
extends SceneTree

var _passed: int = 0
var _failed: int = 0
## The pot block's design spots (bonfire_hud_build.gd), y only.
const HOME_Y := {"pot": 860.0, "throw": 930.0, "notes": 982.0, "risk": 1018.0, "mult": 880.0}


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


func _check(canvas: Vector2i, screen: Vector2, tag: String) -> void:
	var sv := SubViewport.new()
	sv.size = canvas
	root.add_child(sv)
	var s := (load("res://scenes/bonfire.tscn") as PackedScene).instantiate() as Bonfire3D
	s.setup = TableSetup.sandbox(load("res://resources/tuning/bonfire_tuning.tres"), 5)
	s.tutorial_override = 0
	sv.add_child(s)
	await _frames(2)
	if screen != Vector2.ZERO:
		s.fit_phone(screen)
		s._refresh_hud()
	await _frames(3)
	var h := s.bhud
	var phone := screen.x > screen.y
	check(h.is_phone_land == phone, "%s: phone landscape mode %s" % [tag, h.is_phone_land])
	var lift := 8.0 * h.ui_pt_px if phone else 0.0
	var labels := {"pot": h.pot_label, "throw": h.throw_label, "notes": h.notes_label, "risk": h.risk_label, "mult": h.mult_label}
	for k: String in labels:
		var y: float = labels[k].get_global_rect().position.y
		check(is_equal_approx(y, HOME_Y[k] - lift), "%s: %s line at y %.1f (want %.1f)" % [tag, k, y, HOME_Y[k] - lift])
	if phone:
		h.throw_label.text = "Click lit dice to pot one combo."
		await _frames(1)
		var hint := h.throw_label.get_global_rect()
		var bar := h.bottom_bar.get_global_rect()
		check(h.bottom_bar.visible and hint.end.y <= bar.position.y + 0.5,
			"%s: hint line ends at %.1f, on or above the bar top %.1f" % [tag, hint.end.y, bar.position.y])
		check(hint.end.y <= h.get_viewport_rect().size.y and hint.position.y > h.target_plate.get_global_rect().end.y, "%s: hint stays on screen, under the plate" % tag)
	sv.queue_free()
	await process_frame


func _run() -> void:
	await _check(Vector2i(1920, 1080), Vector2.ZERO, "PC")
	await _check(Vector2i(2337, 1080), Vector2(844, 390), "phone landscape")
	await _check(Vector2i(1920, 4155), Vector2(390, 844), "portrait")
	print("test_phone_pot_lift: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)
