extends SceneTree
## Hearth detail pass renders (Oct 19): before / after (Hearth.dressing off / on) game-camera stills for PC
## and phone landscape, a 3/4 hero, close-ups, the 48 px dice read test (dressing on vs off, with metrics)
## and the ambient clip frames. Same stage as render_hearth.gd / render_smiles.gd: Lamp3D (reduced motion),
## burgundy rim, the game's a153087 camera (rig -55, tilt-up 7.5, FOV 36; PC d 2.40 pivot z 0.26, phone
## 844x390 d 2.04 pivot z 0.34), Smiles at the dealer spot. Everything is driven through the Hearth hooks.
## Not a test and not exported (art/*/src/ is excluded); needs a GPU (Vulkan) display, e.g. under xvfb-run:
##   xvfb-run -a godot --path . --rendering-driver vulkan --fixed-fps 30 \
##     --script res://art/models/boards/hearth/src/render_detail.gd -- --stills|--read|--ambient [--only=<name part>] [--out=<dir>] [--scratch=<dir>]
## --out: where the stills / sheets / logs go (default: the team render folder below, outside the repo).
## --scratch: the no-dice read frames (read_nodice_*.png, for brightness measurements) and the ambient
## frames (ambient_frames/%04d.png; encode with ffmpeg -framerate 30 -i %04d.png -c:v libx264 -pix_fmt yuv420p -crf 18).
var out := "/workspace/dice/art/renders/hearth/detail_pass/"
var scratch := "/tmp/hearth_render/"
const BOARD := "res://art/models/boards/hearth/scenes/hearth_board%s.tscn"
const SMILES := "res://art/models/characters/smiles/scenes/smiles%s.tscn"
const DEALER_POS := Vector3(-0.42, -0.47, -0.86)
const GAME := {"pot_step": 3, "eyes": 2, "fill": 0.6, "lit_count": 5, "seam": 0.6}
const FPS := 30.0
var mode := "stills"
var only := ""
var boards: Array[Node3D] = []
var log_lines: PackedStringArray = []

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--scratch="):
			scratch = a.substr(10)
		elif a.begins_with("--only="):
			only = a.substr(7)
		elif a.begins_with("--"):
			mode = a.substr(2)
	DirAccess.make_dir_recursive_absolute(out)
	DirAccess.make_dir_recursive_absolute(scratch)
	_run.call_deferred()

func _env() -> Environment:
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("#050405")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("#1A080C")
	e.ambient_light_energy = 0.25
	e.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	e.tonemap_mode = Environment.TONE_MAPPER_AGX
	e.tonemap_exposure = 1.1
	e.tonemap_white = 6.0
	e.fog_enabled = true
	e.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	e.fog_light_color = Color("#0E0B0C")
	e.fog_density = 0.12
	e.ssao_enabled = true
	e.ssao_radius = 0.25
	e.ssao_intensity = 1.6
	e.glow_enabled = true
	e.glow_intensity = 0.8
	e.glow_strength = 1.0
	e.glow_bloom = 0.05
	e.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	e.glow_hdr_threshold = 1.0
	e.glow_hdr_scale = 2.0
	for lvl in 7:
		e.set_glow_level(lvl, 1.0 if lvl in [1, 2, 3] else 0.0)
	e.adjustment_enabled = true
	e.adjustment_contrast = 1.08
	e.adjustment_saturation = 1.05
	return e

func _label(parent: Node, text: String, size: float) -> void:
	var l := Label3D.new()
	l.text = text
	l.font = load("res://fonts/AlfaSlabOne-Regular.ttf")
	l.font_size = 96
	l.pixel_size = size / 96.0
	l.modulate = Color("#E8DCC0")
	l.outline_modulate = Color("#0E1414")
	l.outline_size = 18
	l.position = Vector3(0, 0, 0.001)
	parent.add_child(l)

func _a153087(pivot: Vector3, d: float) -> Transform3D:
	var rig := Transform3D(Basis.from_euler(Vector3(deg_to_rad(-55), 0, 0)), pivot)
	return rig * Transform3D(Basis.from_euler(Vector3(deg_to_rad(7.5), 0, 0)), Vector3(0, 0, d))

func _look(from: Vector3, at: Vector3) -> Transform3D:
	return Transform3D(Basis.IDENTITY, from).looking_at(at, Vector3.UP)

const PC_CAM := [Vector3(0, 0, 0.26), 2.40]
const PHONE_CAM := [Vector3(0, 0, 0.34), 2.04]

