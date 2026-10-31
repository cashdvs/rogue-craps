## Layer 4 of the Bonfire table: one throw from launch to settle.
## Launching the handful, the pre-sim faces, landing / scoring rule
## triggers, face changes, lighting the scoring dice, and the bust.
@abstract
class_name BonfireThrowFlow
extends BonfireTableLayout


# Declared here, written in a later layer (the chain ends at Bonfire3D).
# "@abstract" only promises the function exists so this file can call it.
@abstract func fast_forward_juice() -> bool
@abstract func _end_sequence_after_forfeit() -> void
@abstract func _after_hand() -> void
@abstract func _to_hand(seconds: float = 0.22) -> void
@abstract func _kill_hand_tweens() -> void


## mod_triggered / triggers_resolved ctx for a face mod on die `d`.
func _mod_ctx(fm: FaceModData, d: DieVisual) -> Dictionary:
	if fm == null:
		return {}
	var dir := 1
	match fm.effect:
		FaceModData.Effect.BLANK:
			dir = -1
		FaceModData.Effect.WILD, FaceModData.Effect.HEAVY, FaceModData.Effect.KINDLING:
			dir = 0
	return {"flavor": StringName(String(FaceModData.Effect.keys()[fm.effect]).to_lower()),
		"target_die": event_id(d) if d != null else -1,
		"count": 2 if fm.effect == FaceModData.Effect.TWIN else 1, "direction": dir}


## TableEvents.triggers_resolved entry.
func _trigger(stage: StringName, row_id: StringName, die_id: int, anchor: StringName, ctx: Dictionary, start_s: float, tier: int = 0) -> Dictionary:
	return {"stage": stage, "row_id": row_id, "tier": tier, "die_id": die_id,
		"intensity": clampf(tier / 4.0, 0.0, 1.0), "anchor": anchor, "ctx": ctx, "start_s": start_s}


## The settle half of triggers_resolved for a landed throw (land, copies,
## boss, lit check; see TableEvents). ok = land_throw's result.
func landing_triggers(th: TableThrow, ok: bool) -> Array:
	var out: Array = []
	var by_stage: Dictionary = {&"land": [], &"copies": [], &"boss": [], &"lit": []}
	for ch: Dictionary in th.changes:
		var i := int(ch["index"])
		var by := StringName(ch.get("by", &""))
		var stage := &"land"
		if by == &"mirror":
			stage = &"copies"
		else:
			for r in run.rules:
				if r.id == by and r.kind == TableRule.Kind.CHEAT:
					stage = &"boss"
		var d: DieVisual = throw_dice[i] if i < throw_dice.size() else null
		var target := -1
		if stage == &"copies" and th.positions.size() == th.size():
			# The die it copied: the nearest non-Mirror die with that value.
			var best := INF
			for j in th.size():
				if j != i and th.special(j) != &"mirror" and th.values[j] == int(ch["to"]) and th.positions[i].distance_to(th.positions[j]) < best:
					best = th.positions[i].distance_to(th.positions[j])
					target = event_id(throw_dice[j]) if j < throw_dice.size() else j
		(by_stage[stage] as Array).append(_trigger(stage, by, event_id(d) if d != null else i, &"die",
			{"flavor": stage, "target_die": target, "count": 1, "direction": signi(int(ch["to"]) - int(ch["from"])), "from": int(ch["from"]), "to": int(ch["to"])}, 0.0))
	var lit_at := 0.0 if th.changes.is_empty() else FLIP_TIME + 0.08
	if ok:
		for i in run.throw_faces.size():
			for r in run.rules:
				if not r.can_light(run, run.throw_faces[i]):
					var d: DieVisual = throw_dice[i] if i < throw_dice.size() else null
					(by_stage[&"lit"] as Array).append(_trigger(&"lit", r.id, event_id(d) if d != null else i, &"die",
						{"flavor": &"kept_dark", "target_die": event_id(d) if d != null else i, "count": 1, "direction": -1}, lit_at))
					break
	else:
		var ids: Array = []
		for d in throw_dice:
			ids.append(event_id(d))
		var what := &"kindling_saved" if run.kindling_saved else &"bust"
		(by_stage[&"lit"] as Array).append(_trigger(&"lit", what, -1, &"table",
			{"flavor": what, "target_die": -1, "count": ids.size(), "direction": 0 if run.kindling_saved else -1, "die_ids": ids}, lit_at))
	for st: StringName in _STAGE_ORDER:
		if by_stage.has(st):
			out.append_array(by_stage[st])
	return out


