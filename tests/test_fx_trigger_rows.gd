## Headless test: trigger FX per-row visuals (scripts/fx/trigger_fx*.gd).
## Split from the former monolithic test_fx_trigger.gd so each file stays
## near the ~400-line newcomer rule. Shared stubs/helpers: TriggerFxHarness.
##
## Run:
##   godot --headless --path . --script res://tests/test_fx_trigger_rows.gd
extends TriggerFxHarness


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	print("=== Dice of the Damned: trigger FX per-row visuals ===")
	_setup_world()
	_test_links_and_icons()
	_test_rows_read_apart()
	_test_never_tints_the_die()
	await _test_coin_flight()
	_test_aliases()
	_finish()


func _test_links_and_icons() -> void:
	var fx := _fx()
	var src := _die(Vector3(-0.2, 0.04, 0))
	var m := _die(Vector3(0.2, 0.04, 0))
	fx.trigger_fx(&"mirror_copy", m, {"source": src})
	_step(fx, 1.0 / 12.0 + DT)
	var b: TriggerFxPool.Burst = fx._live[0]
	var gp := b.glint.global_position
	_check(b.glint.visible and gp.x > -0.2 and gp.x < 0.2, "Mirror: a glass glint is on its way from the source on f1 (%s)" % gp)
	_check(gp.y <= 0.04 + 0.0001 and absf(gp.z) > 0.01, "the glint bows sideways along the felt, never up (%s)" % gp)
	var low := true
	for u in 11:
		low = low and TriggerFxLinks.glint_point(src.global_position, m.global_position, u / 10.0, _cam).y <= 0.04 + 0.0001
	_check(low, "the glint path never rises above the dice")
	_check(b.glint.mesh.size.x < 0.15, "the glint is a short streak, not a beam (%.3f m)" % b.glint.mesh.size.x)
	var along := (b.glint.global_basis.x).normalized()
	var path := (TriggerFxLinks.glint_point(src.global_position, m.global_position, 0.4, _cam) - TriggerFxLinks.glint_point(src.global_position, m.global_position, 0.26, _cam)).normalized()
	_check(absf(along.dot(_cam.global_basis.z)) < 0.01 and along.dot(path) > 0.5, "the streak faces the camera and lies along its path")
	_step(fx, 2.0 / 12.0)
	_check(not b.glint.visible and _motes_ok(b, m), "the glint arrives on the hit (f3) as two small motes off the die's top-right corner")
	_check(b.icon.visible and is_equal_approx(b.icon.diameter, 32.0 * fx.px_scale()) and b.icon.studs == 4, "major icon: 32 px at 720p, 4 studs (%.1f)" % b.icon.diameter)
	_step(fx, 1.0)
	fx.trigger_fx(&"coin_heads_copy", m, {"source": src})
	_step(fx, 2.0 / 12.0 + DT)
	b = fx._live[0]
	_check(not b.glint.visible, "Coin: no glint while it spin-flips")
	_check(not m.faces.transform.is_equal_approx(b.rest), "Coin: the die is in the air, flipping on f2")
	_step(fx, 2.0 / 12.0)
	_check(b.glint.visible, "Coin: the glint from the highest die arrives after it lands")
	_step(fx, 1.0 / 12.0)
	_check(not b.glint.visible and _motes_ok(b, m), "Coin: the glint reaches the coin on f5 as two motes, off the face")
	_step(fx, 1.0)
	fx.trigger_fx(&"gilded_payout", m)
	_step(fx, 2.0 / 12.0 + DT)
	b = fx._live[0]
	_check(b.icon.visible and is_equal_approx(b.icon.diameter, 32.0 * fx.px_scale()) and b.icon.studs == 0, "minor icon pops ON the hit: 32 px at 720p too, plain rim")
	_step(fx, 1.0)
	_free([fx, src, m])


