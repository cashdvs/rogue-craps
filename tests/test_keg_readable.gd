## Powder Keg barrel readability. The scoring stave points straight up, so
## from the table camera a neighbouring stave (a different number) is the
## one that faces the lens, and the printed pips are about 5 mm and partly
## under the hoops. KegValueTag shows the value the table reads
## (DieVisual.shown_value) on a camera-facing label.
## After one real settle, every stave slot (values 1, 1, 2, 2, 3, 3) is
## turned up and checked on:
##   - desktop 1920x1080
##   - a 1024x576 window (the 16:9 canvas scaled down; the short window uses
##     the phone Soul reliquary)
##   - phone landscape 844x390
##   - phone portrait 390x844
## The tag must show that read value, sit inside the screen, miss every HUD
## text rect, and be >= 24 px tall in real screen pixels. Glow stays <= 0.3.
## A d6 beside it gets no tag. Disabling KegValueTag.attach fails this.
##   godot --headless --path . --script res://tests/test_keg_readable.gd
extends "res://tests/d4_readable_base.gd"

const FACES: Array[int] = [1, 1, 2, 2, 3, 3]
const MIN_PX := 24.0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var m: Array = await _scene(Vector2i(1920, 1080))
	var sv: SubViewport = m[0]
	var s: Bonfire3D = m[1]
	var keg := _keg(s)
	var bone := _other(s, keg)
	check(keg != null and keg.shape == &"keg", "sandbox die is a Powder Keg barrel")
	check(bone != null and bone.get_node_or_null("KegValueTag") == null, "a d6 has no keg tag")
	var tag: KegValueTag = keg.get_node_or_null("KegValueTag") as KegValueTag if keg != null else null
	check(tag != null and tag.billboard == BaseMaterial3D.BILLBOARD_ENABLED and not tag.shaded,
		"keg has an unlit camera-facing value tag")
	if tag == null or keg == null:
		print("test_keg_readable: %d passed, %d failed" % [_passed, _failed])
		quit(1)
		return
	var ink := RareDieLook.contrast(tag.modulate, tag.outline_modulate)
	check(ink >= 4.5 and tag.outline_size > 0, "tag ink vs outline contrast %.1f:1 (>= 4.5)" % ink)
	await _until_aim(s)
	s.set_reduced_motion(true)
	check(s.quick_throw(), "throw started")
	await s.sequence_finished
	for i in 40:
		await process_frame
	s.camera.snap_home()
	_check_glow(keg)
	await _check_view(s, sv, keg, bone, tag, "pc")
	await _check_view(s, sv, keg, bone, tag, "small")
	await _check_view(s, sv, keg, bone, tag, "land")
	await _check_view(s, sv, keg, bone, tag, "portrait")
	sv.queue_free()
	await process_frame
	print("test_keg_readable: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


## The real scene: one Bone and one Powder Keg (faces 1, 1, 2, 2, 3, 3).
func _scene(canvas: Vector2i) -> Array:
	var sv := SubViewport.new()
	sv.size = canvas
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(sv)
	var t := load("res://resources/tuning/bonfire_tuning.tres") as BonfireTuning
	var st := TableSetup.sandbox(t, 2)
	st.nerve_uses = 0
	var keg := TableDie.new(DiceIds.DIE_POWDER_KEG, "Powder Keg")
	var printed: Array[int] = []
	printed.assign(FACES)
	keg.faces = printed
	st.dice[st.dice.size() - 1] = keg
	var s := (load("res://scenes/bonfire.tscn") as PackedScene).instantiate() as Bonfire3D
	s.setup = st
	s.tutorial_override = 0
	s.bonfire_seed = 5
	s.test_speed = 10.0
	sv.add_child(s)
	await process_frame
	await process_frame
	return [sv, s]


func _keg(s: Bonfire3D) -> DieVisual:
	for d: DieVisual in s.all_dice:
		if d.shape == &"keg":
			return d
	return null


func _other(s: Bonfire3D, keg: DieVisual) -> DieVisual:
	for d: DieVisual in s.all_dice:
		if d != keg:
			return d
	return null


func _until_aim(s: Bonfire3D) -> void:
	for i in 600:
		if s.phase == Table3D.Phase.BET and s.run != null and s.run.state == BonfireRun.State.AIM and not s.hand_moving():
			return
		await process_frame


## Rest, highlight and top-tier scoring glow all stay <= 0.3, then clear.
func _check_glow(d: DieVisual) -> void:
	var rest := _energy(d)
	d.highlight = 1.0
	var hl := _energy(d)
	d.highlight = 0.0
	DieGlow.apply(d, 3)
	var hot := _energy(d)
	DieGlow.clear(d)
	check(rest <= 0.3 and hl <= 0.3 and hot <= 0.3 and is_zero_approx(_energy(d)),
		"keg glow <= 0.3 (rest %.2f, highlight %.2f, score %.2f, clear %.2f)" % [rest, hl, hot, _energy(d)])


func _energy(d: DieVisual) -> float:
	return float(d.body_material.get_shader_parameter("emission_energy"))


## Frames one play view, then checks every stave after the die has settled.
func _check_view(s: Bonfire3D, sv: SubViewport, keg: DieVisual, bone: DieVisual, tag: KegValueTag, kind: String) -> void:
	var real_h := _frame(s, sv, kind)
	for i in 5:
		await process_frame
	s.camera.snap_home()
	var y := keg.global_position.y
	keg.global_position = Vector3(0.12, y, 0.0)
	bone.global_position = Vector3(-0.55, y, 0.32)
	for slot in range(1, 7):
		keg.set_face(slot, false)
		var want: int = FACES[slot - 1]
		await _read(s, keg, tag, slot, want, real_h, "%s slot %d" % [kind, slot])


## Puts the camera and HUD in one play view. Returns the real screen height
## the canvas is scaled onto (tag px are measured in those pixels).
func _frame(s: Bonfire3D, sv: SubViewport, kind: String) -> float:
	var real_h := 1080.0
	if kind == "pc":
		sv.size = Vector2i(1920, 1080)
		s.window_px_override = Vector2i(1920, 1080)
		s.phone_screen = Vector2.ZERO
		s.camera.fit_viewport(Vector2(1920, 1080))
	elif kind == "small":
		# 1024x576 is 16:9, so the game keeps the 1920x1080 canvas and scales
		# it. Under 720 px tall the Soul reliquary uses the phone plate.
		sv.size = Vector2i(1920, 1080)
		s.window_px_override = Vector2i(1024, 576)
		s.phone_screen = Vector2.ZERO
		s.camera.fit_viewport(Vector2(1920, 1080))
		real_h = 576.0
	elif kind == "land":
		sv.size = Vector2i(2337, 1080)
		s.fit_phone(Vector2(844, 390))
		real_h = 390.0
	else:
		var phone := Vector2(390, 844)
		var scale := minf(phone.x / 1920.0, phone.y / 1080.0)
		sv.size = Vector2i(int(round(phone.x / scale)), int(round(phone.y / scale)))
		s.fit_phone(phone)
		real_h = phone.y
	s._update_portrait_hud()
	s._refresh_hud()
	return real_h


## One settled stave: the read value is unchanged, and the tag shows it,
## on screen, clear of HUD text, and tall enough.
func _read(s: Bonfire3D, keg: DieVisual, tag: KegValueTag, slot: int, want: int, real_h: float, label: String) -> void:
	for i in 20:
		await process_frame
	check(keg.up_slot() == slot and keg.shown_value() == want,
		"%s: read stays %d (slot %d, shown %d)" % [label, want, keg.up_slot(), keg.shown_value()])
	check(tag.visible and tag.text == str(want),
		"%s: tag shows %d (text '%s', visible %s)" % [label, want, tag.text, tag.visible])
	if not tag.visible:
		return
	var r := _tag_rect(s, tag)
	var view := s.get_viewport().get_visible_rect()
	check(view.encloses(r), "%s: tag %s inside %s" % [label, str(r), str(view)])
	var hits: Array[String] = []
	for t in _text_rects(s):
		if (t[0] as Rect2).intersects(r):
			hits.append(str(t[1]))
	check(hits.is_empty(), "%s: tag covers no HUD text %s" % [label, str(hits)])
	var px := r.size.y * real_h / view.size.y
	check(px >= MIN_PX, "%s: tag %.1f px tall (>= %.0f)" % [label, px, MIN_PX])
