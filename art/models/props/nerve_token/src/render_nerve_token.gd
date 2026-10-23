## Nerve token renders (Forward+): the 48 px phone state strip and a close-up sheet (PC LOD), on the
## Hearth detail-pass stage (render_detail.gd). Game-camera stills: render_nerve_token_game.gd.
## Not a test, not exported. Needs Vulkan:
##   xvfb-run -a godot --path . --rendering-driver vulkan --fixed-fps 30 \
##     --script res://art/models/props/nerve_token/src/render_nerve_token.gd -- [--out=<dir>]
extends "res://art/models/boards/hearth/src/render_detail.gd"

const TOKEN := "res://art/models/props/nerve_token/scenes/nerve_token%s.tscn"
const AT := {false: Vector3(0.48, 0.11, 0.578), true: Vector3(0.30, 0.11, 0.61)}   # proposed spots (PC, phone)
## [label, state, extra]  extra: "" | "bob" (rescue mid-bob) | "shake" (refusal, first drawing)
const STATES := [["available", 0, ""], ["carried (notch)", 1, ""], ["picking (lift)", 2, ""], ["nudged (tip)", 3, ""],
	["spent (flat, dull)", 4, ""], ["closed", 5, ""], ["rescue (slid, bob up)", 6, "bob"], ["shake (mid)", 0, "shake"]]


func _add(vp: SubViewport, mobile: bool, st: Array) -> Node3D:
	var t := (load(TOKEN % ("_mobile" if mobile else "")) as PackedScene).instantiate() as Node3D
	t.name = "Token"
	t.position = AT[mobile]
	vp.add_child(t)
	t.set("reduced_motion", true)
	if st[1] == 6:
		t.call("rescue_at", AT[mobile] + Vector3(-0.12, 0, 0))
	t.call("set_state", st[1], false)
	return t


func _pose(t: Node3D, st: Array) -> void:
	t.set_process(false)
	if st[2] == "bob":
		t.set("bob", 0.006)
	elif st[2] == "shake":
		t.set("shake_deg", 10.0)
	t.call("_apply")


func _run() -> void:
	out = "/workspace/dice/art/renders/nerve_token/v1/"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	var ph := _a153087(PHONE_CAM[0], PHONE_CAM[1])
	var svps: Array = []
	for st in STATES:
		var vp := _stage(Vector2i(844, 390), ph, 36.0, true, {"mobile": true, "dice": false, "smiles": false})
		svps.append([vp, _add(vp, true, st)])
	await _settle(6)
	for i in STATES.size():
		_pose(svps[i][1], STATES[i])
	await _settle(3)
	var cam0 := (svps[0][0] as SubViewport).get_node("Cam") as Camera3D
	var c := AT[true] as Vector3
	var lo := Vector2(1e9, 1e9)
	var hi := Vector2(-1e9, -1e9)
	for p in [c + Vector3(-0.30, 0, 0.06), c + Vector3(0.30, 0, 0.06), c + Vector3(-0.30, 0.22, -0.05), c + Vector3(0.30, 0.22, -0.05)]:
		var s := cam0.unproject_position(p)
		lo = lo.min(s)
		hi = hi.max(s)
	var r := Rect2i(Vector2i(lo), Vector2i(hi - lo)).intersection(Rect2i(0, 0, 844, 390))
	var die_px := cam0.unproject_position(c + Vector3(0.04, 0, 0)).x - cam0.unproject_position(c - Vector3(0.04, 0, 0)).x
	var k := 48.0 / die_px
	var tw := int(r.size.x * k)
	var th := int(r.size.y * k)
	var strip := Image.create(tw * 4, th * 2, false, Image.FORMAT_RGB8)
	for i in STATES.size():
		var img := (svps[i][0] as SubViewport).get_texture().get_image().get_region(r)
		img.convert(Image.FORMAT_RGB8)
		img.resize(tw, th, Image.INTERPOLATE_LANCZOS)
		strip.blit_rect(img, Rect2i(0, 0, tw, th), Vector2i((i % 4) * tw, (i / 4) * th))
	strip.save_png(out.path_join("phone_strip_48px.png"))
	log_lines.append("[phone strip] crop %s at 844x390, die %.1f px -> x%.2f (die = 48 px); 4x2 tiles L->R, T->B: %s" % [r, die_px, k, ", ".join(STATES.map(func(s): return s[0]))])
	for v in svps:
		v[0].queue_free()
	await _settle(2)
	var cvps: Array = []
	var at := AT[false] as Vector3
	var eye := at + Vector3(0.0, 0.30, 0.50)
	for st in STATES:
		var vp := _stage(Vector2i(640, 400), _look(eye, at + Vector3(0, 0.07, 0)), 36.0, true, {"dice": false, "smiles": false})
		cvps.append([vp, _add(vp, false, st)])
	await _settle(6)
	for i in STATES.size():
		_pose(cvps[i][1], STATES[i])
	await _settle(3)
	var sheet := Image.create(640 * 4, 400 * 2, false, Image.FORMAT_RGB8)
	for i in STATES.size():
		var img := (cvps[i][0] as SubViewport).get_texture().get_image()
		img.convert(Image.FORMAT_RGB8)
		sheet.blit_rect(img, Rect2i(0, 0, 640, 400), Vector2i((i % 4) * 640, (i / 4) * 400))
	sheet.save_png(out.path_join("closeup_sheet.png"))
	log_lines.append("[closeup] PC LOD, 640x400 tiles 4x2, same order")
	var lf := FileAccess.open(out.path_join("metrics.txt"), FileAccess.WRITE)
	lf.store_string("\n".join(log_lines) + "\n")
	print("\n".join(log_lines))
	quit(0)
