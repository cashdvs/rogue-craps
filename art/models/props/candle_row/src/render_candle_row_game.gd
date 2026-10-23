## Candle row in the REAL game camera + HUD (Bonfire3D, scripts/table3d/camera_rig.gd framing via
## tools/capture_phone.gd), on the Hearth board at its Anchors/CandleRow marker. Prints the row's screen
## rect, candle height / pitch in px and every visible HUD control it overlaps. Not a test, not exported.
##   xvfb-run -a godot --path . --rendering-driver vulkan --resolution 1920x1080 \
##     --script res://art/models/props/candle_row/src/render_candle_row_game.gd -- [phone=2337x1080] [out=<png>] [state=h,d,l]
##     [anchor=CandleRow|CandleRowPortrait]
extends SceneTree

const HEARTH := "res://art/models/boards/hearth/scenes/hearth_board%s.tscn"
const ROW := "res://art/models/props/candle_row/scenes/candle_row%s.tscn"
var _phone := CapturePhone.new()


func _initialize() -> void:
	_run.call_deferred()


func _ctrls(n: Node, out: Array) -> void:
	if n is Control and (n as Control).is_visible_in_tree() and (n is Button or (n is Label and (n as Label).text != "")):
		out.append(n)
	for c in n.get_children():
		_ctrls(c, out)


func _run() -> void:
	_phone.parse_args()
	var out := "/workspace/dice/art/renders/candle_row/v2/game_real_pc.png"
	var st := [4, 0, 3]
	var anchor_name := "CandleRow"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
		if a.begins_with("state="):
			var p := a.substr(6).split(",")
			st = [int(p[0]), int(p[1]), int(p[2])]
		if a.begins_with("anchor="):
			anchor_name = a.substr(7)
	var t := load("res://resources/tuning/bonfire_tuning.tres") as BonfireTuning
	var s := (load("res://scenes/bonfire.tscn") as PackedScene).instantiate() as Bonfire3D
	s.setup = TableSetup.sandbox(t, 5)
	s.tutorial_override = 0
	_phone.add_table(root, s)
	await process_frame
	await process_frame
	var tbl := s.find_child("Table", true, false)
	if tbl != null:  # the sandbox table's own felt + rails: the Hearth board replaces them for the still
		for c in tbl.get_children():
			if c is MeshInstance3D and c.name != "WallBack":
				(c as MeshInstance3D).visible = false
	var mob := _phone.screen != Vector2.ZERO
	var lod := "_mobile" if mob else ""
	var board := (load(HEARTH % lod) as PackedScene).instantiate() as Node3D
	s.add_child(board)
	var anchor := board.get_node("Anchors/" + anchor_name) as Marker3D
	var row := (load(ROW % lod) as PackedScene).instantiate() as Node3D
	row.reduced_motion = true
	anchor.add_child(row)
	row.call("table_start", st[0], st[1])
	for i in st[0] - st[2]:
		row.call("spend", false)
	await create_timer(0.6).timeout
	_phone.frame(s)
	s.camera.snap_home()
	for i in 8:
		await process_frame
	var cam := s.camera.cam
	var vs := cam.get_viewport().get_visible_rect().size
	var k: float = (row.get_node("Sockets/Socket1") as Node3D).scale.x
	var at := anchor.global_position
	var ax := anchor.global_basis.x
	var az := anchor.global_basis.z
	var half := (0.058 * 4 + 0.01) * k
	var lo := Vector2(1e9, 1e9)
	var hi := Vector2(-1e9, -1e9)
	for p in [Vector3(-half, 0, 0.02 * k), Vector3(half, 0, 0.02 * k), Vector3(-half, 0.11 * k, -0.02 * k), Vector3(half, 0.11 * k, -0.02 * k)]:
		var sp := cam.unproject_position(at + ax * p.x + Vector3.UP * p.y + az * p.z)
		lo = lo.min(sp)
		hi = hi.max(sp)
	var rr := Rect2(lo, hi - lo)
	var s0 := (row.get_node("Sockets/Socket1") as Node3D).global_position
	var s1 := (row.get_node("Sockets/Socket2") as Node3D).global_position
	var pitch := cam.unproject_position(s0).distance_to(cam.unproject_position(s1))
	var ch := cam.unproject_position(s0).distance_to(cam.unproject_position(s0 + Vector3(0, 0.0795 * k, 0)))
	var inside := Rect2(Vector2.ZERO, vs).encloses(rr)
	print("GAME %s vp %s | anchor %s | row rect %s (%s) | candle h %.1f px, pitch %.1f px" % [
		"phone" if mob else "pc", vs, at, rr, "on screen" if inside else "CROPPED", ch, pitch])
	var cs: Array = []
	_ctrls(s.bhud, cs)
	for c in cs:
		var cr := (c as Control).get_global_rect()
		if cr.intersects(rr):
			var txt: String = (c as Button).text if c is Button else (c as Label).text
			print("  overlaps %s '%s' %s" % [c.name, txt.replace("\n", " ").left(24), cr])
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	_phone.image(root).save_png(out)
	quit()
