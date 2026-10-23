## Candle row renders (Forward+): game-camera stills with the Hearth board (PC + phone), the 48 px phone
## state strip, a close-up sheet, and brightness metrics (row p97 luma vs the dice p97). Reuses the Hearth
## detail-pass stage (render_detail.gd). Not a test, not exported. Needs Vulkan, e.g.:
##   xvfb-run -a godot --path . --rendering-driver vulkan --fixed-fps 30 \
##     --script res://art/models/props/candle_row/src/render_candle_row.gd -- [--out=<dir>]
extends "res://art/models/boards/hearth/src/render_detail.gd"

const ROW := "res://art/models/props/candle_row/scenes/candle_row%s.tscn"
const ROW_AT := Vector3(-0.50, 0.11, 0.61)   # v2: = Hearth Anchors/CandleRow (make_hearth.gd CANDLE_ROW_AT)
const K := {false: 1.0, true: 1.4}            # make_candle_row.gd ROW_SCALE (PC, mobile)
## [label, hands, delta, hands_left, extra]
const STATES := [["4 of 4 lit", 4, 0, 4, ""], ["bank: 3 of 4", 4, 0, 3, "snuff"], ["bust: drip 0.25 s", 4, 0, 3, "bust"],
	["bust: bead (end)", 4, 0, 3, "bead"], ["last hand: gutter", 4, 0, 1, ""], ["Ashmouth -1", 3, -1, 3, ""],
	["Bodkin +1: ring", 5, 1, 5, ""], ["8 lit", 8, 0, 8, ""], ["10 hands: >8 cue ring", 10, 0, 10, ""], ["table end", 4, 0, 0, ""]]


func _add_row(vp: SubViewport, mobile: bool, st: Array) -> Node3D:
	var row := (load(ROW % ("_mobile" if mobile else "")) as PackedScene).instantiate() as Node3D
	row.name = "CandleRow"
	row.position = ROW_AT
	vp.add_child(row)
	row.reduced_motion = true
	row.call("table_start", st[1], st[2])
	row.set("hands_left", st[1])
	for i in st[1] - st[3]:
		row.call("spend", false)
	return row


## Freeze a clip mid-way on the candle that was just spent (stills only).
func _pose(row: Node3D, st: Array) -> void:
	var extra: String = st[4]
	if extra == "":
		return
	var i: int = st[3] if extra != "rise" else st[1] - 1
	var c := row.get_node("Sockets/Socket%d/Candle" % (i + 1))
	var ap := c.get_node("AnimationPlayer") as AnimationPlayer
	if extra == "snuff":
		c.state = 1
		ap.play(&"snuff")
		ap.seek(0.33, true)
	elif extra == "bust":
		c.state = 1
		ap.play(&"snuff_bust")
		ap.seek(0.25, true)
	elif extra == "bead":
		c.state = 1
		ap.play(&"snuff_bust")
		ap.seek(1.25, true)
		ap.stop()
		c.state = CandleRowCandle.State.COLD  # the clip-end handler (animation_finished) as in game
		c.drip = 1.0
		c.bead = 1.0
		c.wisp = 1.0
	elif extra == "rise":
		ap.play(&"rise_in")
		ap.seek(0.2, true)
	ap.pause()


func _rect_of(cam: Camera3D, pts: Array, pad: int) -> Rect2i:
	var lo := Vector2(1e9, 1e9)
	var hi := Vector2(-1e9, -1e9)
	for p in pts:
		var s := cam.unproject_position(p)
		lo = lo.min(s)
		hi = hi.max(s)
	return Rect2i(Vector2i(lo) - Vector2i(pad, pad), Vector2i(hi - lo) + Vector2i(pad * 2, pad * 2))


func _row_pts(k := 1.0) -> Array:
	var half := (0.058 * 4 + 0.01) * k
	return [ROW_AT + Vector3(-half, 0, 0.02 * k), ROW_AT + Vector3(half, 0, -0.02 * k), ROW_AT + Vector3(-half, 0.12 * k, 0), ROW_AT + Vector3(half, 0.12 * k, 0)]


func _p97(img: Image, ref: Image, r: Rect2i) -> Array:
	var l: Array[float] = []
	for y in range(maxi(r.position.y, 0), mini(r.end.y, img.get_height())):
		for x in range(maxi(r.position.x, 0), mini(r.end.x, img.get_width())):
			var a := img.get_pixel(x, y)
			var b := ref.get_pixel(x, y)
			if Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length() > 0.08:
				l.append(_luma(a))
	l.sort()
	if l.size() < 10:
		return [0.0, 0.0, l.size()]
	return [l[int(l.size() * 0.97)], l[int(l.size() * 0.5)], l.size()]


