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


func _run() -> void:
	_phone.parse_args()
	var out := "/workspace/dice/art/renders/candle_row/v4/game_real_pc_8lit.png"
	var st := [4, 0, 3]
	var anchor_name := ""
	var x_over := INF
	var z_over := INF
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
		if a.begins_with("state="):
			var p := a.substr(6).split(",")
			st = [int(p[0]), int(p[1]), int(p[2])]
		if a.begins_with("anchor="):
			anchor_name = a.substr(7)
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
	if tbl != null:  # the sandbox table's own felt + rails: the Hearth board replaces them for the still
		for c in tbl.get_children():
			if c is MeshInstance3D and c.name != "WallBack":
				(c as MeshInstance3D).visible = false
	var mob := _phone.screen != Vector2.ZERO
	var lod := "_mobile" if mob else ""
	var board := (load(HEARTH % lod) as PackedScene).instantiate() as Node3D
	s.add_child(board)
	if anchor_name == "":
		anchor_name = "CandleRowPhone" if mob else "CandleRow"
	var anchor := board.get_node("Anchors/" + anchor_name) as Marker3D
	if x_over != INF:
		anchor.position.x = x_over
	if z_over != INF:
		anchor.position.z = z_over
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
	var lo := Vector2(1e9, 1e9)
	var hi := Vector2(-1e9, -1e9)
	for m in row.find_children("*", "MeshInstance3D", true, false):  # every drawn mesh (both tiers, v4)
		var mi := m as MeshInstance3D
		if not mi.is_visible_in_tree():
			continue
		var bb := mi.get_aabb()
		for ci in 8:
			var sp := cam.unproject_position(mi.global_transform * bb.get_endpoint(ci))
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
	# ink extents of the candles themselves (socket 1 .. 8 +- candle radius, base to flame tip)
	var clo := Vector2(1e9, 1e9)
	var chi := Vector2(-1e9, -1e9)
	for i in range(1, mini(st[0], 8) + 1):  # every socket in use (both tiers, v4)
		var sk := row.get_node("Sockets/Socket%d" % i) as Node3D
		for d in [Vector3(-0.012, 0, 0), Vector3(0.012, 0, 0), Vector3(-0.012, 0.115, 0), Vector3(0.012, 0.115, 0)]:
			var sp := cam.unproject_position(sk.to_global(d))
			clo = clo.min(sp)
			chi = chi.max(sp)
	var cr8 := Rect2(clo, chi - clo)
	print("  candles 1-%d ink rect %s (%s)" % [mini(st[0], 8), cr8, "on screen" if Rect2(Vector2.ZERO, vs).encloses(cr8) else "CROPPED"])
	var cs: Array = []
	_ctrls(s.bhud, cs)
	for c in cs:
		var cr := _ink_rect(c as Control)
		if cr.size.x <= 0.0:
			continue
		var hg := maxf(cr.position.x - cr8.end.x, cr8.position.x - cr.end.x)
		var vg := maxf(cr.position.y - cr8.end.y, cr8.position.y - cr.end.y)
		var gap := maxf(hg, vg)  # separation: clear if either axis is apart
		if gap < 60.0:
			var side := ("right" if cr.position.x >= cr8.end.x else "left") if hg >= vg else ("below" if cr.position.y >= cr8.end.y else "above")
			if gap < 0.0:
				side = "OVERLAP"
			var t2: String = (c as Button).text if c is Button else (c as Label).text
			print("  CLEAR %-7s %6.1f px %s  %s '%s' ink %s" % [side, gap, "ok" if gap >= 12.0 else "FAIL", c.name, t2.replace("\n", " ").left(24), cr])
		if false:
			var txt: String = (c as Button).text if c is Button else (c as Label).text
			print("  overlaps %s '%s' %s" % [c.name, txt.replace("\n", " ").left(24), cr])
	var tray := board.get_node_or_null("Anchors/ChipTray")
	if tray != null:  # the cauldron (chip tray) in screen space
		var tlo := Vector2(1e9, 1e9)
		var thi := Vector2(-1e9, -1e9)
		for m in tray.find_children("*", "MeshInstance3D", true, false):
			var mi := m as MeshInstance3D
			var bb := mi.get_aabb()
			for ci in 8:
				var sp := cam.unproject_position(mi.global_transform * bb.get_endpoint(ci))
				tlo = tlo.min(sp)
				thi = thi.max(sp)
		var tr := Rect2(tlo, thi - tlo)
		var g := maxf(maxf(tr.position.x - cr8.end.x, cr8.position.x - tr.end.x), maxf(tr.position.y - cr8.end.y, cr8.position.y - tr.end.y))
		print("  CAULDRON rect %s | separation %.1f px %s" % [tr, g, "clear" if g >= 0.0 else "OVERLAP"])
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	_phone.image(root).save_png(out)
	quit()