## One viewport: board (+ dressing on/off), Smiles, Lamp3D + rim, optional dice and fill, camera.
func _stage(size: Vector2i, cam_xf: Transform3D, fov: float, dressing: bool, opts: Dictionary = {}) -> SubViewport:
	var mobile: bool = opts.get("mobile", false)
	var lod := "_mobile" if mobile else ""
	var vp := SubViewport.new()
	vp.size = size
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.own_world_3d = true
	root.add_child(vp)
	var we := WorldEnvironment.new()
	we.environment = _env()
	vp.add_child(we)
	var board := (load(BOARD % lod) as PackedScene).instantiate() as Node3D
	vp.add_child(board)
	boards.append(board)
	_label(board.get_node("Anchors/TargetPlate/Plate/NumberAnchor"), "21", 0.05)
	_label(board.get_node("Anchors/TotalPlate/Plate/NumberAnchor"), "14", 0.075)
	var fx := board.get_node("Hearth")
	var state: Dictionary = opts.get("state", GAME)
	for k in state:
		fx.set(k, state[k])
	fx.set("dressing", dressing)
	var pose: Dictionary = opts.get("pose", {})
	var d := board.get_node_or_null("Hearth/Dressing")
	if d != null:
		d.set("ambient", opts.get("ambient", false))  # stills: no scheduled peeks; poses are set by hand
		for k in pose:
			d.set(k, pose[k])
	if opts.get("smiles", true):
		var s := (load(SMILES % lod) as PackedScene).instantiate() as Node3D
		s.position = DEALER_POS
		vp.add_child(s)
	var lamp := Lamp3D.new()
	lamp.reduced_motion = true
	vp.add_child(lamp)
	var rim := DirectionalLight3D.new()
	rim.light_color = Color("#6E1A24")
	rim.light_energy = 0.6
	rim.rotation_degrees = Vector3(-20, 180, 0)
	vp.add_child(rim)
	if opts.get("dice", true):
		var spots := [Vector3(-0.25, 0.04, 0.05), Vector3(0.05, 0.04, -0.12), Vector3(0.32, 0.04, 0.18)]
		for i in spots.size():
			var die := DieVisual.new(0.08)
			die.position = spots[i]
			die.rotation_degrees = Vector3(0, 17 + i * 31, 0)
			vp.add_child(die)
	if opts.get("fill", false):
		var f := OmniLight3D.new()
		f.light_color = Color("#FFD8B0")
		f.light_energy = 0.45
		f.omni_range = 1.2
		f.position = cam_xf.origin + Vector3(0, 0.3, 0)
		vp.add_child(f)
	if opts.get("hero", false):
		# presentation only: a soft key from the camera side so the under-table dressing reads
		var k := OmniLight3D.new()
		k.light_color = Color("#FFB070")
		k.light_energy = 0.55
		k.omni_range = 4.5
		k.omni_attenuation = 1.2
		k.position = cam_xf.origin + Vector3(0.4, 0.2, -0.3)
		vp.add_child(k)
	var cam := Camera3D.new()
	cam.name = "Cam"
	cam.fov = fov
	cam.near = 0.02
	cam.far = 30.0
	cam.transform = cam_xf
	vp.add_child(cam)
	return vp

func _save(vp: SubViewport, name: String) -> Image:
	var img: Image = vp.get_texture().get_image()
	img.save_png(out.path_join(name))
	print("saved ", out.path_join(name))
	return img

func _settle(n: int = 24) -> void:
	for i in n:
		await process_frame

# --- stills -------------------------------------------------------------------------------------------