func _run() -> void:
	out = "/workspace/dice/art/renders/candle_row/v2/"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	var pc := _a153087(PC_CAM[0], PC_CAM[1])
	var ph := _a153087(PHONE_CAM[0], PHONE_CAM[1])
	var game := ["bank: 3 of 4", 4, 0, 3, ""]
	# 1. game camera stills (dressing on, dice on the felt), + no-row / no-dice frames for metrics
	var views := [["pc", Vector2i(1920, 1080), pc, false], ["phone", Vector2i(844, 390), ph, true]]
	var vps := {}
	for v in views:
		var vp := _stage(v[1], v[2], 36.0, true, {"mobile": v[3]})
		_add_row(vp, v[3], game)
		vps[v[0]] = vp
	await _settle(30)
	var shots := {}
	for v in views:
		shots[[v[0], "row"]] = _save(vps[v[0]], "game_cam_%s.png" % v[0])
	for v in views:
		(vps[v[0]] as SubViewport).get_node("CandleRow").visible = false
	await _settle(6)
	for v in views:
		shots[[v[0], "norow"]] = (vps[v[0]] as SubViewport).get_texture().get_image()
		for c in (vps[v[0]] as SubViewport).get_children():
			if c is DieVisual:
				c.visible = false
	await _settle(6)
	for v in views:
		shots[[v[0], "nodice"]] = (vps[v[0]] as SubViewport).get_texture().get_image()
		var cam := (vps[v[0]] as SubViewport).get_node("Cam") as Camera3D
		var kk: float = K[v[3]]
		var rr := _rect_of(cam, _row_pts(kk), 6)
		var row_m := _p97(shots[[v[0], "row"]], shots[[v[0], "norow"]], rr)
		var dice_m := _p97(shots[[v[0], "norow"]], shots[[v[0], "nodice"]], Rect2i(Vector2i.ZERO, v[1]))
		var px := cam.unproject_position(ROW_AT + Vector3(0.029 * kk, 0, 0)).x - cam.unproject_position(ROW_AT - Vector3(0.029 * kk, 0, 0)).x
		log_lines.append("[%s %dx%d] row rect %s, socket pitch %.1f px, candle h %.1f px | row p97 luma %.3f (median %.3f, %d px) vs dice p97 %.3f (median %.3f) -> row/dice p97 %.0f%%" % [v[0], v[1].x, v[1].y, rr, px,
			cam.unproject_position(ROW_AT).y - cam.unproject_position(ROW_AT + Vector3(0, 0.081 * kk, 0)).y, row_m[0], row_m[1], row_m[2], dice_m[0], dice_m[1], row_m[0] / maxf(dice_m[0], 1e-3) * 100.0])
		(shots[[v[0], "row"]] as Image).get_region(rr.grow(40)).save_png(out.path_join("game_cam_%s_row_crop.png" % v[0]))
		var lit_only := _p97(shots[[v[0], "row"]], shots[[v[0], "norow"]], rr)
	for v in views:
		(vps[v[0]] as SubViewport).queue_free()
	await _settle(2)
	# 2. 48 px phone strip: phone game camera, each state; tile scaled so a die (0.08 m) = 48 px
	var svps: Array = []
	for st in STATES:
		var vp := _stage(Vector2i(844, 390), ph, 36.0, true, {"mobile": true, "dice": false, "smiles": false})
		var row := _add_row(vp, true, st)
		_pose(row, st)
		svps.append(vp)
	await _settle(4)
	for i in STATES.size():
		var row := (svps[i] as SubViewport).get_node("CandleRow")
		_pose(row, STATES[i])
	await _settle(2)
	var cam0 := (svps[0] as SubViewport).get_node("Cam") as Camera3D
	var r := _rect_of(cam0, _row_pts(1.4), 4)
	var die_px := cam0.unproject_position(ROW_AT + Vector3(0.04, 0, 0)).x - cam0.unproject_position(ROW_AT - Vector3(0.04, 0, 0)).x
	var k := 48.0 / die_px
	var tw := int(r.size.x * k)
	var th := int(r.size.y * k)
	var strip := Image.create(tw, (th + 14) * STATES.size(), false, Image.FORMAT_RGB8)
	var native := Image.create(r.size.x, r.size.y * STATES.size(), false, Image.FORMAT_RGB8)
	for i in STATES.size():
		var img := (svps[i] as SubViewport).get_texture().get_image().get_region(r)
		img.convert(Image.FORMAT_RGB8)
		native.blit_rect(img, Rect2i(Vector2i.ZERO, r.size), Vector2i(0, i * r.size.y))
		img.resize(tw, th, Image.INTERPOLATE_LANCZOS)
		strip.blit_rect(img, Rect2i(0, 0, tw, th), Vector2i(0, i * (th + 14) + 14))
	strip.save_png(out.path_join("phone_strip_48px.png"))
	native.save_png(out.path_join("phone_strip_native.png"))
	log_lines.append("[phone strip] row crop %s at 844x390, die %.1f px native -> x%.2f (die = 48 px); rows top->bottom: %s" % [r, die_px, k, ", ".join(STATES.map(func(s): return s[0]))])
	for vp in svps:
		vp.queue_free()
	await _settle(2)
	# 3. close-up sheet (PC LOD): from the player side, above the near rail (same left-right as the game camera)
	var cvps: Array = []
	var eye := ROW_AT + Vector3(0.0, 0.36, 0.62)
	for st in STATES:
		var vp := _stage(Vector2i(640, 400), _look(eye, ROW_AT + Vector3(0, 0.03, 0)), 36.0, true, {"dice": false, "smiles": false})
		var row := _add_row(vp, false, st)
		_pose(row, st)
		cvps.append(vp)
	await _settle(4)
	for i in STATES.size():
		_pose((cvps[i] as SubViewport).get_node("CandleRow"), STATES[i])
	await _settle(2)
	var sheet := Image.create(640 * 4, 400 * 3, false, Image.FORMAT_RGB8)
	for i in STATES.size():
		var img := (cvps[i] as SubViewport).get_texture().get_image()
		img.convert(Image.FORMAT_RGB8)
		sheet.blit_rect(img, Rect2i(0, 0, 640, 400), Vector2i((i % 4) * 640, (i / 4) * 400))
		img.save_png(out.path_join("closeup_%d.png" % i))
	sheet.save_png(out.path_join("closeup_sheet.png"))
	var lf := FileAccess.open(out.path_join("metrics.txt"), FileAccess.WRITE)
	lf.store_string("\n".join(log_lines) + "\n")
	print("\n".join(log_lines))
	quit(0)