## The scoring half of triggers_resolved for the pot about to be counted
## (call after _pip_die / _pip_mods / _pip_ctx / _juice_dice are set): one
## entry per mod face, in pip order. start_s = pip_s - PIP_LEAD (>= 0).
func scoring_triggers(n_pips: int, n_extra_chips: int, tier: int) -> Array:
	var plan := JuicePlan.timeline(n_pips, n_extra_chips, tier, speed_mode, bonfire_tuning)
	var pips: Array = plan["pips"]
	var clock := maxf(test_speed, 0.001)
	var lift_clock := clock * (2.0 if speed_mode == 1 else 1.0) * (20.0 if speed_mode == 2 else 1.0)
	var stagger := (0.14 if plan["big"] else 0.08) / lift_clock
	var out: Array = []
	for i in _pip_die.size():
		var k: int = _pip_die[i]
		if k < 0 or k >= _pip_mods.size() or _pip_mods[k] == &"" or (i > 0 and _pip_die[i - 1] == k) or k >= _juice_dice.size():
			continue
		var pip_s := float(pips[i]) / clock if i < pips.size() else 0.0
		var e := _trigger(&"scoring", _pip_mods[k], event_id(_juice_dice[k]), &"pip", _pip_ctx[k] if k < _pip_ctx.size() else {},
			maxf(pip_s - TableEvents.PIP_LEAD, 0.0), tier)
		e["pip_s"] = pip_s
		e["lift_s"] = k * stagger
		out.append(e)
	return out


## events.table_cleared, once per table (a clear, then Leave, sends one).
func _emit_table_cleared() -> void:
	if _cleared_emitted:
		return
	_cleared_emitted = true
	if run.goal.target > 0:
		events.goal_reached.emit()  # target tables: the goal sting first (#222)
	events.table_cleared.emit()


