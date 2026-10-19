## Trigger FX capture (trigger_fx_spec.md section 3): the four first rows on
## the real Bonfire table and camera, driven through a stand-in TableEvents
## (`mod_triggered`) until Godot Dev's lands. One fresh table per shot:
##   1 mirror_copy (LAND)  2 gilded_payout (PIP)  3 coin_heads_copy (LAND)
##   4 hellfire_face, flavour verdict (PIP)
## PIP triggers start 2 frames before the die's own count-up pip (spec 1.3,
## from the count-up plan), so the f2/f3 hit lands on or just after it.
## Prints "SHOT <hook> <start_s> <hit_s> <end_s>" (movie time) for cutting,
## and writes trig_<hook>_frames.png (f0-f7 strip + a row scaled so the die
## is 48 px) to --out.
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-driver vulkan \\
##       --resolution 1280x720 --fixed-fps 30 --write-movie /tmp/trig.avi \\
##       --script res://tools/capture_trigger_fx.gd -- --out=/tmp/trigger_fx/
## The special dice wear their real models, never a tinted body: Mirror and
## Gilded use the d6 models on main (art/models/dice/*_d6.glb, same face
## axes as DieVisual, so the pips stay); Ferryman's Coin and Verdict use the
## batch-3 models from PR #102 (art/models/dice/ferryman_d2.glb,
## verdict_d20.glb), shown heads / 20 up. #102 isn't in this branch: check
## its art/models/dice files out into the capture worktree only (see the PR).
## The rules still roll the d6 under it (the face turns are FX overlays,
## TODO(tween_to_face)).
extends SceneTree

const FPS: float = 30.0
const STRIP_CELL: int = 220

var OUT := "user://captures_trigger_fx/"
var _frame: int = 0


func _initialize() -> void:
	process_frame.connect(func() -> void: _frame += 1)
	_run.call_deferred()


func now() -> float:
	return _frame / FPS


func wait(t: float) -> void:
	await create_timer(t, true, false, true).timeout


func _events() -> Node:
	var ev := Node.new()
	ev.name = "StandInEvents"
	ev.add_user_signal("mod_triggered", [{"name": "row_id", "type": TYPE_STRING_NAME}, {"name": "tier", "type": TYPE_INT},
			{"name": "die_id", "type": TYPE_INT}, {"name": "intensity", "type": TYPE_FLOAT}, {"name": "hit_ms", "type": TYPE_INT},
			{"name": "anchor", "type": TYPE_STRING_NAME}, {"name": "ctx", "type": TYPE_DICTIONARY}])
	return ev


func _run() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			OUT = a.trim_prefix("--out=").trim_suffix("/") + "/"
	DirAccess.make_dir_recursive_absolute(OUT)
	await _shot(&"mirror_copy", [5, 5, 2, 5], 3, "mirror_d6", &"LAND", {"source": 1}, [0, 1, 3])
	await _shot(&"gilded_payout", [4, 4, 6, 2], 1, "gilded_d6", &"PIP", {}, [0, 1])
	await _shot(&"coin_heads_copy", [6, 3, 2, 6], 3, "ferryman_d2", &"LAND", {"source": 0}, [0, 3])
	await _shot(&"hellfire_face", [2, 3, 6, 5], 3, "verdict_d20", &"PIP", {"flavor": &"verdict"}, [3])
	quit()


func _shot(id: StringName, faces: Array, die_i: int, model: String, anchor: StringName, ctx: Dictionary, pot: Array) -> void:
	var t := load("res://resources/tuning/bonfire_tuning.tres") as BonfireTuning
	var s := (load("res://scenes/bonfire.tscn") as PackedScene).instantiate() as Bonfire3D
	s.setup = TableSetup.sandbox(t, faces.size())
	s.tutorial_override = 0
	root.add_child(s)
	await wait(0.6)
	var ev := _events()
	s.add_child(ev)
	var fx := s.get_node("TriggerFx") as TriggerFx
	var audio := s.get_node("TableAudio") as TableAudio
	audio.bind(ev, s.sfx)
	fx.bind(ev, s)
	fx.audio = audio
	var die := s.all_dice[die_i]
	var ff: Array[int] = []
	ff.assign(faces)
	s.rig_faces(ff)
	if model.ends_with("_d6"):
		_skin_d6(die, model)
	s.quick_throw()
	await s.throw_resolved
	await s.sequence_finished
	if not model.ends_with("_d6"):
		_skin_batch3(die, model, s.camera.cam)
	var start := now()
	await wait(0.4)
	var hit_at := [0.0]
	fx.hit.connect(func(_id: StringName, _d: Node3D) -> void: hit_at[0] = now(), CONNECT_ONE_SHOT)
	var c := ctx.duplicate()
	if anchor == &"LAND":
		ev.emit_signal("mod_triggered", id, 0, die_i, 1.0, 0, anchor, c)
		await _strip(id, s, die)
		await wait(0.3)
	for i: int in pot:
		s.pick_die(i)
	await wait(0.25)
	s.throw_again()
	if anchor == &"PIP":
		var pips: Array = s.bhud.countup.plan.get("pips", [])
		var pi := 0
		for k in pips.size():
			if s._pip_die[k] >= 0 and s._pip_die[k] < s._juice_dice.size() and s._juice_dice[s._pip_die[k]] == die:
				pi = k
		var lead := maxf(0.0, float(pips[pi]) - TriggerFxDefs.hit_time(id)) if pips.size() > 0 else 0.0
		await wait(lead)
		ev.emit_signal("mod_triggered", id, 1, die_i, 1.0, 0, anchor, c)
		await _strip(id, s, die)
	await s.bhud.countup.finished
	await wait(0.5)
	print("SHOT %s %.3f %.3f %.3f" % [id, start, hit_at[0], now()])
	s.queue_free()
	await wait(0.3)


