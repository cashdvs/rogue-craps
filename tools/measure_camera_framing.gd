## Game-camera framing numbers in the real Bonfire scene at the current
## window size: headroom above the far rail at the dealer's depth (and over
## the rail), projected die size (mean / min over the felt rest spots,
## centre), and the margin (px) of the must-see points (felt, rails,
## TotalPlate, TargetPlate, brazier top) and the phone pot row.
##   xvfb-run -a -s "-screen 0 2400x2400x24" godot --path . --rendering-driver vulkan \\
##       --resolution 1920x1080 --script res://tools/measure_camera_framing.gd
extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var t := load("res://resources/tuning/bonfire_tuning.tres") as BonfireTuning
	var s := (load("res://scenes/bonfire.tscn") as PackedScene).instantiate() as Bonfire3D
	s.setup = TableSetup.sandbox(t, 5)
	s.tutorial_override = 0
	root.add_child(s)
	await process_frame
	await process_frame
	await create_timer(0.3).timeout
	s.camera.snap_home()
	var cam := s.camera.cam
	var ds := s.tuning.die_size
	var st := CameraFraming.die_stats(cam, ds)
	var pot: Array[Vector3] = [s.pot_slot(0) + Vector3(0, Bonfire3D.PILLAR_HEIGHT, 0), s.pot_slot(4) + Vector3(0, ds, 0)]
	var far: Array[Vector3] = [CameraFraming.TARGET_PLATE, CameraFraming.BRAZIER_TOP]
	print("FRAMING window %s canvas %s pitch %.1f tilt %.1f dist %.3f pivot %s | headroom dealer %.3f m, over rail %.3f m | die px mean %.1f min %.1f centre %.1f | must margin %.0f px | far rail+brazier margin %.0f px | pot margin %.0f px | target plate px %.1f" % [
		root.get_window().size, root.get_visible_rect().size, s.camera.pitch_deg, s.camera.look_up_deg, s.camera.home_distance, s.camera.home_pivot,
		CameraFraming.headroom(cam), CameraFraming.headroom_at_rail(cam), float(st["mean"]), float(st["min"]), float(st["center"]),
		CameraFraming.margin(cam, CameraFraming.must_points()), CameraFraming.margin(cam, far), CameraFraming.margin(cam, pot),
		cam.unproject_position(CameraFraming.TARGET_PLATE + Vector3(0.1, 0, 0)).distance_to(cam.unproject_position(CameraFraming.TARGET_PLATE - Vector3(0.1, 0, 0)))])
	quit()
