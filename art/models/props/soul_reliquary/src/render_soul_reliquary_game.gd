## Soul Reliquary in the REAL game camera + HUD (Bonfire3D framing via tools/capture_phone.gd) on the Hearth
## board. Places the reliquary at the board's Anchors/SoulReliquary* marker (pc / phone / portrait), hides the
## flat HUD Soul bar (after) or leaves the board untouched (before=1). Prints the prop's screen rect, the
## clearance to every HUD control, the candle row footprint (PR #142), the Nerve token (main spots + the v3
## portrait spot) and the cauldron, and (mask=1) renders the digits flat magenta so the numeral's ink height
## can be measured in px. Writes a crop around the prop too (crop=<png>). Not a test, not exported.
##   xvfb-run -a godot --path . --rendering-driver vulkan --resolution 1920x1080 \
##     --script res://art/models/props/soul_reliquary/src/render_soul_reliquary_game.gd -- [phone=844x390|390x844]
##     [out=<png>] [crop=<png>] [state=full|mid|low|lethal|grow] [before=1] [mask=1] [x=..] [y=..] [z=..] [yaw=..]
extends SceneTree

const HEARTH := "res://art/models/boards/hearth/scenes/hearth_board%s.tscn"
const RELIQ := "res://art/models/props/soul_reliquary/scenes/soul_reliquary%s.tscn"
const MARK := {"pc": "SoulReliquary", "phone": "SoulReliquaryPhone", "portrait": "SoulReliquaryPortrait"}
## the five gate states: [soul, max_soul, lethal]
const STATES := {"full": [35, 35, false], "mid": [18, 35, false], "low": [4, 35, false], "lethal": [3, 35, true],
	"grow": [39, 39, false]}
## candle row (PR #142) anchors + footprint in row-local space, for the keep-out check
const ROWS := {"pc": [Vector3(-0.40, 0.11, 0.578), 0.0, Vector3(1, 1, 1)], "phone": [Vector3(-0.51, 0.11, 0.61), 0.0, Vector3(1.218, 1.4, 1.4)],
	"portrait": [Vector3(1.11, 0.11, 0.275), 90.0, Vector3(1.218, 1.4, 1.4)]}
const ROW_LO := Vector3(-0.140, 0.0, -0.057)
const ROW_HI := Vector3(0.169, 0.115, 0.017)
## Nerve token spots (main v2 + the PR #145 v3 portrait), its footprint (rig 1.8 x cradle/tablet) for keep-out
const NERVE := {"pc": [[Vector3(0.48, 0.11, 0.578), 0.0]], "phone": [[Vector3(0.30, 0.11, 0.61), 0.0]],
	"portrait": [[Vector3(0.85, 0.11, -0.16), 90.0], [Vector3(1.08, 0.10, -0.26), 90.0]]}
const NERVE_LO := Vector3(-0.083, 0.0, -0.036)
const NERVE_HI := Vector3(0.083, 0.175, 0.036)
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


func _box_rect(cam: Camera3D, xf: Transform3D, lo: Vector3, hi: Vector3) -> Rect2:
	var pts := []
	for ci in 8:
		pts.append(xf * AABB(lo, hi - lo).get_endpoint(ci))
	return _rect(cam, pts)


