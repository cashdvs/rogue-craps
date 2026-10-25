## Layer 5 of the Bonfire table: what the player does after a throw.
## Potting a lit die, throwing the rest again, banking with the count-up,
## and the Nerve rescue glue.
@abstract
class_name BonfirePotBank
extends BonfireThrowFlow


## Space / THROW: in AIM throws the dice; after a throw, pots the picked dice
## and gathers the cold ones (or all of them on a Hot Hand) into the hand.
func throw_again() -> bool:
	if phase != Phase.BET or run.is_over():
		return false
	if run.state == BonfireRun.State.AIM:
		return quick_throw()
	var potted_now: Array[DieVisual] = []
	for i in run.potted:
		potted_now.append(throw_dice[i])
	var cold_now: Array[DieVisual] = []
	for i in throw_dice.size():
		if not run.potted.has(i):
			cold_now.append(throw_dice[i])
	var why := run.rethrow_block_reason()
	var sel := run.selection()
	var hot_before := run.hot_hands
	var per_hot := run.mult_bonus() / maxi(hot_before, 1)
	var faces_now := run.selection_faces()
	var hold := _display_snapshot(sel)
	var rt := run.rethrow()
	if rt.is_empty():
		_refuse(why if why != "" else "Pot at least one lit die first.")
		return false
	bhud.tutorial.on_action(&"rethrow")
	nerve.close_throw()
	pot_dice.append_array(potted_now)
	# Back to the home framing (the reveal left the camera zoomed in on the
	# dice): the count-up and its fire play on the pot row, and the next
	# flick starts from the hand. On a portrait phone the pot is otherwise
	# off-screen for the whole count-up.
	camera.go_home(tuning.cam_return_time)
	_start_count_up(sel, potted_now, faces_now, hot_before, per_hot)
	_hold_display(hold)
	juice.crowd_pot(run.pot)
	if rt["hot"]:
		_taunt(&"bonfire_hot")
		# The lists change now; the dice ignite and fly back after the count-up.
		pot_dice.clear()
		throw_dice.clear()
		_set_active(all_dice)
		_hot_hand_moment()
		_set_why("Hot Hand! All %d dice back, +%d mult on every pot this hand." % [run.cold, run.mult_bonus()])
		onboarding.on_hot_hand()
	else:
		for d in cold_now:
			_set_lit(d, false)
		_set_active(cold_now)
		_to_hand()
		_set_why("Pot %d. Flick the %d cold dice, or regret it." % [run.pot, run.cold])
	_refresh_hud()
	return true


## Hot Hand: after the count-up every die ignites, the banner reads
## "HOT HAND xN", and the dice fly back to the hand trailing fire.
func _hot_hand_moment() -> void:
	if bhud.countup.is_playing():
		await bhud.countup.finished
	if run.is_over() or phase != Phase.BET:
		return
	var list := all_dice.duplicate()
	juice.drop(list, true)
	for d in list:
		_set_lit(d, false)
		d.visible = true
		d.scale = Vector3.ONE
	juice.hot_hand(list)
	bhud.flash("Hot Hand x%d: +%d mult" % [run.hot_hands, run.mult_bonus()], Palette.EMBER)
	var fly := bonfire_tuning.juice_hot_hand_fly_time if not reduced_motion else 0.22
	if speed_mode == 2:
		fly = 0.05
	var ids: Array = []
	for d in list:
		ids.append(event_id(d))
	var count := run.hot_hands
	events.hot_hand_fly.emit(ids, fly)
	juice.fly_start(list, fly)
	_to_hand(fly)
	# The Hot Hand sound (scripts/fx/table_audio.gd) is the dice arriving.
	_timer(fly, true, false, false).timeout.connect(func() -> void: events.hot_hand.emit(count))
	_timer(fly + 0.05, true, false, false).timeout.connect(func() -> void: juice.fly_stop(list))


