## Game-camera still of the Bonfire table at the current window size, for
## framing reviews. If the art is in the tree (art/board-hearth,
## art/dealer-smiles), the Hearth board replaces the greybox table visuals
## and Smiles stands at his dealer spot; otherwise it's the greybox table.
## Prints the CameraFraming numbers too.
##   xvfb-run -a -s "-screen 0 2400x2400x24" godot --path . --rendering-driver vulkan \\
##       --resolution 1920x1080 --script res://tools/capture_camera_framing.gd -- out=/tmp/x.png
extends SceneTree

const HEARTH := "res://art/models/boards/hearth/scenes/hearth_board.tscn"
const SMILES := "res://art/models/characters/smiles/scenes/smiles.tscn"
## art/dealer-smiles README "Placement".
const DEALER_SPOT := Vector3(-0.42, -0.47, -0.86)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := "user://camera_framing.png"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
	var t := load("res://resources/tuning/bonfire_tuning.tres") as BonfireTuning
	var s := (load("res://scenes/bonfire.tscn") as PackedScene).instantiate() as Bonfire3D
	s.setup = TableSetup.sandbox(t, 5)
	s.tutorial_override = 0
	root.add_child(s)
	await process_frame
	await process_frame
	var art := []
	var brazier: Node3D = null
	var smiles: Node3D = null
	if ResourceLoader.exists(HEARTH):
		var tbl := s.table.root if "root" in s.table else s.find_child("Table", true, false)
		if tbl != null:
			for c in tbl.get_children():
				if c is MeshInstance3D and c.name != "WallBack":
					(c as MeshInstance3D).visible = false
		var board := (load(HEARTH) as PackedScene).instantiate() as Node3D
		s.add_child(board)
		for n in board.find_children("*", "Node3D", true, false):
			if (n as Node).scene_file_path.contains("brazier"):
				brazier = n
				break
		art.append("hearth")
	if ResourceLoader.exists(SMILES):
		var sm := (load(SMILES) as PackedScene).instantiate() as Node3D
		sm.position = DEALER_SPOT
		s.add_child(sm)
		smiles = sm
		art.append("smiles")
	await create_timer(0.6).timeout
	s.camera.snap_home()
	for i in 6:
		await process_frame
	var cam := s.camera.cam
	var st := CameraFraming.die_stats(cam, s.tuning.die_size)
	print("CAPTURE %s art %s | headroom dealer %.3f m, over rail %.3f m | die px mean %.1f min %.1f | must margin %.0f px" % [
		root.get_window().size, str(art), CameraFraming.headroom(cam), CameraFraming.headroom_at_rail(cam), float(st["mean"]), float(st["min"]),
		CameraFraming.margin(cam, CameraFraming.must_points())])
	for pair in [["brazier", brazier], ["smiles", smiles]]:
		if pair[1] != null:
			var pts := _mesh_corners(pair[1])
			var top := -INF
			for q in pts:
				top = maxf(top, q.y)
			print("  %s: mesh top y %.3f, fully-in-frame margin %.0f px" % [pair[0], top, CameraFraming.margin(cam, pts)])
	var img := root.get_texture().get_image()
	img.save_png(out)
	print("saved ", out)
	quit()


## World-space AABB corners of every mesh under n (particles/lights ignored).
func _mesh_corners(n: Node) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var nodes: Array = n.find_children("*", "MeshInstance3D", true, false)
	if n is MeshInstance3D:
		nodes.append(n)
	for m in nodes:
		var mi := m as MeshInstance3D
		if not mi.is_visible_in_tree():
			continue
		var bb := mi.global_transform * mi.get_aabb()
		for i in 8:
			out.append(bb.get_endpoint(i))
	return out