func _stills() -> void:
	var pc := _a153087(PC_CAM[0], PC_CAM[1])
	var ph := _a153087(PHONE_CAM[0], PHONE_CAM[1])
	var out_pose := {"tail_out": 1.0, "tail_sway": 0.35, "tail_curl": 0.5}
	var all := [
		["before_game_cam_pc.png", _stage(Vector2i(1920, 1080), pc, 36.0, false)],
		["after_game_cam_pc.png", _stage(Vector2i(1920, 1080), pc, 36.0, true)],
		["before_game_cam_phone.png", _stage(Vector2i(844, 390), ph, 36.0, false, {"mobile": true})],
		["after_game_cam_phone.png", _stage(Vector2i(844, 390), ph, 36.0, true, {"mobile": true})],
		["after_game_cam_pc_tail_out.png", _stage(Vector2i(1920, 1080), pc, 36.0, true, {"pose": out_pose})],
		["hero_34.png", _stage(Vector2i(1920, 1080), _look(Vector3(-2.35, 0.62, 1.45), Vector3(-0.3, -0.2, -0.2)), 38.0, true, {"pose": out_pose, "hero": true})],
		["closeup_far_left.png", _stage(Vector2i(1600, 900), _look(Vector3(-0.6, 0.3, -0.26), Vector3(-0.93, 0.11, -0.64)), 42.0, true, {"fill": true})],
		["closeup_far_right.png", _stage(Vector2i(1600, 900), _look(Vector3(0.6, 0.36, -0.22), Vector3(0.98, 0.1, -0.58)), 40.0, true, {"fill": true})],
		["closeup_left_rail_tail.png", _stage(Vector2i(1600, 900), _look(Vector3(-1.98, 0.32, 0.5), Vector3(-1.2, -0.02, -0.26)), 40.0, true, {"fill": true, "pose": out_pose})],
		["closeup_near_right.png", _stage(Vector2i(1600, 900), _look(Vector3(0.5, 0.34, 1.02), Vector3(1.06, 0.07, 0.48)), 40.0, true, {"fill": true})],
	]
	var jobs := []
	for j in all:
		if only == "" or (j[0] as String).contains(only):
			jobs.append(j)
		else:
			(j[1] as SubViewport).queue_free()
	await _settle()
	for j in jobs:
		_save(j[1], j[0])
	if only != "":
		return
	# before / after side by side (PC) for the review sheet
	var a := Image.load_from_file(out.path_join("before_game_cam_pc.png"))
	var b := Image.load_from_file(out.path_join("after_game_cam_pc.png"))
	var sheet := Image.create(1920, 1080 * 2, false, a.get_format())
	sheet.blit_rect(a, Rect2i(0, 0, 1920, 1080), Vector2i.ZERO)
	sheet.blit_rect(b, Rect2i(0, 0, 1920, 1080), Vector2i(0, 1080))
	sheet.resize(1280, 1440, Image.INTERPOLATE_LANCZOS)
	sheet.save_png(out.path_join("before_after_pc_sheet.png"))

# --- 48 px dice read test -----------------------------------------------------------------------------

## Dice on the felt (incl. over the wear marks: scorch rings, pocks, scuff arc), game camera, dressing on
## vs off; for each die: silhouette contrast vs the felt around it and face / pip contrast inside it,
## from a with-dice minus no-dice mask. Tiles are rescaled so each die is 48 px.
const READ_DICE := [["bone_d6", Vector3(0.0, 0.04, -0.42), 5], ["hellfire_d6", Vector3(-0.42, 0.04, -0.34), 3], ["bone_d6", Vector3(0.78, 0.04, -0.3), 6],
	["gilded_d6", Vector3(-0.8, 0.04, 0.31), 4], ["bone_d6", Vector3(0.0, 0.04, 0.05), 2], ["blood_pact_d6", Vector3(0.42, 0.04, 0.3), 1],
	["wanderer_d6", Vector3(-0.9, 0.04, 0.18), 3], ["bone_d6", Vector3(0.9, 0.04, 0.42), 4], ["last_breath_d6", Vector3(0.3, 0.04, -0.4), 2], ["bone_d6", Vector3(-0.3, 0.04, 0.4), 1]]

func _face_basis(v: int, yaw: float) -> Basis:
	var b := Basis.IDENTITY
	match v:
		6: b = Basis(Vector3.RIGHT, PI)
		2: b = Basis(Vector3.BACK, PI / 2)
		5: b = Basis(Vector3.BACK, -PI / 2)
		3: b = Basis(Vector3.RIGHT, -PI / 2)
		4: b = Basis(Vector3.RIGHT, PI / 2)
	return Basis(Vector3.UP, yaw) * b

func _dice(vp: SubViewport) -> Node3D:
	var n := Node3D.new()
	n.name = "ReadDice"
	vp.add_child(n)
	for i in READ_DICE.size():
		var s: Array = READ_DICE[i]
		var scn := (load("res://art/models/dice/%s.glb" % s[0]) as PackedScene).instantiate() as Node3D
		scn.transform = Transform3D(_face_basis(s[2], deg_to_rad(12 + i * 23)), s[1])
		n.add_child(scn)
	return n

func _luma(c: Color) -> float:
	return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b

