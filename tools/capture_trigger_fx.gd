## Trigger FX capture (trigger_fx_spec.md section 3): the four first rows on
## the real Bonfire table and camera, driven through a stand-in TableEvents
## (`mod_triggered`) until Godot Dev's lands. One fresh table per shot:
##   1 mirror_copy (LAND)  2 gilded_payout (PIP)  3 coin_heads_copy (LAND)
##   4 hellfire_face, flavour verdict (PIP)
## PIP triggers start 2 frames before the die's own count-up pip (spec 1.3,
## from the count-up plan), so the f2/f3 hit lands on or just after it.
## Prints "SHOT <hook> <start_s> <hit_s> <end_s>" (movie time) for cutting,
## and writes trig_<hook>_frames.png (f0-f6 strip + a 48 px row) to --out.
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-driver vulkan \\
##       --resolution 1280x720 --fixed-fps 30 --write-movie /tmp/trig.avi \\
##       --script res://tools/capture_trigger_fx.gd -- --out=/tmp/trigger_fx/
## The special dice are tinted Bone d6 stand-ins (the Coin and d20 shapes
## aren't on main yet), and the Mirror's face turn is a flip overlay.
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
	await _shot(&"mirror_copy", [5, 5, 2, 5], 3, Color("#C9D2D6"), &"LAND", {"source": 1}, [0, 1, 3])
	await _shot(&"gilded_payout", [4, 4, 6, 2], 1, Color("#C9A24E"), &"PIP", {}, [0, 1])
	await _shot(&"coin_heads_copy", [6, 3, 2, 6], 3, Color("#8E9196"), &"LAND", {"source": 0}, [0, 3])
	await _shot(&"hellfire_face", [2, 3, 6, 5], 3, Color("#5A1620"), &"PIP", {"flavor": &"verdict"}, [3])
	quit()


func _shot(id: StringName, faces: Array, die_i: int, tint: Color, anchor: StringName, ctx: Dictionary, pot: Array) -> void:
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
	die.set_look(tint, TriggerFxDefs.BONE if tint.v < 0.5 else Palette.PIT_BLACK, [1, 2, 3, 4, 5, 6])
	var ff: Array[int] = []
	ff.assign(faces)
	s.rig_faces(ff)
	s.quick_throw()
	await s.throw_resolved
	await s.sequence_finished
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


## f0-f6 at the game camera (crops around the die), plus the same frames
## scaled so the die is 48 px (spec 0: readable at 48 px).
func _strip(id: StringName, s: Bonfire3D, die: DieVisual) -> void:
	var cam := s.camera.cam
	var t0 := now()
	var cells: Array[Image] = []
	for f in 7:
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
	var out := Image.create(STRIP_CELL * 7, STRIP_CELL + small, false, Image.FORMAT_RGBA8)
	out.fill(Color("#0E1414"))
	for f in cells.size():
		var cimg := cells[f]
		out.blit_rect(cimg, Rect2i(Vector2i.ZERO, cimg.get_size()), Vector2i(f * STRIP_CELL, 0))
		var sm := cimg.duplicate() as Image
		sm.resize(maxi(1, int(cimg.get_width() * k)), maxi(1, int(cimg.get_height() * k)), Image.INTERPOLATE_BILINEAR)
		out.blit_rect(sm, Rect2i(Vector2i.ZERO, sm.get_size()), Vector2i(f * STRIP_CELL, STRIP_CELL))
	out.save_png(OUT + "trig_%s_frames.png" % id)
	print("saved %strig_%s_frames.png (die %.0f px, 48 px row x%.2f)" % [OUT, id, px, k])