## Starts the count-up for a committed pot (sel = its score before commit).
func _start_count_up(sel: Dictionary, dice_list: Array[DieVisual], faces: Array, hot_hands: int, per_hot: int) -> void:
	if not sel.get("valid", false):
		return
	if bhud.countup.is_playing():
		bhud.countup.fast_forward()
	var t := bonfire_tuning
	var tier := JuicePlan.tier(int(sel["points"]), t)
	var chips := JuicePlan.chips(sel, hot_hands, per_hot)
	var vals: Array = sel["values"]
	_pip_die.clear()
	for k in faces.size():
		var f: Dictionary = faces[k]
		var m: FaceModData = f.get("mod")
		var n := 2 if m != null and m.effect == FaceModData.Effect.TWIN and not run.rule_ctx()["no_mods"] else 1
		for j in n:
			_pip_die.append(k)
	_juice_dice = dice_list.duplicate()
	_juice_tier = tier
	_pip_mods.clear()
	_pip_ctx.clear()
	var wild := -1
	for k in faces.size():
		var fm: FaceModData = (faces[k] as Dictionary).get("mod")
		_pip_mods.append(fm.id if fm != null and not run.rule_ctx()["no_mods"] else &"")
		_pip_ctx.append(_mod_ctx(fm, dice_list[k] if k < dice_list.size() else null))
		if wild < 0 and fm != null and fm.effect == FaceModData.Effect.WILD and not run.rule_ctx()["no_mods"]:
			wild = k
	# JIT4 points at the first Wild face (its index in the throw, -1 = none).
	var wd := throw_dice.find(dice_list[wild]) if wild >= 0 and wild < dice_list.size() else -1
	onboarding.on_pot(StringName(sel.get("combo", &"")), wd)
	var ids: Array = []
	for d in dice_list:
		ids.append(event_id(d))
	events.combo_potted.emit(StringName(sel.get("combo", &"")), ids, int(sel["points"]), int(sel.get("mult", 0)), tier)
	# The scoring triggers with their start times, before the count-up is
	# planned (TableEvents.triggers_resolved).
	events.triggers_resolved.emit(scoring_triggers(vals.size(), chips.size() - 1, tier))
	var plan := JuicePlan.timeline(vals.size(), chips.size() - 1, tier, speed_mode, t)
	juice.lift(_juice_dice, plan["big"], test_speed * (2.0 if speed_mode == 1 else 1.0) * (20.0 if speed_mode == 2 else 1.0))
	bhud.countup.play({"base": int(sel["base"]), "values": vals, "chips": chips, "points": int(sel["points"]),
		"name": str(sel["name"]), "score_tier": tier, "banner_tier": JuicePlan.banner_tier(StringName(sel["combo"]), t)},
		plan, test_speed, reduced_motion)


func _on_count_pip(i: int) -> void:
	if speed_mode != 2:
		juice.pip_sound(i)
	var k: int = _pip_die[i] if i < _pip_die.size() else -1
	if k >= 0 and k < _pip_mods.size() and _pip_mods[k] != &"" and (i == 0 or _pip_die[i - 1] != k) and k < _juice_dice.size():
		events.mod_triggered.emit(_pip_mods[k], _juice_tier, event_id(_juice_dice[k]), clampf(_juice_tier / 4.0, 0.0, 1.0), Time.get_ticks_msec(), &"pip", _pip_ctx[k] if k < _pip_ctx.size() else {})
	if k >= 0 and k < _juice_dice.size() and is_instance_valid(_juice_dice[k]):
		var d := _juice_dice[k]
		d.body_material.set_shader_parameter("emission_color", Palette.EMBER)
		d.body_material.set_shader_parameter("emission_energy", 1.1)


func _on_count_banner(score_tier: int, _banner_tier: int) -> void:
	if speed_mode == 2:
		juice.sfx(juice.stinger(score_tier), 1.0, 0.0, 0.0, &"rim_hit", 1.2, -6.0)
	else:
		juice.banner_sound(score_tier)
	juice.escalate(score_tier, _juice_dice, reduced_motion, speed_mode == 2)


## Tap / click / any action: finish the count-up now.
func fast_forward_juice() -> bool:
	if bhud.countup.is_playing():
		bhud.countup.fast_forward()
		return true
	return false