func _test_rows_read_apart() -> void:
	var fx := _fx()
	var d := _die(Vector3(0, 0.04, 0))
	# Ring: a pulse from the hit that grows and fades within 0.25 s.
	fx.trigger_fx(&"hellfire_face", d)
	var b: TriggerFxPool.Burst = fx._live[0]
	_step(fx, 1.0 / 12.0 + DT)
	_check(not b.ring.visible, "no static ring during anticipation")
	_step(fx, 2.0 / 12.0)
	var r0: float = b.ring.mesh.size.x
	var a0: float = b.ring.material_override.albedo_color.a
	_check(b.ring.visible and not b.ring2.visible, "the bone ring pulses on the hit; the ember one a frame later")
	_check(b.card.visible and b.card.material_override.albedo_texture == TriggerShapes.texture(&"needles_radial", TriggerFxDefs.BONE), "Hellfire: bone needles on the hit")
	_check(b.frame.visible and b.frame.material_override.albedo_texture == TriggerShapes.texture(&"frame_square", TriggerFxDefs.HELLFIRE), "Hellfire on a d6: a Hellfire-red square frame")
	_check(b.core.visible, "Hellfire: an ember-core glow")
	var n0: float = b.card.mesh.size.x
	_check(b.sparks.all(func(x: MeshInstance3D) -> bool: return not x.visible), "Hellfire: no diamond sparks (no crackle)")
	_step(fx, 1.0 / 12.0)
	_check(b.ring.visible and b.ring.mesh.size.x > r0 and b.ring.material_override.albedo_color.a < a0, "the ring grows and fades (%.3f > %.3f)" % [b.ring.mesh.size.x, r0])
	_check(b.ring2.visible, "the ember inner pulse follows")
	_check(b.card.mesh.size.x > n0, "the needles shoot out")
	_check(b.chip.visible and b.chip.text == "×1.5", "Hellfire: the ×1.5 chip pops beside the icon")
	_step(fx, 1.0 / 12.0)
	_check(b.card.mesh.size.x < n0 * 1.5 - 0.001, "then retract")
	_step(fx, 1.0 / 12.0)
	_check(not b.ring.visible, "the pulse is gone 0.25 s after the hit")
	_step(fx, 1.0)
	# Gilded: a gold halo on the pip tick, gold sparks, the gold ring.
	fx.trigger_fx(&"gilded_payout", d)
	b = fx._live[0]
	_step(fx, 2.0 / 12.0 + DT)
	_check(b.card.visible and b.card.material_override.albedo_texture == TriggerShapes.texture(&"radial_glow_soft", TriggerFxDefs.BRASS_HI)
			and b.frame.visible, "Gilded: a gold glow + shine bar on the hit")
	_check(b.ring.material_override.albedo_texture == TriggerShapes.texture(&"ring_pulse_soft", TriggerFxDefs.BRASS_HI), "Gilded: the ring is gold")
	_check(b.sparks[0].visible and b.sparks[0].material_override.albedo_texture == TriggerShapes.texture(&"spark_diamond", TriggerFxDefs.BRASS_HI), "Gilded: gold sparks")
	_step(fx, 1.0)
	fx.trigger_fx(&"hellfire_face", d, {"flavor": &"verdict"})
	b = fx._live[0]
	_step(fx, 3.0 / 12.0 + DT)
	_check(b.frame.material_override.albedo_texture == TriggerShapes.texture(&"frame_hex", TriggerFxDefs.HELLFIRE), "Hellfire on Verdict: the frame is a hex")
	_step(fx, 1.0)
	_free([fx, d])


## Art Director: never tint the die body (it reads as another die type).
## Every material and colour on the die stays exactly as it was, every frame.

func _test_never_tints_the_die() -> void:
	var fx := _fx()
	var src := _die(Vector3(-0.2, 0.04, 0))
	var d := _die(Vector3(0.1, 0.04, 0))
	var before := _die_look(d)
	var kids := d.get_child_count()
	var changed := 0
	for id: StringName in [&"mirror_copy", &"gilded_payout", &"coin_heads_copy", &"coin_tails_copy", &"coin_alone_heads",
			&"hellfire_face", &"wild_face", &"other"]:
		fx.trigger_fx(id, d, {"source": src})
		for i in 90:
			_step(fx, DT)
			if _die_look(d) != before:
				changed += 1
		_step(fx, 0.5)
	_check(changed == 0, "trigger FX never change the die's albedo, body colour, emission or materials (%d frames changed)" % changed)
	_check(d.get_child_count() == kids and d.faces.get_child_count() == before["faces_children"], "nothing is parented onto the die")
	_free([fx, src, d])