func _play_total_roll(slots: Array[int], velocity: Vector2, release_pos: Vector2) -> void:
	# A throw ends any count-up still running; lifted / trailing dice let go.
	fast_forward_juice()
	juice.drop(all_dice, true)
	juice.fly_stop(all_dice)
	bhud.pulse_cards([])
	throw_slots = slots.duplicate()
	var values := _values_for(slots)
	var mods := _mods_for(slots)
	last_values = values
	# Throw from the hand ring even if the gather tween hasn't finished.
	_kill_hand_tweens()
	for i in dice.size():
		dice[i].global_transform = Transform3D(dice[i].global_transform.basis, hand_spot(i))
	throw_dice = dice.duplicate()
	for d in throw_dice:
		_set_lit(d, false)
	throw_started.emit()
	thrown.emit(velocity.length())
	_set_why("")
	await _throw_dice(slots, velocity, release_pos)
	if run.is_over():
		_end_sequence_after_forfeit()
		return
	phase = Phase.REVEAL
	dice_landed.emit(values)
	camera.follow(_dice_center(), tuning.cam_reveal_time)
	await _wait(tuning.reveal_hold)
	if run.is_over():
		_end_sequence_after_forfeit()
		return
	_punch_dice()
	events.dice_settled.emit()
	sfx.play(&"dice_settle", 1.0, -3.0)
	_felt_pos.clear()
	for d in throw_dice:
		_felt_pos.append(d.global_position)
	var tds: Array = []
	for i in throw_dice.size():
		tds.append(_td(i))
	var th := TableThrow.make(values, mods, tds, run.rng)
	th.slots = slots.duplicate()
	th.positions = _felt_pos.duplicate()
	nerve.landed = slots.duplicate()
	var ok := run.land_throw(th)
	_compute_throw_claims()
	events.triggers_resolved.emit(landing_triggers(th, ok))
	if not th.changes.is_empty():
		await _show_face_changes(th)
		if run.is_over():
			_end_sequence_after_forfeit()
			return
	values = run.throw_faces.duplicate()
	last_values = values
	var lit := run.lit()
	throw_resolved.emit(values, lit)
	emit_selection()
	if not ok and run.free_rethrow:
		# Nonstandard dice: a full throw that lit nothing is thrown again free.
		bhud.flash("Nothing lit: free rethrow", Palette.BONE)
		_set_why("A full throw can't bust. Throw the %d dice again." % run.cold)
		_to_hand()
		phase = Phase.BET
	elif not ok and run.kindling_saved:
		# A Kindling face: nothing lit, but no bust. Same dice, throw again.
		bhud.flash("KINDLING!  NO BUST", Palette.EMBER)
		sfx.play(&"rim_hit", 1.3, -4.0)
		_embers(_dice_center(), 14, 6)
		_set_why("Kindling saved it: nothing lit, but no bust. Throw the %d dice again." % run.cold)
		_to_hand()
		phase = Phase.BET
	elif not ok and run.bust_pending:
		# Nerve can save it: wait for the rescue prompt (NerveUi).
		# The rescue prompt (NerveUi) says it; HN1 only the first time.
		_set_why("")
		onboarding.on_nerve_rescue()
		for d in throw_dice:
			_set_cold(d)
		phase = Phase.BET
	elif ok:
		nerve.open_throw(th)
		for i in throw_dice.size():
			if i in lit:
				_set_lit(throw_dice[i], true)
				_embers(throw_dice[i].global_position, 8, 2)
			else:
				_set_cold(throw_dice[i])
		sfx.play(&"rim_hit", 0.8, -6.0)
		_set_why("%d lit. Click dice into the pot: one combo per throw." % lit.size())
		phase = Phase.BET
		onboarding.on_lit_settle()
	else:
		await _bust()
	_skip = false
	Engine.time_scale = 1.0
	_refresh_hud()
	sequence_finished.emit()


## Throw momentum: the flick's speed scales the launch speed, its arc and
## the spin (bonfire_tuning "Throw momentum"). Direction is Table3D's (flick
## direction kept in the aim cone).
func launch_for(velocity: Vector2, release_pos: Vector2) -> Dictionary:
	var base := super(velocity, release_pos)
	var bt := bonfire_tuning
	var k := launch_k(velocity.length())
	var speed := lerpf(bt.launch_speed_min_mps, bt.launch_speed_max_mps, k)
	var up := lerpf(bt.launch_up_min_mps, bt.launch_up_max_mps, k)
	var spin_mag := lerpf(bt.spin_min_rad_s, bt.spin_max_rad_s, k)
	var lin: Array[Vector3] = []
	var spin: Array[Vector3] = []
	var n := dice.size()
	var dir := Vector2(base["lin"][0].x, base["lin"][0].z).normalized()
	if n > 1:
		# Undo Table3D's 4-degree fan on die 0 to get the aim direction back.
		var c := Vector2.ZERO
		for v: Vector3 in base["lin"]:
			c += Vector2(v.x, v.z).normalized()
		dir = c.normalized()
	for i in n:
		var f := 0.0 if n == 1 else (float(i) - float(n - 1) * 0.5) / (float(n - 1) * 0.5)
		var d := dir.rotated(deg_to_rad(bt.fan_deg * f))
		var s := speed * (1.0 + 0.04 * f)
		lin.append(Vector3(d.x * s, up, d.y * s))
		var axis: Vector3 = base["spin"][i]
		axis = axis.normalized() if axis.length() > 0.001 else Vector3.RIGHT
		spin.append(axis * spin_mag * (1.0 + _fx_rng.randf_range(-bt.spin_jitter, bt.spin_jitter)))
		if i < n and dice[i].shape == &"coin":
			# Ferryman's Coin: a hard end-over-end flip about a diameter plus
			# extra lift, both growing with the flick, so it visibly flips.
			var cn := dice[i].global_transform.basis.orthonormalized() * Vector3.UP
			var flip := CoinPhysics.flip_axis(cn, lin[i], _fx_rng, deg_to_rad(bt.coin_axis_jitter_deg))
			spin[i] = flip * lerpf(bt.coin_flip_min_rad_s, bt.coin_flip_max_rad_s, k) * (1.0 + _fx_rng.randf_range(-bt.spin_jitter, bt.spin_jitter))
			lin[i].y += lerpf(bt.coin_lift_min_mps, bt.coin_lift_max_mps, k)
	last_launch = {"lin": lin, "spin": spin, "speed": speed, "k": k, "flick": velocity.length()}
	_show_throw_debug(velocity.length(), speed, k)
	throw_measured.emit(velocity.length(), speed, k)
	return last_launch


