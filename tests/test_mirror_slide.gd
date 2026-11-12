## The HUD slide is visual-only. Mirror copies the nearest die from the
## positions where the dice settled, not from where the slide parked them.
##   godot --headless --path . --script res://tests/test_mirror_slide.gd
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
	var sv := SubViewport.new()
	sv.size = Vector2i(1920, 1080)
	root.add_child(sv)
	var t := load("res://resources/tuning/bonfire_tuning.tres") as BonfireTuning
	var st := TableSetup.sandbox(t, 3)
	st.dice[0].special = DiceIds.DIE_MIRROR
	var s := (load("res://scenes/bonfire.tscn") as PackedScene).instantiate() as Bonfire3D
	s.setup = st
	s.tutorial_override = 0
	sv.add_child(s)
	await process_frame
	await process_frame
	var mirror := s.all_dice[0]
	var size := s.tuning.die_size
	var y := size * 0.5
	var under := _ray(s.camera.cam, s.bhud.throw_button.get_global_rect().get_center(), y)
	check(_on_felt(under, size), "the Throw button covers a felt point %s" % under)
	var laid := _layout(s, mirror, under, size)
	check(not laid.is_empty(), "a layout where the slide changes the Mirror's neighbour")
	if laid.is_empty():
		print("test_mirror_slide: %d passed, %d failed" % [_passed, _failed])
		quit(1)
		return
	var a_pos: Vector3 = laid["near"]
	var b_pos: Vector3 = laid["far"]
	var dest: Vector3 = laid["dest"]
	s.all_dice[1].global_position = a_pos
	s.all_dice[2].global_position = b_pos
	mirror.global_position = under
	var values: Array[int] = [1, 4, 6]
	var pre := _copied(s, [under, a_pos, b_pos], values)
	var post := _copied(s, [dest, a_pos, b_pos], values)
	check(pre == 4 and post == 6, "without the snapshot the slide would copy %d instead of %d" % [post, pre])
	s.throw_dice = s.all_dice.duplicate()
	s.throw_slots = [1, 4, 6]
	HudRestClear.apply(s)
	check(s.rules_pose[0].is_equal_approx(under), "rules_pose keeps the pre-slide settle point")
	check(s._land_settled(values, [null, null, null]), "the copied pair lights")
	check(s.run.throw_faces[0] == 4, "Mirror copies the pre-slide neighbour (got %s)" % str(s.run.throw_faces))
	print("test_mirror_slide: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


## What a fresh Mirror would copy with these positions (does not touch the run).
func _copied(s: Bonfire3D, positions: Array, values: Array[int]) -> int:
	var dice: Array = [s._td(0), s._td(1), s._td(2)]
	var th := TableThrow.make(values, [], dice, s.run.rng)
	var posed: Array[Vector3] = []
	for p: Vector3 in positions:
		posed.append(p)
	th.positions = posed
	DieMirror.new().on_throw_landed(s.run, th)
	return th.values[0]


## near = the pre-slide neighbour (value 4), far = the post-slide one (value 6).
## dest = where the mirror actually stops with both of them down.
func _layout(s: Bonfire3D, mirror: DieVisual, under: Vector3, size: float) -> Dictionary:
	var cam := s.camera.cam
	var blockers := HudRestClear.blockers(s)
	var near_die := s.all_dice[1]
	var far_die := s.all_dice[2]
	far_die.global_position = Vector3(0.0, size * 0.5, -2.0)
	mirror.global_position = under
	var solo: Array[DieVisual] = [mirror]
	HudRestClear.clear(cam, solo, blockers, size)
	var slide := mirror.global_position - under
	slide.y = 0.0
	mirror.global_position = under
	if slide.length() < size * 2.0:
		return {}
	var near := _clear_spot(s, near_die, under, size, slide.length() * 0.85)
	if near == Vector3.INF:
		return {}
	var far := _far_spot(s, under, near, slide, size)
	if far == Vector3.INF:
		return {}
	near_die.global_position = near
	far_die.global_position = far
	mirror.global_position = under
	var trio: Array[DieVisual] = [mirror, near_die, far_die]
	HudRestClear.clear(cam, trio, blockers, size)
	var dest := mirror.global_position
	if under.distance_to(near) < under.distance_to(far) and dest.distance_to(far) < dest.distance_to(near):
		return {"near": near, "far": far, "dest": dest}
	return {}


## Closest felt point to [param under] whose die is off the buttons, within [param max_d].
func _clear_spot(s: Bonfire3D, die: DieVisual, under: Vector3, size: float, max_d: float) -> Vector3:
	var best := Vector3.INF
	var best_d := max_d
	for ang in 24:
		var dir := Vector3(cos(float(ang) * TAU / 24.0), 0.0, sin(float(ang) * TAU / 24.0))
		for step in range(3, 16):
			var q := under + dir * size * float(step) * 0.25
			q.y = under.y
			var d := q.distance_to(under)
			if d >= best_d or not _on_felt(q, size):
				continue
			die.global_position = q
			if _under_button(s, die):
				continue
			best = q
			best_d = d
	return best


## A felt spot beside the slide's end, off the buttons, closer to the end than [param near] is.
func _far_spot(s: Bonfire3D, under: Vector3, near: Vector3, slide: Vector3, size: float) -> Vector3:
	var end := under + slide
	var side := Vector3(-slide.z, 0.0, slide.x).normalized()
	var die := s.all_dice[2]
	for sign: float in [1.0, -1.0]:
		var far := end + side * sign * size * 1.4
		far.y = under.y
		if not _on_felt(far, size):
			continue
		die.global_position = far
		if _under_button(s, die):
			continue
		if under.distance_to(near) < under.distance_to(far) and end.distance_to(far) < end.distance_to(near):
			return far
	return Vector3.INF


func _under_button(s: Bonfire3D, die: DieVisual) -> bool:
	var box := RulesPlaqueDodge.die_rect(s.camera.cam, die)
	return box.intersects(s.bhud.throw_button.get_global_rect()) or box.intersects(s.bhud.bank_button.get_global_rect())


func _on_felt(p: Vector3, die: float) -> bool:
	var lim := Table3DBuilder.FELT_HALF - Vector2.ONE * die * 0.5
	return absf(p.x) <= lim.x and absf(p.z) <= lim.y


func _ray(cam: Camera3D, screen: Vector2, y: float) -> Vector3:
	var origin := cam.project_ray_origin(screen)
	var dir := cam.project_ray_normal(screen)
	var t := (y - origin.y) / dir.y
	return origin + dir * t