func _read() -> void:
	var views := [["pc", Vector2i(1920, 1080), _a153087(PC_CAM[0], PC_CAM[1]), false], ["phone", Vector2i(844, 390), _a153087(PHONE_CAM[0], PHONE_CAM[1]), true]]
	var vps := {}
	for v in views:
		for on in [false, true]:
			var vp := _stage(v[1], v[2], 36.0, on, {"mobile": v[3], "dice": false})
			_dice(vp)
			vps[[v[0], on]] = vp
	await _settle()
	var imgs := {}
	for k in vps:
		imgs[[k[0], k[1], true]] = (vps[k] as SubViewport).get_texture().get_image()
	for k in vps:
		(vps[k] as SubViewport).get_node("ReadDice").visible = false
	await _settle(6)
	for k in vps:
		imgs[[k[0], k[1], false]] = (vps[k] as SubViewport).get_texture().get_image()
	var worst := 1e9
	for v in views:
		var cam := (vps[[v[0], true]] as SubViewport).get_node("Cam") as Camera3D
		var tile := 120  # crop = 2.5 die widths -> the die is 48 px in the tile
		var sheet := Image.create(tile * READ_DICE.size(), tile * 2, false, Image.FORMAT_RGB8)
		log_lines.append("[%s %dx%d] die silhouette contrast (|die - felt ring| luma) / face-pip contrast (p90 - p10 luma inside the die), off -> on" % [v[0], v[1].x, v[1].y])
		for i in READ_DICE.size():
			var p: Vector3 = READ_DICE[i][1]
			var c := cam.unproject_position(p)
			var w := cam.unproject_position(p + Vector3(0.04, 0, 0)).x - cam.unproject_position(p - Vector3(0.04, 0, 0)).x
			var half := int(ceil(w * 1.25))
			var r := Rect2i(Vector2i(c) - Vector2i(half, half), Vector2i(half * 2, half * 2))
			var m := {}
			for on in [false, true]:
				var with: Image = imgs[[v[0], on, true]]
				var without: Image = imgs[[v[0], on, false]]
				var inside: Array[float] = []
				var ring := 0.0
				var rn := 0
				for y in range(r.position.y, r.end.y):
					for x in range(r.position.x, r.end.x):
						var a := with.get_pixel(x, y)
						var b := without.get_pixel(x, y)
						# the die body (not its soft glow halo / contact shadow): a strong change vs the no-dice frame
						if absf(_luma(a) - _luma(b)) > 0.15 or Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length() > 0.22:
							inside.append(_luma(a))
						else:
							ring += _luma(a)
							rn += 1
				inside.sort()
				var mean := 0.0
				for q in inside:
					mean += q
				mean /= maxf(1.0, inside.size())
				var sil := absf(mean - ring / maxf(1.0, rn))
				var pip := inside[int(inside.size() * 0.9)] - inside[int(inside.size() * 0.1)] if inside.size() > 10 else 0.0
				m[on] = [sil, pip, inside.size()]
				var crop := (with as Image).get_region(r)
				crop.convert(Image.FORMAT_RGB8)
				crop.resize(tile, tile, Image.INTERPOLATE_LANCZOS)
				sheet.blit_rect(crop, Rect2i(0, 0, tile, tile), Vector2i(i * tile, (1 if on else 0) * tile))
			var diff := 0.0
			var dn := 0
			var won: Image = imgs[[v[0], true, true]]
			var woff: Image = imgs[[v[0], false, true]]
			for y in range(r.position.y, r.end.y):
				for x in range(r.position.x, r.end.x):
					var a := won.get_pixel(x, y)
					var b := woff.get_pixel(x, y)
					diff += (absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)) / 3.0
					dn += 1
			m["diff"] = diff / maxf(1.0, dn) * 255.0
			var ds: float = (m[true][0] - m[false][0]) / maxf(m[false][0], 1e-3) * 100.0
			var dp: float = (m[true][1] - m[false][1]) / maxf(m[false][1], 1e-3) * 100.0
			worst = minf(worst, minf(ds, dp))
			log_lines.append("  %-15s at (%.2f, %.2f) %4.1f px  silhouette %.3f -> %.3f (%+.1f%%)  pips %.3f -> %.3f (%+.1f%%)  die mask %d/%d px  crop on-off mean |dRGB| %.2f/255" % [READ_DICE[i][0], p.x, p.z, w,
				m[false][0], m[true][0], ds, m[false][1], m[true][1], dp, m[false][2], m[true][2], m["diff"]])
		sheet.save_png(out.path_join("read_test_48px_%s.png" % v[0]))
		print("saved ", out.path_join("read_test_48px_%s.png" % v[0]))
		for on in [false, true]:
			(imgs[[v[0], on, true]] as Image).save_png(out.path_join("read_test_game_cam_%s_%s.png" % [v[0], "on" if on else "off"]))
			(imgs[[v[0], on, false]] as Image).save_png(scratch.path_join("read_nodice_%s_%s.png" % [v[0], "on" if on else "off"]))
	log_lines.append("worst change (dressing on vs off): %+.1f%% (rows: top = dressing off, bottom = on; 120 px tiles = 2.5 die widths, die = 48 px). Silhouette / pip deltas come from the die mask (with-dice minus no-dice frame); where they move, the on-off |dRGB| of the with-dice crop shows the drawn pixels are unchanged (the wear under a die shifts the mask edge only)" % worst)
	var f := FileAccess.open(out.path_join("read_test_48px_log.txt"), FileAccess.WRITE)
	f.store_string("\n".join(log_lines) + "\n")
	print("\n".join(log_lines))

