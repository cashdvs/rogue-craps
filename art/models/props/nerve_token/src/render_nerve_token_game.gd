## Nerve token in the REAL game camera + HUD (Bonfire3D framing via tools/capture_phone.gd) on the Hearth
## board. main has no Anchors/NerveToken yet (the candle row anchors are in unmerged PR #142), so the
## proposed spots live here (SPOTS) and in the README. Prints the token's screen rect, its height in px,
## the clearance to every HUD control and to the candle row's footprint. Not a test, not exported.
##   xvfb-run -a godot --path . --rendering-driver vulkan --resolution 1920x1080 \
##     --script res://art/models/props/nerve_token/src/render_nerve_token_game.gd -- [phone=844x390] [out=<png>]
##     [state=0..6] [spot=pc|phone|portrait] [x=..] [z=..]
extends SceneTree

const HEARTH := "res://art/models/boards/hearth/scenes/hearth_board%s.tscn"
const TOKEN := "res://art/models/props/nerve_token/scenes/nerve_token%s.tscn"
## proposed anchor: position on the Hearth (rail top y 0.11), yaw (deg)
const SPOTS := {"pc": [Vector3(0.48, 0.11, 0.578), 0.0], "phone": [Vector3(0.30, 0.11, 0.61), 0.0],
	"portrait": [Vector3(0.85, 0.11, -0.16), 90.0]}
## candle row (PR #142) anchors + footprint in row-local space, for the keep-out check
const ROWS := {"pc": [Vector3(-0.40, 0.11, 0.578), 0.0, Vector3(1, 1, 1)], "phone": [Vector3(-0.51, 0.11, 0.61), 0.0, Vector3(1.218, 1.4, 1.4)],
	"portrait": [Vector3(1.11, 0.11, 0.275), 90.0, Vector3(1.218, 1.4, 1.4)]}
const ROW_LO := Vector3(-0.140, 0.0, -0.057)
const ROW_HI := Vector3(0.169, 0.115, 0.017)
var _phone := CapturePhone.new()


func _initialize() -> void:
	_run.call_deferred()


func _ctrls(n: Node, out: Array) -> void:
	if n is Control and (n as Control).is_visible_in_tree() and (n is Button or (n is Label and (n as Label).text != "")):
		out.append(n)
	for c in n.get_children():
		_ctrls(c, out)


## Labels: the rect the glyphs actually cover (alignment-aware), not the layout box. Buttons: the box.
func _ink_rect(c: Control) -> Rect2:
	var r := c.get_global_rect()
	if not (c is Label):
		return r
	var l := c as Label
	var f := l.get_theme_font("font")
	var fs := l.get_theme_font_size("font_size")
	if l.label_settings != null:
		if l.label_settings.font != null:
			f = l.label_settings.font
		fs = l.label_settings.font_size
	var sz := f.get_multiline_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, r.size.x if l.autowrap_mode != TextServer.AUTOWRAP_OFF else -1.0, fs)
	sz.x = minf(sz.x, r.size.x)
	var x := r.position.x
	if l.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER:
		x += (r.size.x - sz.x) * 0.5
	elif l.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT:
		x += r.size.x - sz.x
	var y := r.position.y
	if l.vertical_alignment == VERTICAL_ALIGNMENT_CENTER:
		y += (r.size.y - sz.y) * 0.5
	elif l.vertical_alignment == VERTICAL_ALIGNMENT_BOTTOM:
		y += r.size.y - sz.y
	var gs := c.get_global_transform().get_scale()
	return Rect2(Vector2(x, y), sz * gs)


func _rect(cam: Camera3D, pts: Array) -> Rect2:
	var lo := Vector2(1e9, 1e9)
	var hi := Vector2(-1e9, -1e9)
	for p in pts:
		var sp := cam.unproject_position(p)
		lo = lo.min(sp)
		hi = hi.max(sp)
	return Rect2(lo, hi - lo)


func _mesh_pts(n: Node) -> Array:
	var out := []
	for m in n.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if not mi.is_visible_in_tree():
			continue
		var bb := mi.get_aabb()
		for ci in 8:
			out.append(mi.global_transform * bb.get_endpoint(ci))
	return out


func _gap(a: Rect2, b: Rect2) -> float:
	return maxf(maxf(b.position.x - a.end.x, a.position.x - b.end.x), maxf(b.position.y - a.end.y, a.position.y - b.end.y))


