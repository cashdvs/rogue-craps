## Headless tests for the 3D table (scenes/table_3d.tscn). Physics runs
## headless, so these throw REAL RigidBody3D dice:
##   - face math: every (physical face, wanted face) remap puts the wanted face up
##   - many varied/seeded flicks: the settled up-faces always equal the
##     DiceRoller's result, the dice rest flat and on the felt
##   - timing (design doc 5b): median settle <= tuning.settle_target and the
##     reveal always done by tuning.reveal_cap; reports how often the
##     settle assist fired
##   - weak throws don't roll; a strong throw uses a roll
##   - 1x / 2x / Instant speed toggle; audio signals (impact, settled)
##   - wins never restore Soul (also on the 3D table)
##   - dice render >= tuning.min_die_px on phone-sized viewports
##
## Run:
##   godot --headless --path /workspace/dice/game --script res://tests/test_table_3d.gd
extends SceneTree

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
	_test_face_math()
	_test_mesh()
	var scene := _make_scene()
	root.add_child(scene)
	await process_frame
	await _test_weak_and_strong(scene)
	await _test_flick_clock(scene)
	await _test_faces_and_bounds(scene)
	await _test_audio_hooks(scene)
	await _test_sfx_hooks(scene)
	_test_flat_separation(scene)
	await _test_timing_stats(scene)
	await _test_real_time_reveal(scene)
	await _test_speed_modes(scene)
	await _test_no_soul_restore(scene)
	await _test_running_total(scene, 1)
	await _test_running_total(scene, 3)
	await _test_back_to_craps(scene)
	scene.queue_free()
	await process_frame
	await _test_die_size()
	print("test_table_3d: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _make_scene() -> Table3D:
	var s := (load("res://scenes/table_3d.tscn") as PackedScene).instantiate() as Table3D
	s.rng_seed = 42
	# A roomy copy of the shipped tuning so the table never ends mid-test.
	var t := (load("res://resources/tuning/poc_tuning.tres") as TuningData).duplicate() as TuningData
	t.roll_limit = 100000
	t.target_bankroll = 1000000
	s.tuning = t
	return s


## Stand-ins for the Sound Designer's SfxManager hooks (not on this branch
## yet): play_throw(flick_speed_px_s) -> float and play_impact(kind,
## speed_mps, material = &"bone", die_id = -1) -> bool. Both log their calls;
## play() logs the fallback events so we can see which path ran.
const SFX_STUB_SRC := """extends SfxManager
var calls: Array = []
func play(event: StringName, _pitch: float = 1.0, _volume_db: float = 0.0, _jitter: float = 0.06) -> void:
	calls.append([&"play", event])
func play_throw(flick_speed_px_s: float) -> float:
	calls.append([&"throw", flick_speed_px_s])
	return 0.5
func play_impact(kind: StringName, speed_mps: float, material: StringName = &"bone", die_id: int = -1) -> bool:
	calls.append([&"impact", kind, speed_mps, material, die_id])
	return true
"""


func _sfx_stub(src: String) -> Node:
	var gd := GDScript.new()
	gd.source_code = src
	gd.reload()
	var n: Node = gd.new()
	return n


func _test_sfx_hooks(s: Table3D) -> void:
	# The throw / impact sounds belong to the feel layer (scripts/fx/,
	# TableAudio): the table only emits events.dice_thrown / die_impact and
	# never calls the SfxManager hooks or the old fallbacks itself.
	var real_sfx := s.sfx
	var stub := _sfx_stub(SFX_STUB_SRC)
	s.add_child(stub)
	s.sfx = stub
	var fx := s.get_node_or_null("TableAudio")
	if fx != null and fx.has_method("unbind"):
		fx.call("unbind")
	var thrown_ev: Array = []
	var impact_ev: Array = []
	var on_thrown := func(v: float) -> void: thrown_ev.append(v)
	var on_impact := func(k: StringName, v: float, m: StringName, id: int) -> void: impact_ev.append([k, v, m, id])
	s.events.dice_thrown.connect(on_thrown)
	s.events.die_impact.connect(on_impact)
	_bet(s)
	s.throw(Table3D.QUICK_THROW)
	await s.sequence_finished
	check(thrown_ev.size() == 1 and is_equal_approx(float(thrown_ev[0]), Table3D.QUICK_THROW.length()), "events.dice_thrown gets the flick speed %.0f px/s once (%s)" % [Table3D.QUICK_THROW.length(), str(thrown_ev)])
	check(not stub.calls.any(func(e: Array) -> bool: return e[0] == &"throw" or e[0] == &"impact" or e == [&"play", &"dice_shake"]),
		"the table plays no throw / impact sound itself (%s)" % str(stub.calls))
	check(impact_ev.size() >= 1, "a real throw emits die_impact (%d)" % impact_ev.size())
	var floor_ok := true
	for e: Array in impact_ev:
		if float(e[1]) < s.tuning.impact_min_speed or int(e[3]) < 0 or int(e[3]) >= s.dice.size() or not (e[0] is StringName) or not (e[2] is StringName):
			floor_ok = false
	check(floor_ok, "die_impact args: kind/material StringName, speed >= floor, valid die_id")
	# Contacts: die_id passes through; the 0.3 m/s floor and 0.05 s filter hold.
	impact_ev.clear()
	stub.calls.clear()
	s._last_impact.fill(-1.0)
	s._play_t = 0.0
	s._on_contact({"t": 0.0, "die": 1, "kind": &"rail", "speed": s.tuning.impact_min_speed - 0.05, "impulse": 0.001, "other": -1})
	check(impact_ev.is_empty(), "under-floor contact: no die_impact")
	s._play_t = 1.0
	s._on_contact({"t": 1.0, "die": 1, "kind": &"rail", "speed": 2.5, "impulse": 0.01, "other": -1})
	s._play_t = 1.01
	s._on_contact({"t": 1.01, "die": 1, "kind": &"felt", "speed": 2.0, "impulse": 0.01, "other": -1})
	check(impact_ev.size() == 1 and impact_ev[0][0] == &"rail" and is_equal_approx(float(impact_ev[0][1]), 2.5) and impact_ev[0][2] == StringName(s.dice[1].material) and int(impact_ev[0][3]) == s.event_id(s.dice[1]),
		"die_impact(&\"rail\", 2.5, material, die 1), throttled after (%s)" % str(impact_ev))
	check(stub.calls.is_empty(), "contacts play no sound on the table (%s)" % str(stub.calls))
	s._play_t = -1.0
	s.events.dice_thrown.disconnect(on_thrown)
	s.events.die_impact.disconnect(on_impact)
	s.sfx = real_sfx
	# Stale/speculative contacts: a die that rested elsewhere and is thrown
	# from the hand must not log a phantom hit at release (the previous rest
	# spot's felt contact, with a nonsense speed of 20-50 m/s).
	var rest_at: Array[Transform3D] = [Transform3D(Basis.IDENTITY, Vector3(-0.6, 0.041, -0.2)), Transform3D(Basis.IDENTITY, Vector3(-0.3, 0.041, 0.1))]
	var zero: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
	await s.sim.simulate(rest_at, zero, zero, 7)
	var tilt := Basis.from_euler(Vector3(0.5, 0.3, 0.7))
	var from: Array[Transform3D] = [Transform3D(tilt, Vector3(0.75, 0.06, 0.3)), Transform3D(tilt, Vector3(0.9, 0.06, 0.3))]
	var lin2: Array[Vector3] = [Vector3(-3.0, 1.0, -3.0), Vector3(-3.0, 1.0, -3.0)]
	var ang2: Array[Vector3] = [Vector3(25.0, 0.0, 15.0), Vector3(-20.0, 10.0, 0.0)]
	var rec2: ThrowRecording = await s.sim.simulate(from, lin2, ang2, 7)
	var cap := lin2[0].length() + 30.0 * s.tuning.die_size + 0.5
	var worst := 0.0
	var at_release := 0
	for c: Dictionary in rec2.contacts:
		worst = maxf(worst, float(c["speed"]))
		if float(c["t"]) <= 0.0:
			at_release += 1
	check(at_release == 0, "no contact logged on the release tick (%d)" % at_release)
	check(worst <= cap, "contact speeds stay physical: max %.2f m/s <= %.2f" % [worst, cap])
	stub.queue_free()
	await process_frame


## Flattening at the end of a throw (settle assist / timeout) puts every die
## on the felt: a die resting on top of another must be moved beside it, not
## dropped inside it (seen on hard 5-die bonfire throws near the backboard).
func _test_flat_separation(s: Table3D) -> void:
	var ds := s.tuning.die_size
	var lim := Table3DBuilder.FELT_HALF - Vector2.ONE * ds * 0.75
	var cases := [
		[Vector3(0.70, ds * 0.5, -0.37), Vector3(0.70, ds * 1.5, -0.37)],  # stacked
		[Vector3(0.70, ds * 0.5, -0.37), Vector3(0.71, ds * 0.5, -0.37)],  # side by side, overlapping
		[Vector3(lim.x, ds * 0.5, -lim.y), Vector3(lim.x, ds * 1.5, -lim.y)],  # stacked in the corner
	]
	for c: Array in cases:
		var froms: Array[Transform3D] = []
		var targets: Array[Transform3D] = []
		for p: Vector3 in c:
			froms.append(Transform3D(Basis.IDENTITY, p))
			targets.append(s.sim._flat(Transform3D(Basis.IDENTITY, p)))
		var bottom_before := targets[0].origin
		s.sim._separate(targets, froms)
		var d := Vector2(targets[0].origin.x - targets[1].origin.x, targets[0].origin.z - targets[1].origin.z).length()
		var inside := true
		for tr in targets:
			inside = inside and absf(tr.origin.x) <= lim.x + 0.0001 and absf(tr.origin.z) <= lim.y + 0.0001
		check(d >= ds * 0.95 and inside, "flattened dice from %s end apart (%.3f m >= %.3f) inside the rails" % [str(c), d, ds * 0.95])
		if c[1].y > c[0].y + ds * 0.5 and absf(c[0].x) < lim.x - ds:
			check(targets[0].origin.is_equal_approx(bottom_before), "the bottom die stays put; the stacked one moves")


# --- Pure face math ---------------------------------------------------------------

func _test_face_math() -> void:
	var bad := 0
	for phys in range(1, 7):
		for want in range(1, 7):
			for q in 4:
				# A body resting with face `phys` on top, any yaw.
				var a_phys := DieVisual.FACE_AXES[phys] as Vector3
				var body := Basis(Quaternion(a_phys, Vector3.UP)) if not a_phys.is_equal_approx(Vector3.DOWN) else Basis(Vector3.RIGHT, PI)
				body = Basis(Vector3.UP, 0.7 * q) * body
				check(DieVisual.value_up(body) == phys, "body basis has %d up" % phys)
				var m := DieVisual.remap_basis(phys, want, q * PI * 0.5 + 0.1)
				if DieVisual.value_up(body * m) != want:
					bad += 1
	check(bad == 0, "remap puts the wanted face up for all 6x6x4 cases (%d bad)" % bad)
	# Opposite faces sum to 7.
	for v: int in DieVisual.FACE_AXES:
		check((DieVisual.FACE_AXES[v] as Vector3).is_equal_approx(-(DieVisual.FACE_AXES[7 - v] as Vector3)), "face %d opposite %d" % [v, 7 - v])


func _test_mesh() -> void:
	var mesh := DieVisual.rounded_cube(0.08, 0.0128)
	var arr := mesh.surface_get_arrays(0)
	var verts := arr[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var normals := arr[Mesh.ARRAY_NORMAL] as PackedVector3Array
	check(verts.size() > 100, "rounded cube has vertices (%d)" % verts.size())
	var ok := true
	for i in verts.size():
		if absf(normals[i].length() - 1.0) > 0.01 or absf(verts[i].x) > 0.0401 or absf(verts[i].y) > 0.0401:
			ok = false
	check(ok, "rounded cube: unit normals, fits the 0.08 m box")


# --- Throws through the scene ------------------------------------------------------

func _bet(s: Table3D) -> void:
	if not s.poc.table.craps.has_point() and s.poc.table.stake_on(&"pass") < s.tuning.min_bet:
		if s.poc.bankroll.coin < 10:
			s.poc.bankroll.add(100)
		s.place()


func _test_weak_and_strong(s: Table3D) -> void:
	s.test_speed = 8.0
	check(s.throw(Table3D.QUICK_THROW) == false, "no bet: throw refused")
	check(s.poc.rolls_used == 0, "no bet: no roll used")
	_bet(s)
	var drops: Array[int] = [0]
	s.dropped_back.connect(func() -> void: drops[0] += 1)
	check(s.throw(Vector2.ZERO, Vector2.INF, 0.0) == false, "click-release (no motion) does not throw")
	check(s.throw(Vector2(-300, -200)) == false, "slow flick does not throw")
	check(s.throw(Vector2(-3000, -2000), Vector2.INF, 5.0) == false, "fast but tiny drag does not throw")
	check(drops[0] == 3 and s.poc.rolls_used == 0, "weak throws drop back to the hand, no roll used (%d drops)" % drops[0])
	check(s.phase == Table3D.Phase.BET, "after a weak throw you can grab again")
	s.rig_next_roll(2, 3)
	check(s.throw(Table3D.QUICK_THROW) == true, "strong flick throws")
	check(s.phase == Table3D.Phase.ROLL, "strong flick starts the roll")
	await s.sequence_finished
	check(s.poc.rolls_used == 1, "strong throw used one roll")


## Flick timing through the real input path and Table3D's game clock
## (QA on PR #13): frames are stepped by hand at a given fps and
## Engine.time_scale, mouse events arrive in per-frame batches. A strong
## flick must throw with a speed within 15% of the truth; a slow drag drops.
func _test_flick_clock(s: Table3D) -> void:
	s.test_speed = 10.0
	var cases: Array[Vector3] = []  # fps, time_scale, release hitch (s)
	for fps in [10.0, 20.0, 60.0, 144.0]:
		for ts in [0.05, 0.5, 1.0, 2.0]:
			cases.append(Vector3(fps, ts, 0.0))
	cases.append(Vector3(60.0, 1.0, 0.12))
	cases.append(Vector3(30.0, 0.05, 0.09))
	var speeds: Array[float] = []
	var cb := func(v: float) -> void: speeds.append(v)
	s.thrown.connect(cb)
	var drops: Array[int] = [0]
	var cb_drop := func() -> void: drops[0] += 1
	s.dropped_back.connect(cb_drop)
	for c in cases:
		_bet(s)
		speeds.clear()
		var threw := await _scripted_flick(s, c.x, c.y, c.z, 1800.0)
		var got := speeds[0] if not speeds.is_empty() else 0.0
		var err := absf(got - 1800.0) / 1800.0
		check(threw and err <= 0.15, "1800 px/s flick at %.0f fps, time scale %.2f, %.0f ms hitch: throws, read %.0f px/s" % [c.x, c.y, c.z * 1000.0, got])
		if threw:
			await s.sequence_finished
	for ts in [0.05, 1.0, 2.0]:
		_bet(s)
		var before := drops[0]
		var threw := await _scripted_flick(s, 20.0, ts, 0.0, 250.0)
		check(not threw and drops[0] == before + 1, "slow drag at 20 fps, time scale %.2f drops back" % ts)
	s.thrown.disconnect(cb)
	s.dropped_back.disconnect(cb_drop)


## Grabs the dice, moves the mouse steadily at `speed` px/s for 0.3 s and
## releases, stepping Table3D._process by hand. Returns true if it threw.
func _scripted_flick(s: Table3D, fps: float, ts: float, hitch: float, speed: float) -> bool:
	s.set_process(false)
	# The flick clock is real (wall) time; here the script's own real_t.
	_clock_t = 0.0
	s.flick_clock = func() -> float: return _clock_t
	Engine.time_scale = ts
	var hand := s.camera.cam.unproject_position(Table3D.HAND)
	var dir := Vector2(-0.55, -0.83).normalized()
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = hand
	s._unhandled_input(press)
	var real_t := 0.0
	var ev_t := 0.004
	var flick := 0.3
	while real_t < flick - 0.0001:
		var dt := 1.0 / fps
		if hitch > 0.0 and real_t + dt >= flick - hitch:
			dt = flick - real_t  # the release frame is one long hitch
		real_t += dt
		_clock_t = real_t
		s._process(dt * ts)  # the engine passes scaled delta
		while ev_t <= real_t + 0.00001:
			var mm := InputEventMouseMotion.new()
			mm.position = hand + dir * speed * ev_t
			mm.button_mask = MOUSE_BUTTON_MASK_LEFT
			s._unhandled_input(mm)
			ev_t += 0.004
	Engine.time_scale = 1.0
	var rel := InputEventMouseButton.new()
	rel.button_index = MOUSE_BUTTON_LEFT
	rel.pressed = false
	rel.position = hand + dir * speed * real_t
	s._unhandled_input(rel)
	s.flick_clock = Callable()
	s.set_process(true)
	await process_frame
	return s.phase != Table3D.Phase.BET and s.phase != Table3D.Phase.HELD


func _test_faces_and_bounds(s: Table3D) -> void:
	s.test_speed = 10.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	var impacts: Array[Dictionary] = []
	var settles: Array[Vector2i] = []
	for d in s.dice:
		d.impact.connect(func(id: int, surface: String, speed: float, impulse: float, other: int, mat: String) -> void:
			impacts.append({"id": id, "surface": surface, "speed": speed, "impulse": impulse, "other": other, "material": mat}))
		d.settled.connect(func(id: int, face: int) -> void: settles.append(Vector2i(id, face)))
	var mismatches := 0
	var off_table := 0
	var not_flat := 0
	var n := 24
	for k in n:
		_bet(s)
		if k % 2 == 0:
			s.rig_next_roll(rng.randi_range(1, 6), rng.randi_range(1, 6))
		var v := Vector2.from_angle(rng.randf_range(-PI * 0.9, -PI * 0.3)) * rng.randf_range(s.tuning.min_throw_speed * 1.05, s.tuning.max_throw_speed)
		var hand := s.camera.cam.unproject_position(Table3D.HAND)
		impacts.clear()
		settles.clear()
		check(s.throw(v, hand + Vector2(rng.randf_range(-40, 40), rng.randf_range(-30, 30))), "throw %d starts" % k)
		var landed: Array = await s.dice_landed
		for i in 2:
			var d := s.dice[i]
			if d.up_value() != int(landed[i]) or d.up_value() != s.last_values[i]:
				mismatches += 1
				print("  throw %d die %d: up %d wanted %d" % [k, i, d.up_value(), s.last_values[i]])
			if d.up_dot() < 0.999:
				not_flat += 1
			var p := d.global_position
			var lim := Table3DBuilder.FELT_HALF
			if absf(p.x) > lim.x - 0.039 or absf(p.z) > lim.y - 0.039 or absf(p.y - s.tuning.die_size * 0.5) > 0.002:
				off_table += 1
				print("  throw %d die %d off the felt at %s" % [k, i, p])
		check(impacts.size() >= 1, "throw %d: dice emitted impact signals (%d)" % [k, impacts.size()])
		var surfaces_ok := true
		for imp in impacts:
			if not (imp["surface"] in ["felt", "rail", "backboard", "die", "chip", "puck"]) or float(imp["speed"]) < s.tuning.impact_min_speed or float(imp["impulse"]) < 0.0 or imp["material"] != "bone":
				surfaces_ok = false
			if imp["surface"] == "die" and (int(imp["id"]) != 0 or int(imp["other"]) != 1):
				surfaces_ok = false
			if imp["surface"] != "die" and int(imp["other"]) != -1:
				surfaces_ok = false
		check(surfaces_ok, "throw %d: impact surface/speed/impulse valid" % k)
		check(settles.size() == 2 and settles[0].y == s.last_values[settles[0].x] and settles[1].y == s.last_values[settles[1].x], "throw %d: settled(die, face) reports the seeded faces" % k)
		await s.sequence_finished
	check(mismatches == 0, "up-faces match the DiceRoller result on all %d throws (%d mismatches)" % [n, mismatches])
	check(not_flat == 0, "dice rest flat (%d tilted)" % not_flat)
	check(off_table == 0, "dice stay on the felt (%d off)" % off_table)


## Running-total mode (Burn Line groundwork): N dice per throw (1 and 3)
## with the same flick, physics and seeded-face guarantees; the total, HUD
## and Stop placeholder follow.
func _test_running_total(s: Table3D, per_throw: int) -> void:
	s.test_speed = 10.0
	s.set_speed_mode(0)
	s.set_mode(Table3D.Mode.RUNNING_TOTAL, per_throw)
	await process_frame
	check(s.dice.size() == per_throw and s.dice_per_throw() == per_throw, "%d-die mode: %d visible dice" % [per_throw, per_throw])
	check(s.total_hud.visible and s.total_hud.stop_button.disabled, "%d-die mode: total HUD shown, Stop disabled at 0" % per_throw)
	check(s.can_throw() == "", "%d-die mode: no Pass Line bet needed to throw" % per_throw)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77 + per_throw
	var mismatches := 0
	var bad_pose := 0
	var slow := 0
	var expected := 0
	var throws := 8
	for k in throws:
		if k % 2 == 0:
			var rig: Array[int] = []
			for i in per_throw:
				rig.append(rng.randi_range(1, 6))
			s.rig_next_values(rig)
		var v := Vector2.from_angle(rng.randf_range(-PI * 0.9, -PI * 0.3)) * rng.randf_range(s.tuning.min_throw_speed * 1.05, s.tuning.max_throw_speed)
		var hand := s.camera.cam.unproject_position(Table3D.HAND)
		check(s.throw(v, hand + Vector2(rng.randf_range(-30, 30), rng.randf_range(-20, 20))), "%d-die throw %d starts" % [per_throw, k])
		var landed: Array = await s.dice_landed
		check(landed.size() == per_throw and s.last_recording.count() == per_throw, "%d-die throw %d: %d values and simulated bodies" % [per_throw, k, per_throw])
		for i in per_throw:
			var d := s.dice[i]
			if d.up_value() != int(landed[i]):
				mismatches += 1
			var p := d.global_position
			var lim := Table3DBuilder.FELT_HALF
			if d.up_dot() < 0.999 or absf(p.x) > lim.x - 0.039 or absf(p.z) > lim.y - 0.039:
				bad_pose += 1
			expected += int(landed[i])
		if s.last_recording.duration() + s.tuning.windup_time + s.tuning.settle_wobble_time > s.tuning.reveal_cap + 0.001:
			slow += 1
		await s.sequence_finished
		check(s.running_total.total == expected and s.running_total.count() == (k + 1) * per_throw, "%d-die throw %d: running total %d" % [per_throw, k, expected])
	check(mismatches == 0, "%d-die mode: up-faces match the seeded values (%d mismatches)" % [per_throw, mismatches])
	check(bad_pose == 0, "%d-die mode: dice rest flat on the felt (%d bad)" % [per_throw, bad_pose])
	check(slow == 0, "%d-die mode: every reveal within reveal_cap (%d slow)" % [per_throw, slow])
	await create_timer(0.6).timeout  # let the count-up finish
	check(s.total_hud.total_label.text == str(expected), "%d-die mode: HUD counts up to the total (%s)" % [per_throw, s.total_hud.total_label.text])
	await process_frame
	check(s.total_hud.list_box.get_child_count() == throws * per_throw, "%d-die mode: HUD lists every die thrown" % per_throw)
	check(not s.total_hud.stop_button.disabled, "%d-die mode: Stop enabled once something is thrown" % per_throw)
	var stopped: Array[int] = []
	var cb := func(t: int) -> void: stopped.append(t)
	s.total_stopped.connect(cb)
	s.total_hud.stop_button.pressed.emit()
	s.total_stopped.disconnect(cb)
	check(stopped == [expected] and s.running_total.total == 0, "%d-die mode: Stop banks %d and starts a new total" % [per_throw, expected])
	check(s.stop_total() == -1, "%d-die mode: Stop with nothing thrown does nothing" % per_throw)


## Switching back keeps the craps flow intact (2 dice, Pass Line).
func _test_back_to_craps(s: Table3D) -> void:
	s.set_mode(Table3D.Mode.CRAPS)
	await process_frame
	check(s.dice.size() == 2 and not s.total_hud.visible, "back to craps: 2 dice, total HUD hidden")
	_bet(s)
	s.rig_next_roll(2, 5)
	check(s.quick_throw(), "back to craps: a Pass Line throw starts")
	var report: PocRollReport = await s.outcome_shown
	check(report.table_report.roll.total == 7 and s.dice[0].up_value() == 2 and s.dice[1].up_value() == 5, "back to craps: seeded 2-5 rolls a 7")
	await s.sequence_finished


## Sound Designer hooks: die-die once per pair (lower id, other_id set),
## silent under the 0.3 m/s floor, rest / tumble_ending / thrown fire.
func _test_audio_hooks(s: Table3D) -> void:
	# Raw recording: die 0 slides into a resting die 1.
	var starts: Array[Transform3D] = [Transform3D(Basis.IDENTITY, Vector3(-0.17, 0.041, 0.0)), Transform3D(Basis.IDENTITY, Vector3(0.0, 0.041, 0.0))]
	var lin: Array[Vector3] = [Vector3(3.0, 0.0, 0.0), Vector3.ZERO]
	var ang: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
	var rec: ThrowRecording = await s.sim.simulate(starts, lin, ang, 5)
	var die_hits := rec.contacts.filter(func(c: Dictionary) -> bool: return c["kind"] == &"die")
	check(die_hits.size() >= 1, "die-die collision recorded (%d)" % die_hits.size())
	var pair_ok := true
	for c: Dictionary in die_hits:
		if int(c["die"]) != 0 or int(c["other"]) != 1:
			pair_ok = false
	check(pair_ok, "die-die recorded once per pair, by die 0, other_id 1")
	var first: Dictionary = die_hits[0] if die_hits.size() > 0 else {}
	check(not first.is_empty() and float(first["speed"]) > 1.0 and float(first["speed"]) < 3.2, "die-die speed is the relative contact speed (~2-3 m/s), got %s" % str(first.get("speed")))
	# Rest and tumble times were recorded.
	check(rec.rest_t[0] > 0.0 and rec.rest_t[1] >= 0.0 and rec.rest_t[0] <= rec.duration() + 0.001, "rest times recorded %s" % str(rec.rest_t))
	# Silence floor: a contact under impact_min_speed emits nothing.
	var got: Array[float] = []
	var cb := func(_id: int, _surf: String, speed: float, _imp: float, _o: int, _m: String) -> void: got.append(speed)
	s.dice[0].impact.connect(cb)
	s._last_impact = [-1.0, -1.0]
	s._play_t = 0.0
	s._on_contact({"t": 0.0, "die": 0, "kind": &"felt", "speed": s.tuning.impact_min_speed - 0.05, "impulse": 0.001, "other": -1})
	check(got.is_empty(), "contact at %.2f m/s (< %.2f floor) is silent" % [s.tuning.impact_min_speed - 0.05, s.tuning.impact_min_speed])
	s._play_t = 1.0
	s._on_contact({"t": 1.0, "die": 0, "kind": &"felt", "speed": s.tuning.impact_min_speed + 0.05, "impulse": 0.001, "other": -1})
	check(got.size() == 1, "contact just above the floor emits impact")
	s._play_t = 1.01
	s._on_contact({"t": 1.01, "die": 0, "kind": &"felt", "speed": 2.0, "impulse": 0.01, "other": -1})
	check(got.size() == 1, "impacts throttled per die (impact_min_interval)")
	s.dice[0].impact.disconnect(cb)
	s._play_t = -1.0
	# A real throw: thrown, tumble_ending and rest fire once per die.
	var counts := {"thrown": 0, "tumble": 0, "rest": 0}
	var c1 := func(_v: float) -> void: counts["thrown"] += 1
	var c2 := func(_id: int, _w: float) -> void: counts["tumble"] += 1
	var c3 := func(_id: int) -> void: counts["rest"] += 1
	s.thrown.connect(c1)
	for d in s.dice:
		d.tumble_ending.connect(c2)
		d.rest.connect(c3)
	_bet(s)
	s.throw(Table3D.QUICK_THROW)
	await s.sequence_finished
	check(counts["thrown"] == 1 and counts["tumble"] == 2 and counts["rest"] == 2, "thrown x1, tumble_ending x2, rest x2 per throw (%s)" % str(counts))
	s.thrown.disconnect(c1)
	for d in s.dice:
		d.tumble_ending.disconnect(c2)
		d.rest.disconnect(c3)


## Many varied, seeded flicks straight through the physics (DiceSim), the
## same way the table throws them. Design doc 5b timing pillar.
func _test_timing_stats(s: Table3D) -> void:
	var t := s.tuning
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var settle: Array[float] = []
	var reveal_max := 0.0
	var assists := 0
	var assisted_dice := 0
	var nudges := 0
	var n := 200
	var hand := s.camera.cam.unproject_position(Table3D.HAND)
	for k in n:
		for i in 2:
			s.dice[i].global_transform = Transform3D(Basis(Vector3(rng.randf(), rng.randf(), rng.randf()).normalized(), rng.randf_range(0, TAU)), s.hand_spot(i) + Vector3(rng.randf_range(-0.1, 0.0), 0.04, rng.randf_range(-0.05, 0.05)))
		var v := Vector2.from_angle(rng.randf_range(-PI * 0.95, -PI * 0.25)) * rng.randf_range(t.min_throw_speed, t.max_throw_speed * 1.2)
		var launch := s.launch_for(v, hand)
		var starts: Array[Transform3D] = [s.dice[0].global_transform, s.dice[1].global_transform]
		var rec: ThrowRecording = await s.sim.simulate(starts, launch["lin"], launch["spin"], k)
		# From mouse release: wind-up, then the recorded throw.
		var st := t.windup_time + rec.duration()
		settle.append(st)
		reveal_max = maxf(reveal_max, st + t.settle_wobble_time)
		if rec.assisted:
			assists += 1
			assisted_dice += rec.assisted_dice
		nudges += rec.nudges
	settle.sort()
	var median := (settle[n / 2 - 1] + settle[n / 2]) * 0.5
	var p90 := settle[int(n * 0.9)]
	print("TIMING over %d flicks: settle median %.3f s, p90 %.3f s, max %.3f s, min %.3f s; reveal max %.3f s; settle assist fired on %d throws (%.1f%%, %d dice); rail nudges %d" % [
		n, median, p90, settle[n - 1], settle[0], reveal_max, assists, 100.0 * assists / n, assisted_dice, nudges])
	check(median <= t.settle_target, "median settle %.3f <= settle_target %.2f" % [median, t.settle_target])
	check(reveal_max <= t.reveal_cap + 0.0001, "max reveal %.3f <= reveal_cap %.2f" % [reveal_max, t.reveal_cap])


## One throw at 1x in real time: release -> dice_landed within reveal_cap.
func _test_real_time_reveal(s: Table3D) -> void:
	s.test_speed = 1.0
	var worst := 0.0
	for k in 3:
		_bet(s)
		var t0 := Time.get_ticks_msec()
		s.throw(Table3D.QUICK_THROW)
		await s.dice_landed
		worst = maxf(worst, (Time.get_ticks_msec() - t0) / 1000.0)
		s.test_speed = 10.0
		await s.sequence_finished
		s.test_speed = 1.0
	print("REAL-TIME 1x release -> reveal (dice_landed): worst %.3f s" % worst)
	check(worst <= s.tuning.reveal_cap + 0.1, "1x reveal in real time %.3f <= %.2f (+0.1 frame slack)" % [worst, s.tuning.reveal_cap])


func _test_speed_modes(s: Table3D) -> void:
	var times: Array[float] = []
	for mode in 3:
		s.set_speed_mode(mode)
		s.test_speed = 1.0
		_bet(s)
		s.rig_next_roll(3, 3)  # never a decision on a point, a point on the come-out
		var t0 := Time.get_ticks_msec()
		s.throw(Table3D.QUICK_THROW)
		await s.sequence_finished
		times.append((Time.get_ticks_msec() - t0) / 1000.0)
		check(s.dice[0].up_value() == 3 and s.dice[1].up_value() == 3, "speed %s: faces still the seeded 3-3" % Table3D.SPEED_NAMES[mode])
	print("SPEED full throw sequence: 1x %.2f s, 2x %.2f s, Instant %.2f s" % times)
	check(times[1] < times[0] * 0.8, "2x is faster than 1x")
	check(times[2] < times[1] * 0.6 and times[2] < 1.0, "Instant skips straight to the result (%.2f s)" % times[2])
	s.set_speed_mode(0)


func _test_no_soul_restore(s: Table3D) -> void:
	s.test_speed = 10.0
	s.set_speed_mode(2)
	# Make sure we are on a come-out, lose some Soul, then win.
	while s.poc.table.craps.has_point():
		s.rig_next_roll(3, 4)
		_bet(s)
		s.throw(Table3D.QUICK_THROW)
		await s.sequence_finished
	_bet(s)
	s.rig_next_roll(1, 1)
	s.throw(Table3D.QUICK_THROW)
	await s.sequence_finished
	var soul := s.poc.soul
	for k in 4:
		_bet(s)
		s.rig_next_roll(3, 4)  # natural 7 on the come-out
		s.throw(Table3D.QUICK_THROW)
		await s.sequence_finished
		check(s.poc.soul == soul, "3D table: natural #%d leaves Soul at %d (wins never restore Soul)" % [k, soul])
	s.set_speed_mode(0)


# --- Phone readability -----------------------------------------------------------

func _test_die_size() -> void:
	var sizes: Array[Vector2i] = [Vector2i(1920, 1080), Vector2i(390, 844), Vector2i(844, 390)]
	for sz in sizes:
		var vp := SubViewport.new()
		vp.size = sz
		vp.own_world_3d = true
		root.add_child(vp)
		var s := _make_scene()
		vp.add_child(s)
		await process_frame
		var phone := sz.x < 1000
		var d := s.camera.distance
		if phone:
			s.fit_phone(Vector2(sz))
			d = s.camera.distance
		s.camera._apply()
		var spots := s.rest_spots()
		var min_w := INF
		var min_h := INF
		var on_screen := 0
		var screen := Rect2(Vector2.ZERO, Vector2(sz))
		for p in spots:
			s.dice[0].global_transform = Transform3D(Basis.IDENTITY, p)
			if not screen.has_point(s.camera.cam.unproject_position(p)):
				continue
			on_screen += 1
			var px := s.dice[0].screen_size(s.camera.cam)
			min_w = minf(min_w, px.x)
			min_h = minf(min_h, px.y)
		var hand_ok := screen.has_point(s.camera.cam.unproject_position(s.hand_spot(0))) and screen.has_point(s.camera.cam.unproject_position(s.hand_spot(1)))
		var zone_ok := screen.has_point(s.camera.cam.unproject_position(Vector3(0, 0.04, 0)))
		print("DIE SIZE %dx%d (%s, camera %.2f m): smallest die %.1f x %.1f px (w x h) over %d of %d rest spots on screen; hand on screen %s, landing zone %s" % [
			sz.x, sz.y, "phone framing" if phone else "spec camera", d, min_w, min_h, on_screen, spots.size(), hand_ok, zone_ok])
		check(hand_ok and zone_ok, "%dx%d: hand and landing zone are on screen" % [sz.x, sz.y])
		check(minf(min_w, min_h) >= s.tuning.min_die_px, "%dx%d: dice >= %.0f px (got %.1f)" % [sz.x, sz.y, s.tuning.min_die_px, minf(min_w, min_h)])
		if not phone:
			check(on_screen == spots.size(), "desktop: every rest spot is on screen")
		vp.queue_free()
		await process_frame