func _build_throw_debug() -> void:
	throw_debug_label = Label.new()
	throw_debug_label.name = "ThrowDebug"
	throw_debug_label.label_settings = Palette.label_settings(26, Palette.BRASS_HI, 6)
	throw_debug_label.add_theme_stylebox_override("normal", Palette.ink_box(Color(Palette.PIT_BLACK, 0.85), 8, 2, Palette.BRASS))
	throw_debug_label.position = Vector2(24, 1000)
	throw_debug_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	throw_debug_label.visible = false
	bhud.add_child(throw_debug_label)
	var gs := get_node_or_null("/root/GameSettings")
	var on := gs != null and "throw_debug" in gs and bool(gs.get("throw_debug"))
	throw_debug = on or OS.get_cmdline_user_args().has("--throw-debug")


func _show_throw_debug(flick_px_s: float, launch_mps: float, k: float) -> void:
	if throw_debug_label == null:
		return
	throw_debug_label.text = "THROW  flick %.0f px/s  ->  launch %.2f m/s   curve %.2f" % [flick_px_s, launch_mps, k]
	throw_debug_label.visible = throw_debug


## Options > Throw sensitivity multiplies the flick speed (keyboard quick
## throws stay a fixed medium throw).
func throw(velocity: Vector2, release_pos: Vector2 = Vector2.INF, drag: float = -1.0) -> bool:
	# The tutorial may rig this throw's faces (never over a test's own rig).
	var seeded := _rig.is_empty() and phase == Phase.BET and onboarding.seed_next_throw()
	var ok := super(velocity * (sensitivity() if _player_flick else 1.0), release_pos, drag)
	if ok:
		seeded_throws.append(seeded)
		bhud.tutorial.on_action(&"thrown")
	elif seeded:
		_rig.clear()
	return ok


## Rule moments the table shows (juice / audio hook the same
## BonfireRun.table_event).
func _on_table_event(event: StringName, data: Dictionary) -> void:
	match event:
		&"die_shattered":
			var i: int = data.get("index", -1)
			if i >= 0 and i < throw_dice.size():
				_shatter_die(throw_dice[i])
		&"pot":
			# Blood faces pay Soul as the pot scores.
			_burn_soul(int(data.get("soul_cost", 0)))
		&"hand_start":
			_refresh_hud()
			onboarding.on_hand_start()


