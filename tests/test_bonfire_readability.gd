## Readability pass (how_bonfire_plays.md section 4) on the 3D Bonfire table:
##   - lit dice glow ember, cold dice go matte grey (material only: no lights);
##   - a die that can't join bounces back with a "doesn't score" callout;
##   - the live pot preview "TRIPS: (30+12) x3 = 126" and its factor notes;
##   - the rethrow prompt with the exact bust risk;
##   - bounty cards: PENDING ghost "Pending: bank to claim it.", then the CLAIMED seal;
##   - the TABLE CLEARED banner at the clearing bank (never blocks input);
##   - the combo table printed on the felt (no side panel), swapped by aspect;
##   - the debug throw overlay: off by default, shows the numbers when on.
##   godot --headless --path . --script res://tests/test_bonfire_readability.gd
extends SceneTree

var _passed: int = 0
var _failed: int = 0
var t: BonfireTuning


func _initialize() -> void:
	_run.call_deferred()


func check(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		print("FAIL  ", what)


func throw_faces(s: Bonfire3D, faces: Array[int]) -> void:
	s.rig_faces(faces)
	if not s.quick_throw():
		check(false, "throw %s starts" % str(faces))
		return
	await s.throw_resolved
	await s.sequence_finished


func wait_bet(s: Bonfire3D) -> void:
	for k in 400:
		if s.phase == Table3D.Phase.BET and not s.bhud.countup.is_playing():
			return
		await process_frame


func make_table(size := Vector2i(1920, 1080)) -> Array:
	var sv := SubViewport.new()
	sv.size = size
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(sv)
	var st := TableSetup.sandbox(t, 5)
	st.table_seed = 5
	var s := (load("res://scenes/bonfire.tscn") as PackedScene).instantiate() as Bonfire3D
	s.setup = st
	s.tutorial_override = 0
	s.test_speed = 10.0
	sv.add_child(s)
	await process_frame
	await process_frame
	return [sv, s]


func _run() -> void:
	t = load("res://resources/tuning/bonfire_tuning.tres") as BonfireTuning
	_pure()
	await _scene()
	await _felt_portrait()
	await _debug_overlay()
	print("test_bonfire_readability: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _pure() -> void:
	var trips := BonfireScoring.score_selection([4, 4, 4], t)
	check(BonfireScoring.preview(trips) == "TRIPS: (30+12) x3 = 126", "preview text (%s)" % BonfireScoring.preview(trips))
	var hell := load("res://resources/mods/hellfire.tres") as FaceModData
	var dice := [BonfireScoring.make_die(4, hell), BonfireScoring.make_die(4), BonfireScoring.make_die(4)]
	var s2 := BonfireScoring.score_selection(dice, t, 1)
	var notes := BonfireScoring.factor_notes(dice, s2, t, 1)
	check(BonfireScoring.preview(s2).ends_with("x4 x1.5 = %d" % int(s2["points"])), "preview shows Hot Hand in the mult and the Hellfire factor (%s)" % BonfireScoring.preview(s2))
	check(notes.size() == 2 and notes[0] == "Hot Hand +1 mult" and notes[1].begins_with(hell.display_name) and notes[1].ends_with("x1.5"), "factor notes (%s)" % str(notes))
	check(BonfireScoring.factor_notes([4, 4, 4], trips, t).is_empty(), "no notes for a plain pot")
	# The Bloodletter: the HUD rule row is the strings_v1 row 113 line
	# (synced with bloodletter.tres in #137).
	var br := BonfireRun.new(t)
	br.set_rules(TableRules.build([{"id": &"bloodletter", "params": {}}]), 1)
	check(br.rules.size() == 1 and br.rules[0].info_line(br) == "Every Soul cost is doubled: a bust costs 2 Soul.", "Bloodletter HUD rule line (%s)" % (br.rules[0].info_line(br) if br.rules.size() > 0 else "none"))


func _scene() -> void:
	var made: Array = await make_table()
	var sv: SubViewport = made[0]
	var s: Bonfire3D = made[1]
	var r := s.run
	s.juice.force_fallback = true
	# No side combo panel; the felt table has all 9 printed combos.
	check(s.bhud.find_child("ComboPanel", true, false) == null, "the side combo panel is gone")
	check(s.felt_combos != null and s.felt_combos.labels.size() == 9, "9 combo slots on the felt (%d)" % (s.felt_combos.labels.size() if s.felt_combos else -1))
	var tl: Label3D = s.felt_combos.labels.get(&"trips")
	check(tl != null and tl.text == "Lv1 30x3" and not tl.shaded and is_equal_approx(tl.pixel_size, 0.0005), "Trips slot reads 'Lv1 30x3' (%s)" % (tl.text if tl else "none"))
	check(is_equal_approx(tl.scale.y, 1.40) and is_equal_approx(tl.rotation_degrees.x, -90.0), "landscape slot: flat, x1.40 stretch")
	var fm := s.table.felt_material as ShaderMaterial
	check(bool(fm.get_shader_parameter("use_overlay")) and fm.get_shader_parameter("overlay_tex") != null and is_equal_approx(float(fm.get_shader_parameter("overlay_emission")), 0.35), "the print is on the felt with 0.35 emission")
	# Overflow: squeeze to 0.80 first, then "Lv" -> "L".
	var big := t.duplicate(true) as BonfireTuning
	for c: BonfireCombo in big.combos:
		if c.id == &"pair":
			c.base = 9999
			c.mult = 400
	s.felt_combos.set_combos(big, {&"pair": 88})
	var pl: Label3D = s.felt_combos.labels[&"pair"]
	check(pl.text.begins_with("L88 ") and pl.scale.x >= 0.8 - 0.0001, "overflow: 'Lv' drops to 'L' only after the 0.80 squeeze (%s, %.2f)" % [pl.text, pl.scale.x])
	s.felt_combos.set_combos(t)
	# Lit vs cold.
	await throw_faces(s, [4, 4, 4, 5, 2] as Array[int])
	await process_frame
	await create_timer(0.3).timeout
	var d4: DieVisual = s.throw_dice[0]
	var d2: DieVisual = s.throw_dice[4]
	check(s.is_lit(d4) and d4.glow_lit > 0.99 and d4.glow_cold < 0.01, "a lit die glows (lit %.2f)" % d4.glow_lit)
	check(s.is_cold(d2) and d2.glow_cold > 0.99 and d2.glow_lit < 0.01, "the cold 2 goes matte grey (cold %.2f)" % d2.glow_cold)
	check(float(d2.body_material.get_shader_parameter("die_cold")) > 0.99 and float(d4.body_material.get_shader_parameter("die_lit")) > 0.99, "the states drive the die shader")
	var lights := 0
	for d in s.throw_dice:
		lights += d.find_children("*", "OmniLight3D", true, false).size()
	check(lights == 0, "glow only: no lights on the dice")
	# Playtest fix: lit = thin rim, pips stay dark ink (no ember lerp, no emission, no cores).
	check(is_equal_approx(DieVisual.PIP_MID_ENERGY, 0.0) and is_equal_approx(DieVisual.PIP_CORE_ENERGY, 0.0), "lit pip energies are 0")
	check(d4.pip_core_material != null and float(d4.pip_core_material.get_shader_parameter("energy")) < 0.0001, "lit pips: no hot cores")
	check(float(d4.pip_material.get_shader_parameter("emission_energy")) < 0.0001, "lit pips: no emission")
	check((d4.pip_material.get_shader_parameter("albedo") as Color).is_equal_approx(d4._pip_color), "lit pips keep their ink colour")
	var cores_on := 0
	for c in d4._pip_cores:
		cores_on += 1 if c.visible else 0
	check(cores_on == 0, "lit pips: cores hidden")
	check(is_equal_approx(float(d4.body_material.get_shader_parameter("state_rim_energy")), 0.6), "lit rim energy 0.6")
	var sh_src := (d4.body_material as ShaderMaterial).shader.code
	check(sh_src.contains("state_rim_power = 5.0") and sh_src.contains("state_rim_energy = 0.6") and sh_src.contains("lit_albedo_mix_max = 0.35"), "toon_noir: rim 5.0 / 0.6, lit albedo mix capped at 0.35")
	# AD: lit hull outline on the glass family only (dark warm ink, unshaded, no emission).
	check(d4.material == "bone" and d4.hull_outline == null, "bone stays rim-only: no hull outline")
	for fam in ["bone", "brass", "wood", "obsidian"]:
		check(not DieVisual.has_hull_outline(fam), "%s: rim-only, no hull outline" % fam)
	check(DieVisual.has_hull_outline("frosted_glass"), "frosted glass takes the hull outline")
	var gd: DieVisual = s.throw_dice[1]
	gd.material = "frosted_glass"
	gd.set_glow_state(true, false, true)
	var ho := gd.hull_outline
	check(ho != null and ho.visible, "lit glass die shows its hull outline")
	var hm := ho.material_override as StandardMaterial3D if ho != null else null
	check(hm != null and hm.albedo_color.is_equal_approx(Color("#2A2018")), "hull outline colour #2A2018")
	check(hm != null and hm.grow and is_equal_approx(hm.grow_amount, 0.012), "hull outline width 0.012 m")
	check(hm != null and hm.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED and not hm.emission_enabled and hm.cull_mode == BaseMaterial3D.CULL_FRONT, "hull outline unshaded, no emission, inverted hull")
	gd.set_glow_state(false, false, true)
	check(not ho.visible, "hull outline hides when the die isn't lit")
	gd.material = "bone"
	check(gd.hull_outline == null, "switching back to bone removes the outline")
	check(DieGlow.TIER_EMISSION == [0.1, 0.15, 0.2, 0.3] and DieGlow.TIER_HALO_ALPHA == [0.10, 0.14, 0.18, 0.24], "die_glow tiers: emission/halo toned down")
	# Refusal: bounce back + callout (its sound is the VFX / audio side's).
	var before := d2.position
	var refused: Array = []
	s.refused.connect(func(i: int) -> void: refused.append(i))
	j_clear(s)
	check(not s.pick_die(4), "the cold 2 is refused")
	check(refused == [4] and s.bhud.callout_label.text == "doesn't score" and s.bhud.callout_label.modulate.a > 0.9, "'doesn't score' callout")
	await create_timer(0.4).timeout
	check(d2.position.distance_to(before) < 0.001, "the refused die bounces back to where it was")
	# Pot preview + rethrow risk.
	s.pick_die(0)
	s.pick_die(1)
	s.pick_die(2)
	s._refresh_hud()
	check(s.bhud.throw_label.text == "TRIPS: (30+12) x3 = 126", "pot preview (%s)" % s.bhud.throw_label.text)
	check(s.bhud.risk_label.text == "2 cold dice: 1 in 3 chance nothing lights", "rethrow risk (%s)" % s.bhud.risk_label.text)
	check(s.bhud.card_header.text == "Claim all 3 bounties · 5 hands left", "card header (%s)" % s.bhud.card_header.text)
	check(s.bhud.points_label.text == "points 0 → +0 Embers", "points as income (%s)" % s.bhud.points_label.text)
	# Throw the 2 cold dice: the prompt in AIM says the same.
	check(s.throw_again(), "throw the 2 cold dice")
	await wait_bet(s)
	s._refresh_hud()
	# Bounty card: the potted Triple is pending (ghost), then the claimed seal.
	var card: BountyCard = s.bhud.bounty_cards[&"triple"]
	check(card.state == "pending" and card.ghost.visible and card.pending_label.visible and card.pending_label.text == "Pending: bank to claim it.", "Triple card PENDING · bank to lock (%s)" % card.state)
	check(s.bhud.throw_label.text == "2 cold dice: 1 in 3 chance nothing lights", "AIM prompt with the risk (%s)" % s.bhud.throw_label.text)
	await throw_faces(s, [1, 5] as Array[int])
	s.pick_die(0)
	await s.bank()
	await wait_bet(s)
	check(card.state == "claimed" and card.seal.visible and s.bhud.has_stamp(&"triple"), "banked: the CLAIMED seal")
	check(card.seal.scale.x >= BountyCard.SEAL_SCALE * 0.99, "seal at its rest scale (%.2f)" % card.seal.scale.x)
	check(card.get_global_transform().get_scale().x * BountyCard.CARD_SIZE.x >= 136.0 * 2.0 - 0.5, "PC card is 136 pt wide at UI scale 2")
	# Clear: Run of 3, Two Pairs -> the banner.
	await throw_faces(s, [1, 2, 3, 6, 6] as Array[int])
	for i in 3:
		s.pick_die(i)
	await s.bank()
	await wait_bet(s)
	await throw_faces(s, [2, 2, 3, 3, 6] as Array[int])
	for i in 4:
		s.pick_die(i)
	var banner := s.bhud.cleared_banner
	var seen: Array = []
	banner.impact.connect(func() -> void: seen.append(true), CONNECT_ONE_SHOT)
	await s.bank()
	check(r.cleared and banner.text.begins_with("TABLE CLEARED") and banner.mouse_filter == Control.MOUSE_FILTER_IGNORE, "TABLE CLEARED banner at the clearing bank")
	check(banner.layers.size() == 6 and (banner.glow.material as CanvasItemMaterial).blend_mode == CanvasItemMaterial.BLEND_MODE_ADD, "6 layers, glow in Add blend")
	for k in 40:
		if not banner.is_playing():
			break
		await create_timer(0.1).timeout
	check(seen == [true], "the banner lands (impact) once (%s)" % str(seen))
	check(not banner.is_playing() and not banner.visible, "the banner is gone after its 1.8 s")
	sv.queue_free()
	await process_frame


func j_clear(s: Bonfire3D) -> void:
	s.juice.calls.clear()


## Phone portrait swaps the print and the slots to the portrait block, with
## the near-rail end of the felt at the bottom of the screen.
func _felt_portrait() -> void:
	var made: Array = await make_table(Vector2i(1920, 4155))
	var sv: SubViewport = made[0]
	var s: Bonfire3D = made[1]
	s.camera.cam.current = true
	s.fit_phone(Vector2(390, 844))
	s.camera.snap_home()
	s._refresh_hud()
	await process_frame
	var fc := s.felt_combos
	check(fc.portrait, "portrait: the felt table swaps to the portrait block")
	var lbl: Label3D = fc.labels.get(&"trips")
	check(lbl != null and is_equal_approx(lbl.scale.y, 1.10 * fc.port_scale) and lbl.font_size == 88, "portrait slots: font 88, x1.10 (x%.2f fit)" % fc.port_scale)
	var view := Vector2(1920, 4155)
	var inside := true
	for id in fc.labels:
		var l: Label3D = fc.labels[id]
		var half := fc.text_width(l) * l.scale.x * 0.5
		for dz: float in [-half, half]:
			var sp := s.camera.cam.unproject_position(l.global_position + Vector3(0, 0, dz))
			if sp.x < 0.0 or sp.x > view.x or sp.y < 0.0 or sp.y > view.y:
				inside = false
				print("portrait slot off screen: %s %s" % [id, sp])
	check(inside and fc.port_scale >= 0.6, "portrait: every slot is on screen (block x%.2f, shift %.3f m)" % [fc.port_scale, fc.port_shift_z])
	var near := s.camera.cam.unproject_position(Vector3(-0.9, 0, 0))
	var far := s.camera.cam.unproject_position(Vector3(0.9, 0, 0))
	print("portrait felt: near(-X) y=%.0f far(+X) y=%.0f flipped=%s" % [near.y, far.y, fc.portrait_flipped])
	check((near.y > far.y) == not fc.portrait_flipped, "the block sits at the screen-bottom end (near %.0f far %.0f flipped %s)" % [near.y, far.y, fc.portrait_flipped])
	check(not s.bhud.checklist_panel.visible and s.bhud.portrait_goal.visible, "portrait: cards hidden, goal readout shown")
	sv.queue_free()
	await process_frame


func _debug_overlay() -> void:
	var made: Array = await make_table()
	var sv: SubViewport = made[0]
	var s: Bonfire3D = made[1]
	check(not s.throw_debug and not s.throw_debug_label.visible, "debug throw overlay is off by default")
	var got: Array = []
	s.throw_measured.connect(func(a: float, b: float, k: float) -> void: got.append([a, b, k]))
	await throw_faces(s, [4, 4, 4, 5, 2] as Array[int])
	check(got.size() == 1 and not s.throw_debug_label.visible, "throw_measured fires; overlay stays hidden while off")
	s.throw_debug = true
	check(s.throw_debug_label.visible and s.throw_debug_label.text.contains("px/s") and s.throw_debug_label.text.contains("m/s") and s.throw_debug_label.text.contains("curve"), "on: shows flick px/s, launch m/s, curve (%s)" % s.throw_debug_label.text)
	check(s.throw_debug_label.text.contains("%.2f m/s" % float(got[0][1])), "the overlay shows the measured launch speed")
	s.throw_debug = false
	check(not s.throw_debug_label.visible, "F3 / flag off hides it")
	sv.queue_free()
	await process_frame
