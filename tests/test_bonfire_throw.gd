## Bonfire throw momentum: scripted grab-and-flick at 5 speeds, at 30 and
## 60 fps (game-frame flick clock), must give strictly increasing launch
## speed, travel (path length) and spin; faces stay seeded, dice stay on the
## felt and every reveal respects the cap.
##   godot --headless --path . --script res://tests/test_bonfire_throw.gd
extends SceneTree

## The lob is 720 px/s: just over min_throw_speed (700, the slowest flick
## that throws at all), so the softest throw has clear margin from the
## backboard (at 800 it sometimes grazed it once).
const SPEEDS: Array[float] = [720.0, 1500.0, 2300.0, 3200.0, 4200.0]

var _passed: int = 0
var _failed: int = 0
var _clock_t: float = 0.0


func _initialize() -> void:
	_run.call_deferred()


func check(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		print("FAIL  ", what)


func _run() -> void:
	var s := (load("res://scenes/bonfire.tscn") as PackedScene).instantiate() as Bonfire3D
	s.bonfire_seed = 11
	s.test_speed = 10.0
	root.add_child(s)
	await process_frame
	await process_frame
	s.run.hands_left = 1000
	# The curve itself.
	var prev := -1.0
	var mono := true
	for v in range(0, 5001, 100):
		var k := s.launch_k(float(v))
		mono = mono and k >= prev
		prev = k
	check(mono and s.launch_k(0.0) == 0.0 and s.launch_k(99999.0) == 1.0, "launch curve is monotonic, 0..1")
	for fps in [30.0, 60.0]:
		var launch: Array[float] = []
		var travel: Array[float] = []
		var spin: Array[float] = []
		var reach: Array[float] = []
		var walls: Array[int] = []
		for sp in SPEEDS:
			var faces: Array[int] = [2, 2, 3, 4, 6]
			s.rig_faces(faces)
			var threw := await _flick(s, fps, sp)
			check(threw, "%.0f px/s flick at %.0f fps throws" % [sp, fps])
			if not threw:
				return
			var rr: Array = await s.throw_resolved
			var rec := s.last_recording
			var L := s.last_launch
			var ls := 0.0
			var sn := 0.0
			for i in s.throw_dice.size():
				ls += Vector2(L["lin"][i].x, L["lin"][i].z).length() / 5.0
				sn += (L["spin"][i] as Vector3).length() / 5.0
			var path := 0.0
			var far := 0.0
			var bad := 0
			var lim := Table3DBuilder.FELT_HALF
			for i in rec.count():
				var fr := rec.frames[i] as Array
				for f in range(1, fr.size()):
					path += ((fr[f] as Transform3D).origin - (fr[f - 1] as Transform3D).origin).length() / 5.0
				var p := s.throw_dice[i].global_position
				far += Vector2(p.x - Table3D.HAND.x, p.z - Table3D.HAND.z).length() / 5.0
				if absf(p.x) > lim.x - 0.039 or absf(p.z) > lim.y - 0.039 or s.throw_dice[i].shown_value() != faces[i]:
					bad += 1
			check(bad == 0, "%.0f px/s at %.0f fps: faces seeded, dice on the felt (%d bad)" % [sp, fps, bad])
			check(rec.duration() + s.tuning.windup_time + s.tuning.settle_wobble_time <= s.tuning.reveal_cap + 0.001, "%.0f px/s at %.0f fps: reveal within cap" % [sp, fps])
			var w := 0
			for c: Dictionary in rec.contacts:
				if String(c["kind"]) == "backboard" and float(c["speed"]) > 0.5:
					w += 1
			walls.append(w)
			launch.append(ls)
			travel.append(path)
			spin.append(sn)
			reach.append(far)
			await s.sequence_finished
			if s.run.state == BonfireRun.State.PICK:
				for i in BonfireScoring.matching_subsets(s.run.throw_faces, s.bonfire_tuning)[0]:
					s.pick_die(i)
				await s.bank()
			await create_timer(0.1).timeout
		print("  %.0f fps  launch m/s %s  path m %s  spin rad/s %s  dist from hand m %s" % [fps, _fmt(launch), _fmt(travel), _fmt(spin), _fmt(reach)])
		check(_increasing(launch), "%.0f fps: launch speed strictly increases with flick speed" % fps)
		check(_increasing(travel), "%.0f fps: travel strictly increases with flick speed" % fps)
		check(_increasing(spin), "%.0f fps: spin strictly increases with flick speed" % fps)
		print("  %.0f fps  backboard hits per speed %s" % [fps, str(walls)])
		check(walls[0] == 0 and walls[-1] > 0, "%.0f fps: the lob never reaches the backboard, the hard throw slams it" % fps)
		check(reach[0] < 0.45, "%.0f fps: a gentle lob lands near the hand (%.2f m)" % [fps, reach[0]])
		check(launch[-1] > launch[0] * 3.0, "%.0f fps: hard throw launches >3x the lob" % fps)
	await _containment(s)
	await _slow_frames(s)
	s.queue_free()
	await process_frame
	print("test_bonfire_throw: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _fmt(a: Array[float]) -> String:
	return "[" + ", ".join(a.map(func(x: float) -> String: return "%.2f" % x)) + "]"


func _increasing(a: Array[float]) -> bool:
	for i in range(1, a.size()):
		if a[i] <= a[i - 1]:
			return false
	return true


## Grab, move steadily at `speed` px/s for 0.3 s at `fps`, release.
func _flick(s: Bonfire3D, fps: float, speed: float) -> bool:
	# Same start every time: the dice must be at rest in the hand (the hand
	# tween runs on the frame clock, so a busy box would otherwise release
	# them mid-flight from a different spot).
	while s.phase != Table3D.Phase.BET or s.hand_moving():
		await process_frame
	# ...and in the same orientation (each die otherwise keeps the pose the
	# previous throw's physics left it in, so one tiny difference cascades).
	for i in s.dice.size():
		s.dice[i].global_transform = Transform3D(Basis.IDENTITY, s.hand_spot(i))
	s.set_process(false)
	_clock_t = 0.0
	s.flick_clock = func() -> float: return _clock_t
	var hand := s.camera.cam.unproject_position(Table3D.HAND)
	var dir := Vector2(-0.55, -0.83).normalized()
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = hand
	s._unhandled_input(press)
	var t := 0.0
	var ev_t := 0.004
	while t < 0.3 - 0.0001:
		var dt := 1.0 / fps
		t += dt
		_clock_t = t
		s._process(dt)
		while ev_t <= t + 0.00001:
			var mm := InputEventMouseMotion.new()
			mm.position = hand + dir * speed * ev_t
			mm.button_mask = MOUSE_BUTTON_MASK_LEFT
			s._unhandled_input(mm)
			ev_t += 0.004
	var rel := InputEventMouseButton.new()
	rel.button_index = MOUSE_BUTTON_LEFT
	rel.pressed = false
	rel.position = hand + dir * speed * t
	s._unhandled_input(rel)
	s.flick_clock = Callable()
	s.set_process(true)
	await process_frame
	return s.phase != Table3D.Phase.BET and s.phase != Table3D.Phase.HELD


## Slow frames (4 fps, below the ~7.5 fps where Godot caps a frame's delta
## at max_physics_steps_per_frame steps) and a 0.4 s hitch: the flick is
## timed on the real clock, so it reads its true speed, not 2-3x faster.
func _slow_frames(s: Bonfire3D) -> void:
	for case in [[0.25, 0.0], [0.05, 0.4]]:
		var frame: float = case[0]
		var hitch: float = case[1]
		while s.phase != Table3D.Phase.BET or s.hand_moving():
			await process_frame
		s.set_process(false)
		var hand := s.camera.cam.unproject_position(Table3D.HAND)
		var dir := Vector2(-0.55, -0.83).normalized()
		var speed := 1500.0
		var press := InputEventMouseButton.new()
		press.button_index = MOUSE_BUTTON_LEFT
		press.pressed = true
		press.position = hand
		s._unhandled_input(press)
		var t0 := Time.get_ticks_usec()
		var steps := 0
		var cap := float(Engine.max_physics_steps_per_frame) / float(Engine.physics_ticks_per_second)
		var el := 0.0
		while el < 0.5:
			var real_dt := hitch if hitch > 0.0 and el >= 0.3 - 0.0001 else frame
			OS.delay_usec(int(real_dt * 1000000.0))
			el = (Time.get_ticks_usec() - t0) / 1000000.0
			s._process(minf(real_dt, cap))  # what the engine passes on a slow frame
			var mm := InputEventMouseMotion.new()
			mm.position = hand + dir * speed * el
			mm.button_mask = MOUSE_BUTTON_MASK_LEFT
			s._unhandled_input(mm)
			steps += 1
		var rel := InputEventMouseButton.new()
		rel.button_index = MOUSE_BUTTON_LEFT
		rel.pressed = false
		rel.position = hand + dir * speed * el
		s._unhandled_input(rel)
		s.set_process(true)
		await process_frame
		var read := float(s.last_launch.get("flick", 0.0))
		check(s.phase != Table3D.Phase.BET and absf(read - speed) < speed * 0.15,
			"%s: a %.0f px/s flick reads %.0f px/s (real clock; game delta capped at %.3f s)" % [("%.0f fps" % (1.0 / frame)) if hitch == 0.0 else ("%.1f s hitch" % hitch), speed, read, cap])
		await s.throw_resolved
		await s.sequence_finished
		if s.run.state == BonfireRun.State.PICK:
			for i in BonfireScoring.matching_subsets(s.run.throw_faces, s.bonfire_tuning)[0]:
				s.pick_die(i)
			await s.bank()
		await create_timer(0.1).timeout


## The hardest throws (at and far past the curve's cap) stay on the table:
## every recorded physics frame of every die is inside the felt walls and
## above the felt (no tunneling through the backboard, rails or felt).
func _containment(s: Bonfire3D) -> void:
	var lim := Table3DBuilder.FELT_HALF
	for sp in [6000.0, 9000.0, 14000.0]:
		for fps in [30.0, 60.0]:
			var faces: Array[int] = [1, 3, 4, 5, 6]
			s.rig_faces(faces)
			if not await _flick(s, fps, sp):
				check(false, "%.0f px/s flick throws" % sp)
				return
			await s.throw_resolved
			var rec := s.last_recording
			var out := 0
			var top := 0.0
			for i in rec.count():
				for tr: Transform3D in rec.frames[i]:
					var o := tr.origin
					top = maxf(top, o.y)
					if absf(o.x) > lim.x or absf(o.z) > lim.y or o.y < 0.0:
						out += 1
			var bad := 0
			for i in s.throw_dice.size():
				var p := s.throw_dice[i].global_position
				if absf(p.x) > lim.x - 0.039 or absf(p.z) > lim.y - 0.039 or s.throw_dice[i].shown_value() != faces[i]:
					bad += 1
			check(out == 0 and bad == 0, "%.0f px/s at %.0f fps (k %.2f, %.1f m/s): contained, no tunneling (%d frames out, %d bad rests, top %.2f m)" % [sp, fps, float(s.last_launch["k"]), float(s.last_launch["speed"]), out, bad, top])
			await s.sequence_finished
			if s.run.state == BonfireRun.State.PICK:
				for i in BonfireScoring.matching_subsets(s.run.throw_faces, s.bonfire_tuning)[0]:
					s.pick_die(i)
				await s.bank()
			await create_timer(0.1).timeout