## Rule face changes (Madame Shuffle's reroll, a Mirror's copy): each changed
## die flips to its new face with a tint, before anything lights.
func _show_face_changes(th: TableThrow) -> void:
	var seen: Dictionary = {}
	for ch: Dictionary in th.changes:
		seen[int(ch["index"])] = ch
	for i: int in seen:
		if i >= throw_dice.size():
			continue
		var ch: Dictionary = seen[i]
		var d := throw_dice[i]
		var slot := int(th.slots[i])
		if i < throw_slots.size():
			throw_slots[i] = slot
		var phys := DieVisual.value_up(d.global_transform.basis)
		var to := DieVisual.remap_basis(phys, d.mesh_face(slot)).get_rotation_quaternion()
		if i < _remap_to.size() and dice.has(d):
			var k := dice.find(d)
			_remap_from[k] = to
			_remap_to[k] = to
		var from := d.faces.quaternion
		var base := d.faces.position
		var tint: Color = CHANGE_TINT.get(StringName(ch.get("by", &"")), CHANGE_TINT_DEFAULT)
		d.body_material.set_shader_parameter("emission_color", tint)
		var tw := d.create_tween()
		tw.tween_method(func(k: float) -> void:
			d.faces.quaternion = from.slerp(to, k)
			d.faces.position = base + Vector3(0, sin(k * PI) * d.edge * 0.7, 0)
			d.body_material.set_shader_parameter("emission_energy", 0.9 * (1.0 - k * 0.6)), 0.0, 1.0, FLIP_TIME)
		tw.tween_callback(func() -> void: d.faces.position = base)
	var by_cheat: Dictionary = {}
	for i: int in seen:
		var by := StringName((seen[i] as Dictionary).get("by", &""))
		for r in run.rules:
			if r.id == by and r.kind == TableRule.Kind.CHEAT and i < throw_dice.size():
				if not by_cheat.has(by):
					by_cheat[by] = []
				(by_cheat[by] as Array).append(event_id(throw_dice[i]))
	for by: StringName in by_cheat:
		events.boss_cheat.emit(by, by_cheat[by])
	sfx.play(&"chip_place", 0.7, -2.0)
	await _wait(FLIP_TIME + 0.08)
	for i: int in seen:
		if i < throw_dice.size():
			_set_lit(throw_dice[i], false)


func _bust() -> void:
	phase = Phase.RESOLVE
	var r := run.last_result
	bhud.flash("BUST!  -%d SOUL" % int(r["soul_lost"]), Color("#FF2E3E"))
	_burn_soul(int(r["soul_lost"]))
	_camera_shake(tuning.shake_craps_px, 0.3)
	# Flames snuff, dice ash over, the Soul flask cracks, pending stamps crumble.
	var bust_ids: Array = []
	for d in throw_dice:
		bust_ids.append(event_id(d))
	events.bust.emit(int(r["soul_lost"]), bust_ids)
	juice.bust(throw_dice, reduced_motion)
	var lost_cards: Array = bhud.pending_cards()
	bhud.crumble_pending(reduced_motion)
	bhud.flask_crack(reliquary.bust(run, camera.cam), reduced_motion)
	juice.crowd_pot(0)
	bhud.countup.clear()
	# HB5 replaces TH9 when the bust lost a pending bounty (TH9 stays unseen).
	onboarding.on_bust(int(r["soul_lost"]), lost_cards)
	_embers(_dice_center(), 24, 10)
	_taunt(&"bonfire_bust")
	_set_why("Nothing lit. Bust: pot of %d lost, -%d Soul." % [int(r["lost_pot"]), int(r["soul_lost"])])
	# HANDS LEFT etc. now, not after the beat (a final bust ends the table
	# and the end screen shows over this HUD; QA full run pass 1).
	_refresh_hud()
	hand_result.emit(r)
	await _wait(1.0)
	await _after_hand()


## Sends events.selection_changed with the potted and joinable die ids.
func emit_selection() -> void:
	var potted_ids: Array = []
	var joinable_ids: Array = []
	if run != null and run.state == BonfireRun.State.PICK:
		for i in mini(throw_dice.size(), run.throw_faces.size()):
			if run.potted.has(i):
				potted_ids.append(event_id(throw_dice[i]))
			elif run.can_join(i):
				joinable_ids.append(event_id(throw_dice[i]))
	events.selection_changed.emit(potted_ids, joinable_ids)