func bank() -> Dictionary:
	if phase != Phase.BET or not run.can_continue():
		_refuse("Pot at least one lit die to bank.")
		return {}
	bhud.tutorial.on_action(&"bank")
	fast_forward_juice()
	var sel := run.selection()
	var hot_before := run.hot_hands
	var per_hot := run.mult_bonus() / maxi(hot_before, 1)
	var faces_now := run.selection_faces()
	var potted_now: Array[DieVisual] = []
	for i in run.potted:
		potted_now.append(throw_dice[i])
	var all_pot: Array[DieVisual] = pot_dice.duplicate()
	all_pot.append_array(potted_now)
	var hold := _display_snapshot(sel)
	nerve.close_throw()
	var r := run.bank()
	phase = Phase.RESOLVE
	# Not picking any more: tell listeners nothing is potted or joinable.
	emit_selection()
	_start_count_up(sel, potted_now, faces_now, hot_before, per_hot)
	_hold_display(hold)
	if bhud.countup.is_playing():
		await bhud.countup.finished
	# Bank: embers flow to the pile, each claimed bounty gets its wax stamp.
	bhud.flash("Banked +%d" % int(r["gain"]), Palette.BRASS_HI)
	events.banked.emit(int(r["gain"]))
	juice.bank_sound()
	juice.crowd_pot(0)
	_taunt(&"bonfire_bank")
	var flow := bonfire_tuning.juice_bank_flow_time if speed_mode != 2 else 0.05
	bhud.ember_flow(int(r["gain"]) / 25, flow, reduced_motion)
	juice.ember_pile(pot_slot(0) + Vector3(-0.12, -tuning.die_size * 0.5, 0))
	var names: Array[String] = []
	for b: BountyData in run.all_bounties():
		if (r["ticked"] as Array).has(b.id):
			names.append(b.display_name)
	bhud.flash_ticks(r["ticked"])
	for id: StringName in r["ticked"]:
		bhud.stamp_claimed(id, reduced_motion)
		events.bounty_claimed.emit(id)
		juice.stamp_sound()
		if speed_mode != 2:
			await _wait(bonfire_tuning.juice_stamp_gap / test_speed)
	onboarding.on_bank(r)
	juice.drop(all_pot)
	bhud.countup.clear()
	_set_why("Banked %d points.%s" % [int(r["gain"]), (" Bounty: " + ", ".join(names) + "!") if not names.is_empty() else ""])
	if r.get("cleared_now", false):
		# The clear moment: Embers locked in, the table stays open (unless
		# that was the last hand, then it ends right after this).
		bhud.show_cleared(2.0 if speed_mode == 1 else 1.0, speed_mode == 2 or reduced_motion)
		_emit_table_cleared()
		_taunt(&"bonfire_clear")
		if not run.is_over():
			_set_why("Table cleared! Chase the bonus with your remaining hands, or Leave table.")
	_refresh_hud()
	hand_result.emit(r)
	await _after_hand()
	return r


## Clicks die `i` of the current throw (pots / unpots it; refused if it
## couldn't be part of one combo with the dice already potted).
func pick_die(i: int) -> bool:
	if phase != Phase.BET or run.state != BonfireRun.State.PICK or i < 0 or i >= throw_dice.size():
		return false
	if not run.toggle(i):
		# It bounces back where it was, with a "doesn't score" callout.
		# Its sound (no_score) is played by scripts/fx/table_audio.gd.
		events.no_score.emit()
		refused.emit(i)
		var d := throw_dice[i]
		var tw := d.create_tween()
		var p := d.position
		var hop := tuning.die_size * 0.6
		tw.tween_property(d, "position", p + Vector3(0, hop, 0), 0.08).set_ease(Tween.EASE_OUT)
		tw.tween_property(d, "position", p, 0.14).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		bhud.callout(camera.cam.unproject_position(d.global_position + Vector3(0, tuning.die_size, 0)), NO_SCORE_TEXT)
		bhud.tutorial.on_action(&"refused")
		# Just-in-time or never: it doesn't wait behind another hint.
		onboarding.on_refused(i)
		_set_why("That die doesn't score with this combo (a pot is exactly ONE combo).")
		return false
	sfx.play(&"chip_place", 1.1, -3.0)
	nerve.on_potted()
	emit_selection()
	_layout_throw()
	if not run.potted.is_empty():
		bhud.tutorial.on_action(&"potted")
	if run.can_continue():
		bhud.tutorial.on_action(&"valid_selection")
		onboarding.on_selection()
	_refresh_hud()
	return true