func _model_mesh(model: String) -> MeshInstance3D:
	var path := "res://art/models/dice/%s.glb" % model
	if not ResourceLoader.exists(path):
		push_error("capture: %s missing (check PR #102's art/models/dice out into this worktree)" % path)
		return null
	var scene := (load(path) as PackedScene).instantiate()
	var mi := scene.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var out := MeshInstance3D.new()
	out.mesh = mi.mesh
	for i in mi.get_surface_override_material_count():
		out.set_surface_override_material(i, mi.get_surface_override_material(i))
	scene.free()
	return out


## Mirror / Gilded: the special d6 model replaces the Bone body (same face
## axes and pips, so the rules' face shows).
func _skin_d6(die: DieVisual, model: String) -> void:
	var m := _model_mesh(model)
	if m == null:
		return
	var body := die.faces.get_node("Body") as MeshInstance3D
	body.mesh = m.mesh
	body.material_override = null
	for i in m.get_surface_override_material_count():
		body.set_surface_override_material(i, m.get_surface_override_material(i))
	m.free()


## Coin / Verdict: the batch-3 model sits in the faces node (so the FX beat
## moves it), heads / 20 up with its numeral upright to the camera; the d6
## body and pips are hidden. The coin rests on the felt (it's 24 mm thick).
func _skin_batch3(die: DieVisual, model: String, cam: Camera3D) -> void:
	var m := _model_mesh(model)
	if m == null:
		return
	for c in die.faces.get_children():
		if c is Node3D:
			(c as Node3D).visible = false
	die.faces.add_child(m)
	# Heads (coin 1) and the 20 both face +Y at rest; turn the numeral's up
	# (batch3_faces.json) toward the top of the screen.
	var up := Vector3(0.86603, 0.0, -0.5) if model == "verdict_d20" else Vector3(0, 0, -1)
	var screen_up := -cam.global_basis.z
	screen_up.y = 0.0
	var yaw := atan2(up.x, up.z) - atan2(screen_up.x, screen_up.z)
	var g := Transform3D(Basis(Vector3.UP, -yaw), die.global_position)
	if model == "ferryman_d2":
		g.origin.y = 0.012
	m.global_transform = g


## f0-f7 at the game camera (crops around the die), plus the same frames
## scaled so the die is 48 px (spec 0: readable at 48 px).
func _strip(id: StringName, s: Bonfire3D, die: DieVisual) -> void:
	var cam := s.camera.cam
	var t0 := now()
	var cells: Array[Image] = []
	for f in 8:
		while now() < t0 + f / 12.0 - 0.001:
			await process_frame
		await RenderingServer.frame_post_draw
		var img := root.get_texture().get_image()
		# unproject is in viewport (2D base) units; the image is window pixels.
		var p := cam.unproject_position(die.global_position) * Vector2(img.get_size()) / root.get_visible_rect().size
		var r := Rect2i(Vector2i(p) - Vector2i.ONE * (STRIP_CELL / 2), Vector2i.ONE * STRIP_CELL)
		r = r.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
		var cell := img.get_region(r)
		cell.convert(Image.FORMAT_RGBA8)
		cells.append(cell)
	var px := cam.unproject_position(die.global_position).distance_to(cam.unproject_position(die.global_position + cam.global_basis.x * die.edge))
	px *= float(root.get_texture().get_image().get_width()) / root.get_visible_rect().size.x
	var k := 48.0 / maxf(px, 1.0)
	var small := int(STRIP_CELL * k)
	var out := Image.create(STRIP_CELL * cells.size(), STRIP_CELL + small, false, Image.FORMAT_RGBA8)
	out.fill(Color("#0E1414"))
	for f in cells.size():
		var cimg := cells[f]
		out.blit_rect(cimg, Rect2i(Vector2i.ZERO, cimg.get_size()), Vector2i(f * STRIP_CELL, 0))
		var sm := cimg.duplicate() as Image
		sm.resize(maxi(1, int(cimg.get_width() * k)), maxi(1, int(cimg.get_height() * k)), Image.INTERPOLATE_BILINEAR)
		out.blit_rect(sm, Rect2i(Vector2i.ZERO, sm.get_size()), Vector2i(f * STRIP_CELL, STRIP_CELL))
	out.save_png(OUT + "trig_%s_frames.png" % id)
	print("saved %strig_%s_frames.png (die %.0f px, 48 px row x%.2f)" % [OUT, id, px, k])
