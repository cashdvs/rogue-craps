## AD #198: the Gallows d4 reads like the d6, through the real Bonfire scene.
## The table lamp's shadow leaves a d4's steep faces near black. The fix is
## the #201 rare-dice idea, not a glow:
##   - NO glow at rest (emission 0); a scoring glow is the normal one (<= 0.3)
##     and goes back to 0 when it clears;
##   - an unshaded pass of the d4's OWN body colour (D4FlatPass) is blended
##     40-60% over it, so the hue stays (no pale tint); a d6 has none;
##   - rendered (not headless), a cold d4 is about 0.45 bright, like the d6,
##     and a lit d4 keeps its body hue;
##   - its camera-facing value tag never covers HUD text (the felt seal row
##     "Lv1 120x12", combo strip, 2D labels), even parked right under the
##     seal row, and is >= 24 px tall on a phone (844x390);
##   - nor sits on another die (QA: on phone it covered the next d6's pips):
##     a d6 parked right beside / below the d4, on PC and phone;
##   - QA's crowded phone case (mid-hand, Nerve showing): combo strip below,
##     'Nerve ready' right, a d6 left, a bounty card title above, so all 4
##     plain spots are blocked: the tag still shows (a slid / corner spot),
##     on no text, and >= 4 px clear of every other die.
##   godot --headless --path . --script res://tests/test_d4_readable.gd
##   (brightness part: xvfb-run -a godot --path . --rendering-method gl_compatibility --script ...)
extends SceneTree

var _passed: int = 0
var _failed: int = 0