## The rethrow prompt with its exact bust risk ("Throw 2 cold dice: 1 in 3
## burns", BustRisk). "" when there's no rethrow to talk about.
func rethrow_prompt() -> String:
	var n := next_throw_size()
	if n <= 0:
		return ""
	var tds: Array = []
	var kindling := false
	var hot := false
	if run.state == BonfireRun.State.PICK:
		var sel := run.selection()
		kindling = bool(sel.get("kindling", false))
		hot = run.is_hot()
		if hot:
			for d in all_dice:
				tds.append(_die_of.get(d))
		else:
			for i in throw_dice.size():
				if not run.potted.has(i):
					tds.append(_die_of.get(throw_dice[i]))
	else:
		kindling = run.kindling_armed
		# Mid-rethrow the active dice can still be the whole handful (the cold
		# ones go active right after): no prompt until they match.
		if dice.size() != n:
			return ""
		for d in dice:
			tds.append(_die_of.get(d))
	var key := "%d|%s|%s|%d|%d|%d" % [n, str(tds.map(func(t: Variant) -> int: return t.get_instance_id() if t != null else 0)), kindling, run.soul, run.throws_this_hand, run.rules.size()]
	if key != _risk_key:
		_risk_key = key
		_risk = run.next_throw_risk(tds, kindling)
	return BustRisk.prompt(n, _risk, hot)


func _add_chip() -> String:
	return ""


func _take_down() -> String:
	return ""


## Nerve (nerve_v1.md): builds Nerve for this table from setup.nerve_uses.
func _start_nerve() -> void:
	if nerve == null:
		nerve = NerveTable.new()
		add_child(nerve)
		nerve_ui = NerveUi.new()
		bhud.add_child(nerve_ui)
		nerve_ui.setup(nerve)
	var tds: Array[TableDie] = []
	for d in all_dice:
		tds.append(_die_of.get(d, TableDie.new()))
	nerve.start(self, run, tds, setup.nerve_uses)


## The rescue prompt's Bust: the held bust happens now.
func nerve_bust() -> void:
	run.confirm_bust()
	await _bust()
	_refresh_hud()


func _after_hand() -> void:
	if run.is_over():
		# Out of hands uncleared: the Soul meter drops by the table's
		# penalty, like a bust or forfeit (QA M4). A cleared table costs no
		# Soul here, so nothing burns. Only the part not shown yet burns: a
		# final-hand bust already burned its Soul in _bust(), and maxi()
		# keeps this from going negative.
		_burn_soul(maxi(_soul_shown - run.soul, 0))
		pause_menu.set_forfeit_enabled(false)
		phase = Phase.OVER
		_taunt(&"bonfire_clear" if run.state == BonfireRun.State.CLEARED else &"bonfire_fail")
		bhud.show_end(run)
		_refresh_hud()
		return
	phase = Phase.RESET
	camera.go_home(tuning.cam_return_time)
	await _wait(0.25)
	if run.is_over():  # forfeited meanwhile
		phase = Phase.OVER
		return
	_reset_hand_dice()
	phase = Phase.BET
	_refresh_hud()


## Every die back in the hand, unlit, all of them in the next throw.
func _reset_hand_dice() -> void:
	pot_dice.clear()
	throw_dice.clear()
	for d in all_dice:
		_set_lit(d, false)
		d.visible = true
		d.scale = Vector3.ONE
	_set_active(all_dice)
	_to_hand()


func _to_hand(seconds: float = 0.22) -> void:
	_kill_hand_tweens()
	# A juice lift / settle tween must not pull a die back while it flies home.
	if juice != null:
		juice.drop(dice, true)
	for i in dice.size():
		var d := dice[i]
		var tw := d.create_tween()
		_hand_tweens.append(tw)
		tw.tween_method(_arc_die.bind(d, d.global_position, hand_spot(i)), 0.0, 1.0, seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)


func _kill_hand_tweens() -> void:
	for tw in _hand_tweens:
		if tw.is_valid():
			tw.kill()
	_hand_tweens.clear()