func _run() -> void:
	_phone.parse_args()
	var out := "/workspace/dice/art/renders/nerve_token/v1/game_pc.png"
	var st := 0
	var spot := ""
	var x_over := INF
	var z_over := INF
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
		if a.begins_with("state="):
			st = int(a.substr(6))
		if a.begins_with("spot="):
			spot = a.substr(5)
		if a.begins_with("z="):
			z_over = float(a.substr(2))
		if a.begins_with("x="):
			x_over = float(a.substr(2))
	var t := load("res://resources/tuning/bonfire_tuning.tres") as BonfireTuning
	var s := (load("res://scenes/bonfire.tscn") as PackedScene).instantiate() as Bonfire3D
	s.setup = TableSetup.sandbox(t, 5)
	s.tutorial_override = 0
	_phone.add_table(root, s)
	await process_frame
	await process_frame
	var tbl := s.find_child("Table", true, false)
	if tbl != null:
		for c in tbl.get_children():
			if c is MeshInstance3D and c.name != "WallBack":
				(c as MeshInstance3D).visible = false
	var mob := _phone.screen != Vector2.ZERO
	var lod := "_mobile" if mob else ""
	var board := (load(HEARTH % lod) as PackedScene).instantiate() as Node3D
	s.add_child(board)
	if spot == "":
		spot = ("portrait" if _phone.screen.y > _phone.screen.x else "phone") if mob else "pc"
	var anchor := Marker3D.new()
	anchor.name = "NerveToken"
	board.add_child(anchor)
	anchor.position = SPOTS[spot][0]
	anchor.rotation_degrees.y = SPOTS[spot][1]
	if x_over != INF:
		anchor.position.x = x_over
	if z_over != INF:
		anchor.position.z = z_over
	var tok := (load(TOKEN % lod) as PackedScene).instantiate() as Node3D
	tok.reduced_motion = true
	anchor.add_child(tok)
	if st == 6:
		tok.rescue_x = 0.15
	tok.call("set_state", st, false)
	await create_timer(0.3).timeout
	_phone.frame(s)
	s.camera.snap_home()
	for i in 8:
		await process_frame
	var cam := s.camera.cam
	var vs := cam.get_viewport().get_visible_rect().size
	# the token itself (tablet + inlays, not the track) and the whole prop
	var tr := _rect(cam, _mesh_pts(tok.get_node("Rig/Slide")))
	var all := _rect(cam, _mesh_pts(tok.get_node("Rig/Cradle")) + _mesh_pts(tok.get_node("Rig/Slide")))
	var tap := (tok.get_node("Rig/TapCenter") as Node3D)
	var k: float = (tok.get_node("Rig") as Node3D).scale.x
	var by := tap.global_basis.y.normalized()
	var bx := tap.global_basis.x.normalized()
	var base := tap.global_position - by * 0.044 * k
	var h_px := cam.unproject_position(base).distance_to(cam.unproject_position(base + by * 0.088 * k))
	var w_px := cam.unproject_position(base - bx * 0.031 * k).distance_to(cam.unproject_position(base + bx * 0.031 * k))
	print("GAME %s vp %s screen %s | spot %s at %s | token rect %s (%s) | tablet %.1f x %.1f px (face h x w) | prop rect %s" % [
		"phone" if mob else "pc", vs, _phone.screen, spot, anchor.global_position, tr, "on screen" if Rect2(Vector2.ZERO, vs).encloses(all) else "CROPPED",
		h_px, w_px, all])
	# the dice for scale: the first die's on-screen size
	var dice := s.find_children("*", "DieVisual", true, false)
	if dice.size() > 0:
		var dr := _rect(cam, _mesh_pts(dice[0]))
		print("  die (in the tray) rect %s, %.1f x %.1f px" % [dr, dr.size.x, dr.size.y])
	# candle row footprint (PR #142 anchor)
	var row: Array = ROWS[spot]
	var xf := Transform3D(Basis(Vector3.UP, deg_to_rad(row[1])).scaled(row[2]), row[0])
	var rp := []
	for ci in 8:
		rp.append(board.global_transform * (xf * AABB(ROW_LO, ROW_HI - ROW_LO).get_endpoint(ci)))
	var rrect := _rect(cam, rp)
	print("  CANDLE ROW footprint %s | separation %.1f px %s" % [rrect, _gap(all, rrect), "clear" if _gap(all, rrect) >= 12.0 else "TIGHT"])
	var cs: Array = []
	_ctrls(s.bhud, cs)
	for c in cs:
		var cr := _ink_rect(c as Control)
		if cr.size.x <= 0.0:
			continue
		var gap := _gap(all, cr)
		if gap < 80.0:
			var t2: String = (c as Button).text if c is Button else (c as Label).text
			print("  CLEAR %6.1f px %s  %s '%s' ink %s" % [gap, "ok" if gap >= 12.0 else "FAIL", c.name, t2.replace("\n", " ").left(24), cr])
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	_phone.image(root).save_png(out)
	quit()