func check(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		print("FAIL  ", what)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var m: Array = await _make(Vector2i(1920, 1080))
	var s: Bonfire3D = m[1]
	var d4 := _die(s, &"d4")
	var d6 := _die(s, &"d6")
	check(d4 != null and d6 != null, "sandbox has a Gallows d4 and a d6")
	_check_flat(d4, d6)
	await _check_glow(d4)
	await _check_tag(s, d4, 1080.0, "PC 16:9")
	await _check_brightness(s, m[0])
	(m[0] as Node).queue_free()
	await process_frame
	m = await _make(Vector2i(2337, 1080))
	(m[1] as Bonfire3D).fit_phone(Vector2(844, 390))
	await _check_tag(m[1], _die(m[1], &"d4"), 390.0, "phone 844x390")
	(m[0] as Node).queue_free()
	await process_frame
	m = await _make(Vector2i(2337, 1080), 1)
	(m[1] as Bonfire3D).fit_phone(Vector2(844, 390))
	await _check_crowded(m[1])
	(m[0] as Node).queue_free()
	await process_frame
	print("test_d4_readable: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


## The real scene in a SubViewport; the last of 5 sandbox dice is a Gallows d4.
func _make(canvas: Vector2i, nerve: int = 0) -> Array:
	var sv := SubViewport.new()
	sv.size = canvas
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(sv)
	var t := load("res://resources/tuning/bonfire_tuning.tres") as BonfireTuning
	var st := TableSetup.sandbox(t, 5)
	st.nerve_uses = nerve
	st.dice[st.dice.size() - 1] = TableDie.new(DiceIds.DIE_GALLOWS, "Gallows", DiceIds.shape_of(DiceIds.DIE_GALLOWS))
	var s := (load("res://scenes/bonfire.tscn") as PackedScene).instantiate() as Bonfire3D
	s.setup = st
	s.tutorial_override = 0
	s.bonfire_seed = 5
	s.test_speed = 10.0
	sv.add_child(s)
	await process_frame
	await process_frame
	return [sv, s]


func _die(s: Bonfire3D, shape: StringName) -> DieVisual:
	for d: DieVisual in s.all_dice:
		if d.shape == shape:
			return d
	return null


func _energy(d: DieVisual) -> float:
	return float(d.body_material.get_shader_parameter("emission_energy"))


func _check_flat(d4: DieVisual, d6: DieVisual) -> void:
	var f := d4.body_material.next_pass as ShaderMaterial
	var is_flat := f != null and f.shader != null and "render_mode unshaded" in f.shader.code \
		and f.get_shader_parameter("mix_amount") != null
	check(is_flat, "d4 body has an unshaded flat pass next")
	if not is_flat:
		return
	var mix := float(f.get_shader_parameter("mix_amount"))
	check(mix >= 0.4 and mix <= 0.6, "flat pass blends %.2f of the surface (40-60%%)" % mix)
	var body: Color = d4.body_material.get_shader_parameter("albedo")
	var flat: Color = f.get_shader_parameter("albedo")
	check(flat.is_equal_approx(body), "flat colour is the body's own colour (%s vs %s)" % [flat, body])
	check(f.next_pass != null, "the ink outline still draws after it")
	var f6 := d6.body_material.next_pass as ShaderMaterial
	check(f6 == null or f6.get_shader_parameter("mix_amount") == null, "d6 has no flat pass")


func _check_glow(d4: DieVisual) -> void:
	await process_frame
	await process_frame
	check(is_zero_approx(_energy(d4)), "no glow on the d4 at rest (%.2f)" % _energy(d4))
	d4.highlight = 1.0
	var hl := _energy(d4)
	d4.highlight = 0.0
	check(hl > 0.0 and hl <= 0.3 and is_zero_approx(_energy(d4)), "highlight glow %.2f <= 0.3, then back to 0" % hl)
	DieGlow.apply(d4, 1)
	check(_energy(d4) <= 0.3 + 0.001, "scoring glow is the normal one (%.2f <= 0.3)" % _energy(d4))
	DieGlow.clear(d4)
	await process_frame
	await process_frame
	check(is_zero_approx(_energy(d4)), "no glow comes back after scoring clears (%.2f)" % _energy(d4))


## Every piece of text on screen, worked out here (not with HudTextRects).
func _text_rects(s: Bonfire3D) -> Array:
	var out := []
	var cam := s.camera.cam
	for n in s.get_viewport().find_children("*", "Control", true, false):
		var c := n as Control
		var txt := str(c.get("text")).strip_edges()
		if (c is Label or c is Button) and txt != "" and c.is_visible_in_tree() and _seen(c):
			out.append([c.get_global_rect(), txt])
	for n in s.get_viewport().find_children("*", "Label3D", true, false):
		var l := n as Label3D
		if l.is_visible_in_tree() and l.text.strip_edges() != "" and not l is D4ValueTag:
			var ab := l.get_aabb()
			var r := Rect2(cam.unproject_position(l.global_transform * ab.get_endpoint(0)), Vector2.ZERO)
			for i in 8:
				r = r.expand(cam.unproject_position(l.global_transform * ab.get_endpoint(i)))
			out.append([r, l.text])
	return out


## False when [param c] or a parent is faded out (the hidden count-up "x").
func _seen(c: CanvasItem) -> bool:
	var n: Node = c
	while n is CanvasItem:
		if (n as CanvasItem).modulate.a <= 0.05 or (n as CanvasItem).self_modulate.a <= 0.05:
			return false
		n = n.get_parent()
	return true


## Tag rect from its font, worked out here: font px x pixel size x the
## camera's px per metre at 1 m (KEEP_HEIGHT: view height / 2 tan(fov/2)).
func _tag_rect(s: Bonfire3D, tag: Label3D) -> Rect2:
	var cam := s.camera.cam
	var view_h := s.get_viewport().get_visible_rect().size.y
	var h := tag.font_size * tag.pixel_size * view_h / (2.0 * tan(deg_to_rad(cam.fov) * 0.5))
	var sz := Vector2(h * 0.62 * maxi(tag.text.length(), 1) + 0.25 * h, h)
	return Rect2(cam.unproject_position(tag.global_position) - sz * 0.5, sz)


func _tag_clear(s: Bonfire3D, tag: Label3D, label: String) -> void:
	for k in 20:  # the tag re-reads the HUD every 15 frames
		await process_frame
	if not tag.visible:
		check(true, "%s: tag hidden (no clear spot)" % label)
		return
	var r := _tag_rect(s, tag)
	var hits := []
	for t in _text_rects(s):
		if (t[0] as Rect2).intersects(r):
			hits.append(t[1])
	check(hits.is_empty(), "%s: tag %s covers no HUD text %s" % [label, str(r), str(hits)])


func _check_tag(s: Bonfire3D, d4: DieVisual, screen_h: float, label: String) -> void:
	var tag := d4.get_node_or_null("D4ValueTag") as Label3D
	check(tag != null and tag.billboard == BaseMaterial3D.BILLBOARD_ENABLED and not tag.shaded,
		"%s: d4 has an unlit camera-facing value tag" % label)
	if tag == null:
		return
	for k in 600:
		if s.phase == Table3D.Phase.BET and s.run.state == BonfireRun.State.AIM and not s.hand_moving():
			break
		await process_frame
	s.quick_throw()
	await s.sequence_finished
	await _tag_clear(s, tag, label + " after throw")
	check(tag.visible, "%s: tag shows after a normal throw" % label)
	check(tag.text == str(d4.shown_value()), "%s: tag shows the value (%s vs %d)" % [label, tag.text, d4.shown_value()])
	var px := _tag_rect(s, tag).size.y * screen_h / s.get_viewport().get_visible_rect().size.y
	check(px >= 24.0, "%s: tag %.1f px tall (>= 24)" % [label, px])
	# Park the d4 just under the felt seal row ("Lv1 120x12"), the AD's case.
	var seal: Label3D = null
	for n in s.get_viewport().find_children("*", "Label3D", true, false):
		if (n as Label3D).text.begins_with("Lv1") and (n as Label3D).is_visible_in_tree():
			seal = n
	check(seal != null, "%s: felt seal row found" % label)
	if seal != null:
		d4.global_position = Vector3(seal.global_position.x, d4.global_position.y, seal.global_position.z + 0.05)
		await _tag_clear(s, tag, label + " under the seal row")
	await _check_neighbours(s, d4, tag, label)


## Screen rect of a die's body mesh, worked out here (not the game's die_rect).
func _body_rect(cam: Camera3D, d: DieVisual) -> Rect2:
	var body := d.faces.get_node("Body") as MeshInstance3D
	var ab := body.get_aabb()
	var r := Rect2(cam.unproject_position(body.global_transform * ab.position), Vector2.ZERO)
	for i in 8:
		r = r.expand(cam.unproject_position(body.global_transform * ab.get_endpoint(i)))
	return r


## Parks d6s right next to the d4 (left, right, below, left + below) and
## checks the tag never overlaps another die.
func _check_neighbours(s: Bonfire3D, d4: DieVisual, tag: Label3D, label: String) -> void:
	var others: Array[DieVisual] = []
	for d: DieVisual in s.all_dice:
		if d != d4 and d.shape != &"d4":
			others.append(d)
	check(others.size() >= 2, "%s: two d6s to park" % label)
	if others.size() < 2:
		return
	var y := d4.global_position.y
	var home := Vector3(0.0, y, 0.05)
	var a := others[0]
	var b := others[1]
	var cases := {"left": [Vector3(-0.12, 0, 0)], "right": [Vector3(0.12, 0, 0)],
		"below": [Vector3(0, 0, 0.12)], "left+below": [Vector3(-0.12, 0, 0), Vector3(0, 0, 0.12)]}
	var shown := 0
	for name: String in cases:
		d4.global_position = home
		var offs: Array = cases[name]
		a.global_position = home + offs[0]
		b.global_position = home + (offs[1] if offs.size() > 1 else Vector3(0.6, 0, -0.3))
		for k in 3:
			await process_frame
		if not tag.visible:
			check(true, "%s d6 %s: tag hidden" % [label, name])
			continue
		shown += 1
		var r := _tag_rect(s, tag)
		var hits := []
		for d: DieVisual in s.all_dice:
			if d != d4 and d.is_visible_in_tree() and _body_rect(s.camera.cam, d).intersects(r):
				hits.append(d.name)
		check(hits.is_empty(), "%s d6 %s: tag %s on no other die %s" % [label, name, str(r), str(hits)])
	check(shown >= 2, "%s: tag still shows beside parked d6s (%d of 4)" % [label, shown])


## Is screen rect [param r] on screen but on one of [param rects]?
func _blocked(r: Rect2, rects: Array, view: Rect2) -> bool:
	return view.encloses(r) and rects.any(func(q: Rect2) -> bool: return q.intersects(r))


## [param scan]: walks the felt for the first d4 spot (the d6 0.12 m to its
## left) where all 4 plain tag spots are blocked, and parks both there.
## Not [param scan]: just re-checks the spot they are on now.
## Target HUD v2.1: the bounty-card titles are gone, so a 2nd d6 [param up]
## parked above the d4 can stand in for the text that blocked the top spot.
func _park_crowded(s: Bonfire3D, d4: DieVisual, nb: DieVisual, up: DieVisual, size: Vector2, scan: bool) -> bool:
	var cam := s.camera.cam
	var view := s.get_viewport().get_visible_rect()
	var texts: Array = _text_rects(s).map(func(t: Array) -> Rect2: return t[0])
	var y := d4.global_position.y
	var h := size * 0.5
	var spot := func(p: Vector2) -> Rect2: return Rect2(p - h, size)
	var z := -0.4 if scan else d4.global_position.z
	while z <= 0.5:
		var x := -0.8 if scan else d4.global_position.x
		while x <= 0.8:
			d4.global_position = Vector3(x, y, z)
			nb.global_position = Vector3(x - 0.12, y, z)
			up.global_position = Vector3(x, y, z - 0.12)
			var dr := RulesPlaqueDodge.die_rect(cam, d4)  # the die box the tag hugs
			var c := dr.get_center()
			if not texts.any(func(q: Rect2) -> bool: return q.intersects(dr.grow(4))) \
					and _blocked(spot.call(Vector2(c.x, dr.end.y + 4 + h.y)), texts, view) \
					and _blocked(spot.call(Vector2(dr.end.x + 4 + h.x, c.y)), texts, view) \
					and _blocked(spot.call(Vector2(dr.position.x - 4 - h.x, c.y)), [RulesPlaqueDodge.die_rect(cam, nb)], view) \
					and _blocked(spot.call(Vector2(c.x, dr.position.y - 4 - h.y)), texts + [RulesPlaqueDodge.die_rect(cam, up)], view):
				return true
			if not scan:
				return false
			x += 0.01
		z += 0.01
	return false


## QA #198 phone layout: mid-hand with Nerve showing, a d6 just left of the
## d4. Scans the felt for a d4 spot where all 4 plain tag spots (below,
## right, left, above; worked out here) are blocked as QA saw (left by the
## d6, the other 3 by HUD text), parks it there and checks the tag.
func _check_crowded(s: Bonfire3D) -> void:
	for k in 600:
		if s.phase == Table3D.Phase.BET and s.run.state == BonfireRun.State.AIM and not s.hand_moving():
			break
		await process_frame
	s.quick_throw()
	await s.sequence_finished
	s.nerve_ui.refresh()
	for k in 20:
		await process_frame
	var d4 := _die(s, &"d4")
	var tag := d4.get_node("D4ValueTag") as Label3D
	var cam := s.camera.cam
	var view := s.get_viewport().get_visible_rect()
	check(s.nerve_ui.pip_box.is_visible_in_tree(), "crowded: Nerve showing mid-hand")
	var nb: DieVisual = null
	var up: DieVisual = null
	for d: DieVisual in s.all_dice:
		if d != d4 and nb == null:
			nb = d
		elif d != d4 and d != nb and up == null:
			up = d
	var far := Vector3(0.0, d4.global_position.y, -5.0)
	for d: DieVisual in s.all_dice:  # clear the felt but for the d4 + its neighbour
		if d != d4 and d != nb and d != up:
			d.global_position = far
	var found := false
	for tries in 6:  # the Nerve UI moves off dice, so rescan until it settles
		found = _park_crowded(s, d4, nb, up, _tag_rect(s, tag).size, true)
		for k in 20:  # the tag re-reads the HUD every 15 frames
			await process_frame
		if found and _park_crowded(s, d4, nb, up, _tag_rect(s, tag).size, false):
			break
		found = false
	check(found, "crowded: QA's layout (all 4 plain spots blocked) found on the phone felt")
	if not found:
		return
	print("crowded: d4 at ", d4.global_position)
	check(tag.visible, "crowded: tag still shows with all 4 plain spots blocked")
	if not tag.visible:
		return
	var r := _tag_rect(s, tag)
	var hits := []
	for t in _text_rects(s):
		if (t[0] as Rect2).intersects(r):
			hits.append(t[1])
	check(hits.is_empty(), "crowded: tag %s covers no HUD text %s" % [str(r), str(hits)])
	var nr := RulesPlaqueDodge.die_rect(cam, nb)
	check(not nr.grow(4).intersects(r), "crowded: tag %s >= 4 px clear of the d6 %s" % [str(r), str(nr)])
	var ur := RulesPlaqueDodge.die_rect(cam, up)
	check(not ur.grow(4).intersects(r), "crowded: tag %s >= 4 px clear of the d6 above %s" % [str(r), str(ur)])
	check(view.encloses(r), "crowded: tag on screen")


## Rendered check (skipped headless): cold d4 ~ d6 at ~0.45, lit keeps its hue.
func _check_brightness(s: Bonfire3D, sv: SubViewport) -> void:
	if DisplayServer.get_name() == "headless":
		print("SKIP  brightness (headless: no renderer)")
		return
	var d4 := _die(s, &"d4")
	var d6 := _die(s, &"d6")
	var y := d6.global_position.y
	d6.global_position = Vector3(0, y, 0)
	d4.global_position = Vector3(0.13, y, 0)
	d4.set_glow_state(false, true, true)
	d6.set_glow_state(false, true, true)
	var cold := await _measure(s, sv, d4)
	var cold6 := await _measure(s, sv, d6)
	check(absf(cold[0] - 0.45) <= 0.07, "cold d4 brightness %.3f ~ 0.45" % cold[0])
	# a d6's brightness swings with which face is up, so: never darker than it
	check(cold[0] >= cold6[0] - 0.07, "cold d4 %.3f not darker than cold d6 %.3f" % [cold[0], cold6[0]])
	d4.set_glow_state(true, false, true)
	var lit := await _measure(s, sv, d4)
	var body: Color = d4.body_material.get_shader_parameter("albedo")
	var dh := absf(fposmod((lit[1] as Color).h - body.h + 0.5, 1.0) - 0.5)
	check(dh <= 0.06, "lit d4 keeps its body hue (%.3f vs %.3f)" % [(lit[1] as Color).h, body.h])
	check((lit[1] as Color).s >= body.s * 0.5, "lit d4 is not washed out (sat %.2f vs body %.2f)" % [(lit[1] as Color).s, body.s])


## [mean luminance, mean colour] of the die's pixels.
func _measure(s: Bonfire3D, sv: SubViewport, d: DieVisual) -> Array:
	for k in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := sv.get_texture().get_image()
	var rr := RulesPlaqueDodge.die_rect(s.camera.cam, d).grow(-8)
	var sum := 0.0
	var col := Color(0, 0, 0)
	var cnt := 0
	for py in range(int(rr.position.y), int(rr.end.y)):
		for px in range(int(rr.position.x), int(rr.end.x)):
			var c := img.get_pixel(px, py)
			if c.get_luminance() > 0.06:
				sum += c.get_luminance()
				col += c
				cnt += 1
	return [sum / maxf(cnt, 1), col / maxf(cnt, 1)]