func _test_coin_flight() -> void:
	var fx := _fx()
	var d := _die(Vector3.ZERO)
	var landed: Array[Node3D] = []
	fx.coin_landed.connect(func(x: Node3D) -> void: landed.append(x))
	fx.trigger_fx(&"gilded_payout", d)
	_step(fx, 0.6)
	_check(landed.is_empty(), "Gilded: the coin is still flying when the burst ends")
	_check(fx._coins.any(func(c: TriggerIcon) -> bool: return c.visible and c.icon == &"brass_coin"), "Gilded: a brass coin hops off the die")
	var frames_seen := {}
	for i in 12:
		await create_timer(0.025).timeout
		for c: TriggerIcon in fx._coins:
			if c.visible:
				frames_seen[c.coin_frame] = true
	_check(frames_seen.size() >= 2, "the coin flips through its sprite frames (%s)" % str(frames_seen.keys()))
	await create_timer(0.3).timeout
	_check(landed == [d], "Gilded: coin_landed fires when the coin reaches the pile (counter tick)")
	# The icon pops on the hit, holds about 0.5 s, then fades.
	fx.trigger_fx(&"mirror_copy", d)
	_step(fx, 0.25 + DT)
	var ic: TriggerIcon = fx._live[0].icon
	_step(fx, 1.0)
	await create_timer(0.35).timeout
	_check(ic.visible and ic.modulate.a == 1.0, "the icon still shows 0.35 s after the hit")
	await create_timer(0.45).timeout
	_check(not ic.visible, "and is gone by about 0.65 s")
	_free([fx, d])


func _test_aliases() -> void:
	var want := {&"coin": &"coin_heads_copy", &"ferrymans_coin": &"coin_heads_copy", &"ferryman": &"coin_heads_copy",
		&"ferryman_tails": &"coin_tails_copy", &"coin_tails": &"coin_tails_copy", &"coin_alone": &"coin_alone_heads",
		&"tithe": &"gilded_payout", &"tithe_10": &"gilded_payout", &"midnight": &"hellfire_face", &"midnight_12": &"hellfire_face",
		&"verdict_20": &"hellfire_face", &"lantern": &"wild_face", &"lantern_8": &"wild_face", &"mirror": &"mirror_copy",
		&"hellfire": &"hellfire_face", &"gilded": &"gilded_payout", &"wild": &"wild_face"}
	for id: StringName in want:
		_check(TriggerFxDefs.hook(id) == want[id] and TriggerFxDefs.ROWS.has(want[id]), "%s plays %s" % [id, want[id]])
	_check(TriggerFxDefs.flavor_of(&"verdict_20") == &"verdict" and TriggerFxDefs.flavor_of(&"midnight") == &"midnight"
			and TriggerFxDefs.flavor_of(&"tithe") == &"tithe" and TriggerFxDefs.flavor_of(&"lantern_8") == &"lantern", "die / face ids carry their flavour")
	var fx := _fx()
	var d := _die(Vector3(0, 0.04, 0))
	fx.trigger_fx(&"midnight", d)
	var b: TriggerFxPool.Burst = fx._live[0]
	_check(b.id == &"hellfire_face" and b.ctx.get("flavor") == &"midnight", "Midnight plays Hellfire with its flavour")
	_step(fx, 3.0 / 12.0 + DT)
	_check(b.frame.material_override.albedo_texture == TriggerShapes.texture(&"frame_hex", TriggerFxDefs.HELLFIRE), "Midnight: the hex frame")
	_step(fx, 1.0)
	fx.trigger_fx(&"lantern_8", d)
	b = fx._live[0]
	_step(fx, 2.0 / 12.0 + DT)
	_check(b.id == &"wild_face" and b.card.visible and b.card.material_override.albedo_texture == TriggerShapes.texture(&"spark_diamond", TriggerFxDefs.BONE),
			"Lantern 8: Wild's bone sparkle on the hit")
	_step(fx, 1.0)
	_free([fx, d])


## QA B2: the glint is the same short streak for dice 0.30 m and 0.40 m apart
## and on a diagonal; its basis stays orthonormal (no stretch along a world
## axis); it follows its arc from the source to the target, bowing sideways
## along the felt by 0.3 x the distance, never up.