func _run() -> void:
	_phone.parse_args()
	var out := "/workspace/dice/art/renders/soul_reliquary/v1/game_pc.png"
	var crop := ""
	var st := "mid"
	var before := false
	var mask := false
	var over := [INF, INF, INF]
	var yaw := INF
	var usc := INF
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
		if a.begins_with("crop="):
			crop = a.substr(5)
		if a.begins_with("state="):
			st = a.substr(6)
		if a == "before=1":
			before = true
		if a.begins_with("yaw="):
			yaw = float(a.substr(4))
		if a.begins_with("s="):
			usc = float(a.substr(2))
		if a == "mask=1":
			mask = true
		for i in 3:
			if a.begins_with("xyz"[i] + "="):
				over[i] = float(a.substr(2))
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
	var spot := ("portrait" if _phone.screen.y > _phone.screen.x else "phone") if mob else "pc"
	var anchor := board.get_node("Anchors/" + MARK[spot]) as Marker3D
	for i in 3:
		if over[i] != INF:
			anchor.position[i] = over[i]
	if yaw != INF:
		anchor.rotation_degrees.y = yaw
	if usc != INF:
		anchor.scale = Vector3.ONE * usc
	var rq: SoulReliquary = null
	if not before:
		s.soul_meter.visible = false          # the flat HUD bar is replaced by the reliquary
		rq = (load(RELIQ % lod) as PackedScene).instantiate() as SoulReliquary
		rq.reduced_motion = true
		anchor.add_child(rq)
		var sv: Array = STATES[st]
		rq.set_soul(sv[0], sv[1], false)
		rq.lethal = sv[2]
		if mask:
			var lbl := rq.get_node("Rig/Digits") as Label3D
			lbl.modulate = Color(1, 0, 1)
	await create_timer(0.3).timeout
	_phone.frame(s)
	s.camera.snap_home()
	for i in 8:
		await process_frame
	var cam := s.camera.cam
	var vs := cam.get_viewport().get_visible_rect().size
	print("GAME %s vp %s | spot %s marker %s at %s yaw %.0f | %s" % ["phone" if mob else "pc", vs, spot, MARK[spot],
		anchor.position, anchor.rotation_degrees.y, "BEFORE (flat bar)" if before else "state " + st])
	var all := Rect2()
	if rq != null:
		all = _rect(cam, _mesh_pts(rq))
		var lbl := rq.get_node("Rig/Digits") as Label3D
		print("  RELIQUARY rect %s (%s) %.1f x %.1f px | digits '%s' pixel_size %.5f" % [all, "on screen" if Rect2(Vector2.ZERO, vs).encloses(all) else "CROPPED",
			all.size.x, all.size.y, lbl.text, lbl.pixel_size])
		var dice := s.find_children("*", "DieVisual", true, false)
		if dice.size() > 0:
			var dr := _rect(cam, _mesh_pts(dice[0]))
			print("  die (in the tray) %.1f x %.1f px" % [dr.size.x, dr.size.y])
		var row: Array = ROWS[spot]
		var rr := _box_rect(cam, board.global_transform * Transform3D(Basis(Vector3.UP, deg_to_rad(row[1])).scaled(row[2]), row[0]), ROW_LO, ROW_HI)
		print("  CANDLE ROW footprint %s | separation %.1f px %s" % [rr, _gap(all, rr), "clear" if _gap(all, rr) >= 12.0 else "TIGHT"])
		for nv in NERVE[spot]:
			var nr := _box_rect(cam, board.global_transform * Transform3D(Basis(Vector3.UP, deg_to_rad(nv[1])), nv[0]), NERVE_LO, NERVE_HI)
			print("  NERVE TOKEN at %s rect %s | separation %.1f px %s" % [nv[0], nr, _gap(all, nr), "clear" if _gap(all, nr) >= 12.0 else "TIGHT"])
		var tray := board.get_node_or_null("Anchors/ChipTray/Tray")
		if tray != null:
			var tr := _rect(cam, _mesh_pts(tray))
			print("  CAULDRON rect %s | separation %.1f px %s" % [tr, _gap(all, tr), "clear" if _gap(all, tr) >= 12.0 else "TIGHT"])
		var cands := board.get_node_or_null("Hearth/Candles")
		if cands != null:
			var best := INF
			var bn := ""
			for c in cands.find_children("Candle*", "", true, false):
				var g := _gap(all, _rect(cam, _mesh_pts(c)))
				if g < best:
					best = g
					bn = c.name
			print("  RAIL CANDLES nearest %s | separation %.1f px %s" % [bn, best, "clear" if best >= 12.0 else "TIGHT"])
		for cn in ["Corner_NL", "Corner_NR"]:
			var cc := board.get_node_or_null("Anchors/%s/Cap" % cn)
			if cc != null:
				var cr2 := _rect(cam, _mesh_pts(cc))
				print("  %s cap | separation %.1f px" % [cn, _gap(all, cr2)])
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
	var img := _phone.image(root)
	img.save_png(out)
	if crop != "" and rq != null:
		var sc := Vector2(img.get_width(), img.get_height()) / vs
		var r := Rect2(all.position * sc, all.size * sc).grow(12.0 * sc.x).intersection(Rect2(Vector2.ZERO, Vector2(img.get_width(), img.get_height())))
		img.get_region(Rect2i(r)).save_png(crop)
		print("  CROP %s (image px %s, image/viewport scale %.3f)" % [crop, r, sc.x])
	quit()
