## Physics tuning sweep for the 3D dice: throws a spread of flicks and prints
## settle-time and landing stats. Override any TuningData number to try it:
##   godot --headless --path . --script res://tools/stats_table_3d.gd -- die_linear_damp=1.0
## (Tooling only; the asserted timing numbers live in tests/test_table_3d.gd.)
extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var s := (load("res://scenes/table_3d.tscn") as PackedScene).instantiate() as Table3D
	s.rng_seed = 9
	var t := (load("res://resources/tuning/poc_tuning.tres") as TuningData).duplicate() as TuningData
	var args := OS.get_cmdline_user_args()
	for a in args:
		var kv := a.split("=")
		t.set(kv[0], float(kv[1]))
	s.tuning = t
	root.add_child(s)
	await process_frame
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var durs := []
	var zs := []
	var out_zone := 0
	var nud := 0
	var assists := 0
	var unsettled := 0
	var t0 := Time.get_ticks_msec()
	var n := 40
	for k in n:
		var v := Vector2.from_angle(rng.randf_range(-PI * 0.85, -PI * 0.35)) * rng.randf_range(s.tuning.min_throw_speed, s.tuning.max_throw_speed)
		for i in 2:
			s.dice[i].global_transform = Transform3D(Basis.IDENTITY, s.hand_spot(i))
		var L := s.launch_for(v, s.camera.cam.unproject_position(Table3D.HAND))
		var starts: Array[Transform3D] = []
		for d in s.dice:
			var tr := d.global_transform
			tr.origin.y = 0.06
			starts.append(tr)
		var rec: ThrowRecording = await s.sim.simulate(starts, L["lin"], L["spin"], k)
		durs.append(rec.duration() + s.tuning.windup_time)
		if rec.assisted: assists += 1
		nud += rec.nudges
		if not rec.settled: unsettled += 1
		for i in 2:
			var p := rec.final_transform(i).origin
			zs.append(snappedf(p.z, 0.01))
			if absf(p.x) > 0.7 or p.z < -0.18 or p.z > 0.2: out_zone += 1
	zs.sort()
	durs.sort()
	print("settle median %.3f max %.3f min %.3f reveal max %.3f assists %d" % [durs[durs.size() / 2], durs.max(), durs.min(), durs.max() + s.tuning.settle_wobble_time, assists])
	print("out of zone %d/%d nudges %d unsettled %d  ms %d" % [out_zone, n * 2, nud, unsettled, Time.get_ticks_msec() - t0])
	quit()
