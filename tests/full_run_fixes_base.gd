## Shared helpers for the QA full run pass 1 tests (not a test itself:
## test_bonfire_full_run_fixes.gd and test_bonfire_full_run_fixes_2.gd extend it).
extends SceneTree

var _passed: int = 0
var _failed: int = 0
## The fake flick clock (seconds) the gestures run on.
var _clock_t: float = 0.0


func check(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		print("FAIL  ", what)


# --- M1 -----------------------------------------------------------------------------

## A sandbox table inside a SubViewport of the given canvas size (what the
## window stretches to at that aspect), framed like that screen.
func _table_in(canvas: Vector2i, screen: Vector2) -> Array:
	var sv := SubViewport.new()
	sv.size = canvas
	root.add_child(sv)
	var t := load("res://resources/tuning/bonfire_tuning.tres") as BonfireTuning
	var s := (load("res://scenes/bonfire.tscn") as PackedScene).instantiate() as Bonfire3D
	s.setup = TableSetup.sandbox(t, 5)
	s.tutorial_override = 0
	s.test_speed = 10.0
	sv.add_child(s)
	await process_frame
	await process_frame
	s.camera.cam.current = true
	if screen != Vector2(canvas):
		s.fit_phone(screen)
	s.camera.snap_home()
	return [sv, s]


func _wait_in_hand(s: Bonfire3D) -> void:
	for k in 600:
		if s.phase == Table3D.Phase.BET and not s.hand_moving():
			return
		await process_frame


func _click_event(p: Vector2, down: bool) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = down
	e.position = p
	e.global_position = p
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	return e


## Real input through the viewport (so the GUI gets its chance first):
## press at p, drag up-left at `speed` px/s for 0.2 s, release.
func _flick_from(sv: SubViewport, s: Bonfire3D, p: Vector2, speed: float) -> void:
	_clock_t = 0.0
	s.flick_clock = func() -> float: return _clock_t
	var dir := Vector2(-0.55, -0.83).normalized()
	sv.push_input(_click_event(p, true), true)
	var t := 0.0
	while t < 0.2:
		t += 0.008
		_clock_t = t
		var mm := InputEventMouseMotion.new()
		mm.position = p + dir * speed * t
		mm.global_position = mm.position
		mm.button_mask = MOUSE_BUTTON_MASK_LEFT
		sv.push_input(mm, true)
	sv.push_input(_click_event(p + dir * speed * t, false), true)
	s.flick_clock = Callable()


## Flick from p; it must start a flick throw (launch speed from the drag,
## not the canned quick throw) and press no button. Then a fresh hand.
func _flick_and_check(sv: SubViewport, s: Bonfire3D, p: Vector2, presses: Array, what: String) -> void:
	var before: int = presses[0]
	s.last_launch = {}
	await _flick_from(sv, s, p, 4000.0)
	var thrown := s.phase != Table3D.Phase.BET and s.phase != Table3D.Phase.HELD
	var flick := float(s.last_launch.get("flick", 0.0))
	var want := 4000.0 * s.sensitivity()
	check(thrown and presses[0] == before, "%s: press-drag-release throws (phase %d) and presses no button (%d presses)" % [what, s.phase, presses[0] - before])
	check(absf(flick - want) < want * 0.15, "%s: it's the flick (%.0f px/s, want ~%.0f), not a quick throw" % [what, flick, want])
	if thrown:
		await s.sequence_finished
	s.new_run(11)


# --- M2 -----------------------------------------------------------------------------

## GameSettings with a throwaway file, tutorial on and not seen yet.
func _fresh_settings() -> Dictionary:
	var gs := root.get_node_or_null("GameSettings")
	if gs == null:
		return {}
	var old := {"path": gs.path, "enabled": gs.tutorial_enabled, "seen": gs.tutorial_seen}
	gs.path = "user://test_full_run_fixes_settings.cfg"
	gs.tutorial_enabled = true
	gs.tutorial_seen = false
	return old


func _restore_settings(old: Dictionary) -> void:
	var gs := root.get_node_or_null("GameSettings")
	if gs == null or old.is_empty():
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(gs.path))
	gs.path = old["path"]
	gs.tutorial_enabled = old["enabled"]
	gs.tutorial_seen = old["seen"]


# --- M4 -----------------------------------------------------------------------------

## tutorial: Bonfire3D.tutorial_override (0 = off, 1 = on).
func _one_hand_table(goal_required: int, tutorial: int = 0) -> Bonfire3D:
	var t := load("res://resources/tuning/bonfire_tuning.tres") as BonfireTuning
	var setup := TableSetup.sandbox(t, 5)
	var goal := t.table_goal.duplicate() as TableGoal
	goal.hands = 1
	goal.bonus = []
	goal.required = goal.required.slice(0, goal_required)
	setup.goal = goal
	var s := (load("res://scenes/bonfire.tscn") as PackedScene).instantiate() as Bonfire3D
	s.setup = setup
	s.tutorial_override = tutorial
	s.test_speed = 10.0
	root.add_child(s)
	return s


# --- #103 F1 ------------------------------------------------------------------------

## Lays the button column so `button`'s centre sits on screen point p.
func _button_over(s: Bonfire3D, button: Button, p: Vector2) -> void:
	var col := button.get_parent() as Control
	col.position += p - button.get_global_rect().get_center()


func _click(sv: SubViewport, p: Vector2) -> void:
	sv.push_input(_click_event(p, true), true)
	sv.push_input(_click_event(p, false), true)


func _idle(s: Bonfire3D) -> void:
	for k in 600:
		if s.phase == Table3D.Phase.BET and not s.bhud.countup.is_playing():
			break
		await process_frame
	for k in 12:
		await process_frame