# --- ambient ------------------------------------------------------------------------------------------

## 18 s at 30 fps, every frame: game camera (PC framing, 1280x720) on top, two insets below (left rail:
## tail + chain; the brazier: embers + lamp dust). Tail peeks at 2.0 s and 11.0 s (9 s apart), scoring
## from 12.0 s to 14.8 s (the second peek whips back and none starts while scoring), rail hits at 4.6,
## 5.3, 8.0, 15.6 s, Smiles' bell (far-right cluster since v2) at 6.6 s.
func _ambient() -> void:
	var dir := scratch.path_join("ambient_frames") + "/"
	DirAccess.make_dir_recursive_absolute(dir)
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + f)
	var views := [[Vector2i(1280, 720), _a153087(PC_CAM[0], PC_CAM[1]), 36.0, false, Vector2i(0, 0)],
		[Vector2i(640, 360), _look(Vector3(-1.98, 0.32, 0.5), Vector3(-1.2, -0.02, -0.26)), 40.0, true, Vector2i(0, 720)],
		# v2: the bell moved to the far-right cluster, so this view frames the brazier embers + dust AND the bell
		[Vector2i(640, 360), _look(Vector3(0.42, 0.52, 0.12), Vector3(0.42, 0.24, -0.7)), 46.0, true, Vector2i(640, 720)]]
	var vps: Array[SubViewport] = []
	for v in views:
		vps.append(_stage(v[0], v[1], v[2], true, {"fill": v[3], "ambient": true}))
	for b in boards:
		b.get_node("Hearth/Dressing").call("set_next_peek", 1000.0)
	await _settle(6)
	var n := int(18.0 * FPS)
	var events := {int(2.0 * FPS): "peek", int(11.0 * FPS): "peek", int(12.0 * FPS): "score_on", int(14.8 * FPS): "score_off",
		int(4.6 * FPS): "hit1", int(5.3 * FPS): "hit2", int(8.0 * FPS): "hit3", int(15.6 * FPS): "hit4", int(6.6 * FPS): "bell"}
	var hits := {"hit1": 1.0, "hit2": 0.6, "hit3": 1.3, "hit4": 0.8}
	for f in n:
		if events.has(f):
			var e: String = events[f]
			for b in boards:
				var fx := b.get_node("Hearth")
				var d := b.get_node("Hearth/Dressing")
				match e:
					"peek":
						d.call("set_next_peek", 0.0)
					"score_on":
						fx.set("scoring", true)
					"score_off":
						fx.set("scoring", false)
						d.call("set_next_peek", 1000.0)
					"bell":
						fx.call("bell_ring")
					_:
						fx.call("rail_hit", hits[e])
			log_lines.append("%5.2f s  %s" % [f / FPS, e])
		if f > 0 and events.has(f - 1) and events[f - 1] == "peek":
			for b in boards:
				b.get_node("Hearth/Dressing").call("set_next_peek", 1000.0)
		await RenderingServer.frame_post_draw
		var frame := Image.create(1280, 1080, false, Image.FORMAT_RGBA8)
		for i in vps.size():
			var img: Image = vps[i].get_texture().get_image()
			img.convert(Image.FORMAT_RGBA8)
			frame.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), views[i][4])
		frame.save_png(dir + "%04d.png" % f)
	var lf := FileAccess.open(out.path_join("ambient_timeline.txt"), FileAccess.WRITE)
	lf.store_string("ambient.mp4: 18 s, 30 fps, every frame rendered (top: game camera PC framing; bottom left: left rail tail + chain; bottom right: brazier embers + lamp dust + Smiles' bell in the far-right cluster)\n" + "\n".join(log_lines) + "\n")
	print("frames ", n, " -> ", dir)

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(out)
	match mode:
		"stills":
			await _stills()
		"read":
			await _read()
		"ambient":
			await _ambient()
	quit(0)
