## AD #198: the Gallows d4 reads like the d6, through the real Bonfire scene.
## The table lamp's shadow leaves a d4's steep faces near black. The fix is
## the #201 rare-dice idea, not a glow:
##   - NO glow at rest (emission 0); a scoring glow is the normal one (<= 0.3)
##     and goes back to 0 when it clears;
##   - an unshaded pass of the d4's OWN body colour (D4FlatPass) is blended
##     40-60% over it, so the hue stays (no pale tint); a d6 has none;
##   - rendered (not headless), a cold d4 is about 0.45 bright, like the d6,
##     and a lit d4 keeps its body hue;
##   - its camera-facing value tag never covers HUD text (a felt combo
##     slot, combo strip, 2D labels), even parked right under a combo
##     slot, and is >= 24 px tall on a phone (844x390);
##   - nor sits on another die (QA: on phone it covered the next d6's pips):
##     a d6 parked right beside / below the d4, on PC and phone;
##   - QA's crowded phone case lives in tests/test_d4_crowded.gd.
##   godot --headless --path . --script res://tests/test_d4_readable.gd
##   (brightness part: xvfb-run -a godot --path . --rendering-method gl_compatibility --script ...)
extends "res://tests/d4_readable_base.gd"


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
	print("test_d4_readable: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


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
