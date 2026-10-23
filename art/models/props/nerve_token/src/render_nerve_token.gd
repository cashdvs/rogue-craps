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


func _renderer() -> String:
	var rd := RenderingServer.get_rendering_device()
	return "renderer: method=%s driver=%s device=%s (%s)" % [RenderingServer.get_current_rendering_method(),
		RenderingServer.get_current_rendering_driver_name(), RenderingServer.get_video_adapter_name(),
		"RenderingDevice ok" if rd != null else "NO RenderingDevice (GL)"]


## Mask pass: the tablet (bone only; the chevron and notch still occlude it) drawn flat magenta.
func _mask_tablet(t: Node3D) -> void:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1, 0, 1)
	for mi in t.find_child("Tablet", true, false).find_children("*", "MeshInstance3D", true, false) + [t.find_child("Tablet", true, false)]:
		if mi is MeshInstance3D:
			mi.material_override = m


## Bone pixels of the tablet: the mask pass is magenta there.
func _measure(a: Image, ref: Image) -> Array:
	var l: Array[float] = []
	var sum := Vector3.ZERO
	for y in a.get_height():
		for x in a.get_width():
			var p := a.get_pixel(x, y)
			var q := ref.get_pixel(x, y)
			if q.r - q.g > 0.25 and q.b - q.g > 0.25:
				l.append(_luma(p))
				sum += Vector3(p.r, p.g, p.b)
	l.sort()
	if l.is_empty():
		return [0.0, 0.0, Vector3.ZERO, 0]
	return [l[l.size() / 2], l[int(l.size() * 0.9)], sum / l.size(), l.size()]


## Two stages (available, spent) on one camera; returns [img avail, img spent, measures avail, spent].
func _pair(size: Vector2i, cam: Transform3D, mobile: bool, opts: Dictionary) -> Array:
	var pair := [STATES[0], STATES[4]]
	var vs: Array = []
	for st in pair:
		var vp := _stage(size, cam, 36.0, true, opts)
		vs.append([vp, _add(vp, mobile, st)])
	await _settle(6)
	for i in 2:
		_pose(vs[i][1], pair[i])
	await _settle(3)
	var res: Array = []
	var imgs: Array = []
	for v in vs:
		imgs.append((v[0] as SubViewport).get_texture().get_image())
		_mask_tablet(v[1])
	await _settle(3)
	for i in 2:
		res.append(_measure(imgs[i], (vs[i][0] as SubViewport).get_texture().get_image()))
	for v in vs:
		v[0].queue_free()
	await _settle(2)
	return [imgs[0], imgs[1], res[0], res[1]]


func _fmt(name: String, m: Array) -> String:
	var c: Vector3 = m[2]
	return "%s median luma %.3f (p90 %.3f), mean rgb (%.3f, %.3f, %.3f) b-r %+.3f, %d px" % [name, m[0], m[1], c.x, c.y, c.z, c.z - c.x, m[3]]


func _run() -> void:
	out = "/workspace/dice/art/renders/nerve_token/v3/"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	log_lines.append(_renderer())
	var ph := _a153087(PHONE_CAM[0], PHONE_CAM[1])
	var r: Array = await _pair(Vector2i(844, 390), ph, true, {"mobile": true, "dice": false, "smiles": false})
	log_lines.append("[phone game cam 844x390] " + _fmt("available", r[2]) + " | " + _fmt("spent", r[3]) + " | spent/available %.0f%%" % (r[3][0] / maxf(r[2][0], 1e-3) * 100.0))
	var c := AT[true] as Vector3
	var cam0 := Camera3D.new()
	var lo := Vector2(1e9, 1e9)
	var hi := Vector2(-1e9, -1e9)
	var tmp := _stage(Vector2i(844, 390), ph, 36.0, false, {"mobile": true, "dice": false, "smiles": false})
	await _settle(1)
	var cc := tmp.get_node("Cam") as Camera3D
	for p in [c + Vector3(-0.14, 0, 0.06), c + Vector3(0.14, 0, 0.06), c + Vector3(-0.14, 0.22, -0.05), c + Vector3(0.14, 0.22, -0.05)]:
		var s := cc.unproject_position(p)
		lo = lo.min(s)
		hi = hi.max(s)
	var die_px := cc.unproject_position(c + Vector3(0.04, 0, 0)).x - cc.unproject_position(c - Vector3(0.04, 0, 0)).x
	tmp.queue_free()
	cam0.free()
	var rr := Rect2i(Vector2i(lo), Vector2i(hi - lo)).intersection(Rect2i(0, 0, 844, 390))
	var k := 48.0 / die_px
	var tw := int(rr.size.x * k)
	var th := int(rr.size.y * k)
	var strip := Image.create(tw * 2, th, false, Image.FORMAT_RGB8)
	for i in 2:
		var img := (r[i] as Image).get_region(rr)
		img.convert(Image.FORMAT_RGB8)
		img.resize(tw, th, Image.INTERPOLATE_LANCZOS)
		strip.blit_rect(img, Rect2i(0, 0, tw, th), Vector2i(i * tw, 0))
	strip.save_png(out.path_join("phone_strip_48px_available_spent.png"))
	log_lines.append("[strip] crop %s, die %.1f px -> x%.2f (die = 48 px): available | spent" % [rr, die_px, k])
	var at := AT[false] as Vector3
	var q: Array = await _pair(Vector2i(640, 400), _look(at + Vector3(0, 0.30, 0.50), at + Vector3(0, 0.07, 0)), false, {"dice": false, "smiles": false})
	log_lines.append("[PC close-up 640x400, PC spot] " + _fmt("available", q[2]) + " | " + _fmt("spent", q[3]) + " | spent/available %.0f%%" % (q[3][0] / maxf(q[2][0], 1e-3) * 100.0))
	var sheet := Image.create(1280, 400, false, Image.FORMAT_RGB8)
	for i in 2:
		var img := q[i] as Image
		img.convert(Image.FORMAT_RGB8)
		sheet.blit_rect(img, Rect2i(0, 0, 640, 400), Vector2i(i * 640, 0))
	sheet.save_png(out.path_join("closeup_available_spent.png"))
	var lf := FileAccess.open(out.path_join("metrics.txt"), FileAccess.WRITE)
	lf.store_string("\n".join(log_lines) + "\n")
	print("\n".join(log_lines))
	quit(0)
