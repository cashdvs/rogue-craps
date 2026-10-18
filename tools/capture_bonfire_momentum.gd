## Lob vs hard throw (movie): run with --fixed-fps 30 --write-movie out.avi.
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-driver vulkan \
##       --resolution 1280x720 --fixed-fps 30 --write-movie /tmp/momentum.avi \
##       --script res://tools/capture_bonfire_momentum.gd
extends SceneTree

var s: Bonfire3D


func _initialize() -> void:
	_run.call_deferred()


func wait(t: float) -> void:
	await create_timer(t, true, false, true).timeout


func ready_to_act() -> void:
	while s.phase != Table3D.Phase.BET:
		await process_frame


func flick(speed: float) -> void:
	await ready_to_act()
	await wait(0.5)
	s.rig_faces([2, 2, 3, 4, 6] as Array[int])
	s.throw(Vector2(-0.55, -0.83).normalized() * speed)
	await s.sequence_finished
	await wait(1.0)
	if s.run.state == BonfireRun.State.PICK:
		for i in BonfireScoring.matching_subsets(s.run.throw_faces, s.bonfire_tuning)[0]:
			s.pick_die(i)
		await s.bank()


func _run() -> void:
	s = (load("res://scenes/bonfire.tscn") as PackedScene).instantiate() as Bonfire3D
	s.bonfire_seed = 4
	root.add_child(s)
	await wait(0.8)
	s.bhud.flash("GENTLE LOB", Palette.BONE)
	await flick(800.0)
	s.bhud.flash("HARD THROW", Palette.EMBER)
	await flick(4200.0)
	await wait(0.5)
	quit()
