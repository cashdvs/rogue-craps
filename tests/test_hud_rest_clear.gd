## A resting die must not sit under a HUD button or the Soul lantern plate.
## Places a die at the felt point under Throw / Bank (Hot Hand is that same
## button) on desktop 16:9, phone landscape and phone portrait, slides it
## with HudRestClear, and checks the screen box misses every HUD button.
## The up face does not change. 1024x576 is the same 16:9 canvas as
## 1920x1080 (project stretch scales it onto the window); a raw 1024x576
## viewport is checked too, where the buttons fall below the screen and
## the lantern plate is what covers the felt.
##   godot --headless --path . --script res://tests/test_hud_rest_clear.gd
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


func _run() -> void:
	await _layout(Vector2i(1920, 1080), Vector2.ZERO, "desktop 1920x1080", true)
	await _layout(Vector2i(1024, 576), Vector2.ZERO, "desktop 1024x576", false)
	await _layout(Vector2i(2337, 1080), Vector2(844, 390), "phone landscape", false)
	await _layout(Vector2i(1920, 4155), Vector2(390, 844), "phone portrait", false)
	print("test_hud_rest_clear: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _layout(canvas: Vector2i, screen: Vector2, tag: String, scaled_window: bool) -> void:
	var made: Array = await _make(canvas, screen)
	var s: Bonfire3D = made[1]
	var die := s.all_dice[0]
	var face := die.up_slot()
	var basis := die.global_transform.basis
	var under_button := _place_under_buttons(s, die)
	if not under_button:
		# No on-screen button covers the felt (the raw 1024x576 viewport).
		check(tag == "desktop 1024x576", "%s: buttons cover the felt, or this is the unstretched viewport" % tag)
		check(_place_under_plate(s, die), "%s: a felt point sits under the Soul plate" % tag)
	else:
		check(true, "%s: die placed under Throw / Bank" % tag)
	var start := die.global_position
	check(_overlaps_controls(s, die), "%s: before the slide the die is hidden (%s)" % [tag, start])
	var moved := HudRestClear.clear(s.camera.cam, s.all_dice, HudRestClear.blockers(s), s.tuning.die_size)
	check(moved, "%s: the slide moved the die (%s -> %s)" % [tag, start, die.global_position])
	check(not _overlaps_controls(s, die), "%s: die screen box misses every HUD button and the Soul plate" % tag)
	check(die.up_slot() == face and die.global_transform.basis.is_equal_approx(basis), "%s: up face unchanged (%d)" % [tag, die.up_slot()])
	var lim := Table3DBuilder.FELT_HALF
	check(absf(die.global_position.x) <= lim.x and absf(die.global_position.z) <= lim.y, "%s: die stayed on the felt %s" % [tag, die.global_position])
	var end := die.global_position
	die.global_position = start
	HudRestClear.clear(s.camera.cam, s.all_dice, HudRestClear.blockers(s), s.tuning.die_size)
	check(die.global_position.is_equal_approx(end), "%s: the same start slides to the same spot" % tag)
	if scaled_window:
		_scaled_1024(s, die, tag)
		_two_dice(s)
	# A die in the middle of the felt is not dragged.
	var mid := s.all_dice[2]
	var home := Vector3(0.0, s.tuning.die_size * 0.5, 0.0)
	mid.global_position = home
	if not _overlaps_controls(s, mid):
		HudRestClear.clear(s.camera.cam, s.all_dice, HudRestClear.blockers(s), s.tuning.die_size)
		check(mid.global_position.is_equal_approx(home), "%s: a clear die is left where it landed" % tag)
	made[0].queue_free()
	await process_frame


## 1024x576 uses the 1920x1080 canvas, scaled to the window. Clearance survives that scale.
func _scaled_1024(s: Bonfire3D, die: DieVisual, tag: String) -> void:
	var k := 1024.0 / 1920.0
	var box := RulesPlaqueDodge.die_rect(s.camera.cam, die)
	var d := Rect2(box.position * k, box.size * k)
	for b: Rect2 in _buttons(s):
		var r := Rect2(b.position * k, b.size * k)
		check(not d.intersects(r), "%s: 1024x576 window keeps the die clear of a button" % tag)


## Two dice under the same button both end visible, apart, faces unchanged.
func _two_dice(s: Bonfire3D) -> void:
	var a := s.all_dice[0]
	var b := s.all_dice[1]
	check(_place_under_buttons(s, a), "two dice: first sits under Throw / Bank")
	b.global_position = a.global_position + Vector3(0.02, 0.0, 0.0)
	var fa := a.up_slot()
	var fb := b.up_slot()
	HudRestClear.clear(s.camera.cam, s.all_dice, HudRestClear.blockers(s), s.tuning.die_size)
	check(not _overlaps_controls(s, a) and not _overlaps_controls(s, b), "two dice: both miss the buttons and the plate")
	check(a.up_slot() == fa and b.up_slot() == fb, "two dice: up faces unchanged")
	var gap := Vector2(a.global_position.x - b.global_position.x, a.global_position.z - b.global_position.z)
	check(gap.length() >= s.tuning.die_size * 1.1, "two dice: they don't finish on top of each other (%.3f m)" % gap.length())


func _make(canvas: Vector2i, screen: Vector2) -> Array:
	var sv := SubViewport.new()
	sv.size = canvas
	root.add_child(sv)
	var t := load("res://resources/tuning/bonfire_tuning.tres") as BonfireTuning
	var s := (load("res://scenes/bonfire.tscn") as PackedScene).instantiate() as Bonfire3D
	s.setup = TableSetup.sandbox(t, 5)
	s.tutorial_override = 0
	sv.add_child(s)
	await process_frame
	await process_frame
	if screen != Vector2.ZERO:
		s.fit_phone(screen)
		s._refresh_hud()
	s._update_portrait_hud()
	s.camera.snap_home()
	await process_frame
	return [sv, s]


## Puts [param die] on the felt under Throw or Bank. False if neither button covers the felt.
func _place_under_buttons(s: Bonfire3D, die: DieVisual) -> bool:
	var cam := s.camera.cam
	var y := s.tuning.die_size * 0.5
	var view := _view(s)
	for b: Button in [s.bhud.throw_button, s.bhud.bank_button]:
		var r := b.get_global_rect().intersection(view)
		if not r.has_area():
			continue
		var world := _ray(cam, r.get_center(), y)
		if not _on_felt(world, s.tuning.die_size):
			continue
		die.global_position = world
		if RulesPlaqueDodge.die_rect(cam, die).intersects(b.get_global_rect()):
			return true
	for ix in range(-10, 11):
		for iz in range(-5, 6):
			die.global_position = Vector3(ix * 0.1, y, iz * 0.1)
			if _overlaps_buttons(s, die):
				return true
	return false


func _place_under_plate(s: Bonfire3D, die: DieVisual) -> bool:
	var cam := s.camera.cam
	var y := s.tuning.die_size * 0.5
	var plate := s.reliquary_rect().intersection(_view(s))
	if not plate.has_area():
		return false
	for ix in range(-10, 11):
		for iz in range(-5, 6):
			die.global_position = Vector3(ix * 0.1, y, iz * 0.1)
			if RulesPlaqueDodge.die_rect(cam, die).intersects(plate):
				return true
	return false


func _overlaps_controls(s: Bonfire3D, die: DieVisual) -> bool:
	var cam := s.camera.cam
	if cam.is_position_behind(die.global_position):
		return true
	var box := RulesPlaqueDodge.die_rect(cam, die)
	if _overlaps_buttons(s, die):
		return true
	var plate := s.reliquary_rect().intersection(_view(s))
	return plate.has_area() and box.intersects(plate)


func _overlaps_buttons(s: Bonfire3D, die: DieVisual) -> bool:
	var box := RulesPlaqueDodge.die_rect(s.camera.cam, die)
	for r: Rect2 in _buttons(s):
		if box.intersects(r):
			return true
	return false


func _buttons(s: Bonfire3D) -> Array[Rect2]:
	var view := _view(s)
	var out: Array[Rect2] = []
	for n: Node in s.bhud.find_children("*", "Button", true, false):
		var b := n as Button
		if b.is_visible_in_tree() and str(b.text).strip_edges() != "":
			var r := b.get_global_rect().intersection(view)
			if r.has_area():
				out.append(r)
	return out


func _view(s: Bonfire3D) -> Rect2:
	return Rect2(Vector2.ZERO, s.get_viewport().get_visible_rect().size)


func _on_felt(p: Vector3, die: float) -> bool:
	if p == Vector3.INF:
		return false
	var lim := Table3DBuilder.FELT_HALF - Vector2.ONE * die * 0.5
	return absf(p.x) <= lim.x + 0.02 and absf(p.z) <= lim.y + 0.02


func _ray(cam: Camera3D, screen: Vector2, y: float) -> Vector3:
	var origin := cam.project_ray_origin(screen)
	var dir := cam.project_ray_normal(screen)
	if absf(dir.y) < 0.00001:
		return Vector3.INF
	var t := (y - origin.y) / dir.y
	if t < 0.0:
		return Vector3.INF
	return origin + dir * t
