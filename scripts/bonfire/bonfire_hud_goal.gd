## Layer 2 of the Bonfire HUD: the goal / bounty readout and meters.
## Refreshing the numbers, the rule rows, the bounty checklist and cards,
## stamps and crumbles, and the UI scale.
@abstract
class_name BonfireHudGoal
extends BonfireHudBuild


# Declared here, written in a later layer (the chain ends at BonfireHud).
# "@abstract" only promises the function exists so this file can call it.
@abstract func _reset_leave_ask() -> void
@abstract func _place_result() -> void


func refresh(run: BonfireRun, can_act: bool) -> void:
	coin_label.text = "EMBERS %d" % (_run_embers() + int(display_hold.get("embers", run.embers)))
	# Points are income (section 4): "points 572 → +5 Embers".
	var pts := int(display_hold.get("points", run.points))
	points_label.text = "points %d → +%d Embers" % [pts, BonfireRun.points_to_embers(run.tuning, pts)]  # capped like the payout
	hands_label.text = "Hands left: %d" % run.hands_left
	_refresh_checklist(run)
	portrait_goal.refresh(run)
	_place_result()
	_refresh_rules(run)
	var picking := run.state == BonfireRun.State.PICK
	if display_hold.has("pot_from"):
		hold_count(float(display_hold.get("f", 0.0)))
	elif picking and run.throw_points() > 0:
		# The selection is a preview until the count-up banks it into the pot.
		pot_label.text = "Pot %d (+%d)" % [run.pot, run.throw_points()]
	else:
		pot_label.text = "Pot %d" % run.hand_pot()
	notes_label.text = ""
	risk_label.text = ""
	if display_hold.has("pot_from"):
		# A count-up is playing (rethrow / bank): the old preview line or
		# "Not a combo yet." would stick under the Pot, so show nothing.
		throw_label.text = ""
	elif picking:
		var sel := run.selection()
		if sel["valid"]:
			# The live pot preview, e.g. "TRIPS: (30+12) x3 = 126", and what
			# changed it (Hot Hand, Hellfire...), then the rethrow risk.
			throw_label.text = BonfireScoring.preview(sel)
			notes_label.text = "  ·  ".join(BonfireScoring.factor_notes(run.selection_faces(), sel, run.tuning, run.mult_bonus(), run.rule_ctx()))
			risk_label.text = rethrow_prompt
		elif run.potted.is_empty():
			throw_label.text = "%s lit dice to pot one combo." % ("Tap" if tutorial.touch else "Click")
		else:
			throw_label.text = "Not a combo yet."
	elif run.forfeited or run.is_over():
		throw_label.text = ""
	elif rethrow_prompt != "":
		# Cold dice waiting to be thrown again: say how risky it is.
		throw_label.text = rethrow_prompt
	else:
		throw_label.text = "Grab the %d dice and flick them." % run.cold
	mult_label.text = ("+%d mult" % run.mult_bonus()) if run.mult_bonus() > 0 else ""
	bank_button.disabled = not (can_act and run.can_continue())
	if picking:
		throw_button.disabled = not (can_act and run.rethrow_block_reason() == "")
		throw_button.text = "Hot Hand: throw all %d dice" % run.dice_count if run.is_hot() else "Rethrow %d cold dice" % (run.throw_faces.size() - run.potted.size())
	else:
		throw_button.disabled = not can_act
		throw_button.text = "Throw %d dice" % run.cold
	var why := action_reasons(run, can_act)
	throw_button.tooltip_text = why["throw"]
	bank_button.tooltip_text = why["bank"]
	# The caption names the first greyed-out button's reason while picking.
	action_reason.text = why["throw"] if why["throw"] != "" else (why["bank"] if picking else "")


## Clears the score lines under the Pot (preview, notes, risk). Called at
## hand end, where no HUD refresh runs during the short pause between hands.
## Rethrow, bank, leave and a new table don't need it: refresh() runs in the
## same frame and rewrites all three lines (QA #160).
func clear_score_text() -> void:
	throw_label.text = ""
	notes_label.text = ""
	risk_label.text = ""


## The held pot counts up with the count-up (f = 0..1).
func hold_count(f: float) -> void:
	if not display_hold.has("pot_from"):
		return
	display_hold["f"] = f
	pot_label.text = "Pot %d" % (int(display_hold["pot_from"]) + int(round(int(display_hold.get("pot_add", 0)) * clampf(f, 0.0, 1.0))))


## One row per active rule: NAME (brass; red for a boss cheat) + its line.
func _refresh_rules(run: BonfireRun) -> void:
	var want: Array[String] = []
	for r in run.rules:
		want.append("%s|%s|%d" % [r.display_name, r.info_line(run), r.kind])
	var have: Array[String] = []
	for c in rules_box.get_children():
		have.append(str(c.get_meta("key", "")))
	rules_panel.visible = not want.is_empty()
	_place_rules()
	if have == want:
		return
	for c in rules_box.get_children():
		rules_box.remove_child(c)
		c.queue_free()
	for k in want.size():
		var r: TableRule = run.rules[k]
		var row := VBoxContainer.new()
		row.set_meta("key", want[k])
		row.add_theme_constant_override("separation", 0)
		var name_l := Label.new()
		name_l.text = r.display_name.to_upper()
		var col := Color("#FF5A4A") if r.kind == TableRule.Kind.CHEAT else (Palette.EMBER if r.kind == TableRule.Kind.DIE else Palette.BRASS_HI)
		name_l.label_settings = Palette.label_settings(24, col, 5, true)
		row.add_child(name_l)
		var line := Label.new()
		line.text = r.info_line(run)
		line.label_settings = Palette.label_settings(20, Palette.BONE, 4)
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.custom_minimum_size = Vector2(290, 0)
		row.add_child(line)
		# Boss sign art (Systems Dev, BossSign): icon + tooltip; no art = this text row.
		BossSign.decorate_hud_row(row, name_l, line, r.id, r.params)
		rules_box.add_child(row)
	rules_panel.reset_size()


func _place_rules() -> void:
	# Under the bounty cards; where they'd be when hidden (phone portrait).
	var below := checklist_panel.size.y + 14 if checklist_panel.visible else 0.0
	rules_panel.position.y = checklist_panel.position.y + below


## Names of the rules the HUD shows (tests).
func rule_rows() -> Array[String]:
	var out: Array[String] = []
	for c in rules_box.get_children():
		out.append(str(c.get_meta("key", "")))
	return out


func _refresh_checklist(run: BonfireRun) -> void:
	var bounties := run.all_bounties()
	if bounty_cards.size() != bounties.size() or (not bounties.is_empty() and not bounty_cards.has(bounties[0].id)):
		for id in bounty_cards:
			(bounty_cards[id] as Node).queue_free()
		bounty_cards.clear()
		bounty_rows.clear()
		_stamps.clear()
		_pending_stamps.clear()
		for b: BountyData in bounties:
			var card := BountyCard.new()
			card.setup(b, run.goal.bonus.has(b))
			checklist_panel.add_child(card)
			bounty_cards[b.id] = card
			# The mark text, hidden (tests / accessibility read it).
			var l := Label.new()
			l.visible = false
			card.add_child(l)
			bounty_rows[b.id] = l
		_layout_cards()
	# "CLAIM ALL 3 · 5 hands" (section 4).
	card_header.text = "Claim all %d bounties · %d hand%s left" % [run.goal.required.size(), run.hands_left, "" if run.hands_left == 1 else "s"]
	for b: BountyData in bounties:
		var l: Label = bounty_rows[b.id]
		var bonus := run.goal.bonus.has(b)
		var mark := "[x]" if run.is_ticked(b) else ("[?]" if run.is_pending(b) else "[ ]")
		l.text = "%s %s%s" % [mark, b.display_name, ("  +%d Embers" % b.bonus_embers) if bonus else ""]
		var card: BountyCard = bounty_cards[b.id]
		if run.is_ticked(b):
			if card.state != "claimed":
				# Claimed without a bank stamp (e.g. a restored table): no slam.
				card.set_state("claimed", false)
			_stamps[b.id] = card
			_pending_stamps.erase(b.id)
		elif run.is_pending(b):
			card.set_state("pending")
			_pending_stamps[b.id] = card
			_stamps.erase(b.id)
		elif not _crumbling.has(b.id) and not _pending_stamps.has(b.id):
			# (A pending ghost stays until the bust crumbles it.)
			card.set_state("open")
			_stamps.erase(b.id)


## The cards: 2 per row, right-aligned under the Ember counter. Each card is
## 136 x 72 pt (ui_pt_px design px per pt).
func _layout_cards() -> void:
	var pt := ui_pt_px * card_mult
	var k := pt / 4.0
	var w := BountyCard.CARD_SIZE.x * k
	var h := BountyCard.CARD_SIZE.y * k
	var gap := 6.0 * pt
	var row_gap := 9.0 * pt  # room for the CLAIMED wax hanging under a card
	var header_h := 20.0 * pt
	# Header: Barlow-ish display caps, ~10 pt cap height.
	card_header.label_settings.font_size = int(round(14.0 * pt))
	card_header.position = Vector2.ZERO
	card_header.size = Vector2(2.0 * w + gap, header_h)
	var i := 0
	for id in bounty_cards:
		var c: BountyCard = bounty_cards[id]
		c.scale = Vector2.ONE * k
		c.position = Vector2((i % 2) * (w + gap), header_h + (i / 2) * (h + row_gap))
		i += 1
	var rows := (bounty_cards.size() + 1) / 2
	checklist_panel.position = Vector2(CARDS_RIGHT - 2.0 * w - gap, CARDS_TOP)
	checklist_panel.size = Vector2(2.0 * w + gap, header_h + rows * (h + row_gap))
	_place_rules()


## The design px per pt for this screen (Bonfire3D: 2.0 on PC, more on a
## phone in landscape so the cards keep their real size).
##
## card_mult sizes the bounty cards against that: 1 on PC; a phone in
## landscape uses less (BonfireHud.PHONE_LANDSCAPE_CARDS) so the 2 x 2 grid
## stays off the landing zone.
func set_ui_scale(pt_px: float, cards: float = 1.0) -> void:
	if is_equal_approx(pt_px, ui_pt_px) and is_equal_approx(cards, card_mult):
		return
	ui_pt_px = pt_px
	card_mult = cards
	_layout_cards()
	tutorial.set_ui_scale(pt_px)


## Pulses the bounty cards in `ids` (the ones the selection could claim).
func pulse_cards(ids: Array) -> void:
	_pulse = ids.duplicate()
	portrait_goal.pulse(ids)
	for id in bounty_cards:
		if not _pulse.has(id):
			(bounty_cards[id] as Control).modulate = Color.WHITE


func pulsing() -> Array:
	return _pulse.duplicate()


func _process(delta: float) -> void:
	# The Leave question times out (or the button went away).
	if _leave_asked_at >= 0.0 and (not leave_button.visible or float(leave_clock.call()) - _leave_asked_at > LEAVE_CONFIRM_S):
		_reset_leave_ask()
	_t += delta / maxf(Engine.time_scale, 0.001)
	for id in _pulse:
		var c: Control = bounty_cards.get(id)
		if c != null:
			var k := 0.5 + 0.5 * sin(_t * 9.0)
			c.modulate = Color(1.0 + 0.5 * k, 1.0 + 0.25 * k, 1.0, 1.0)


## A bank claimed bounty `id`: its card's wax CLAIMED seal stamps in (the
## Art Director's 6-key stamp-in). Several in one bank go one card at a
## time, 0.12 s apart. In portrait the goal readout gets the stamp instead.
func stamp_claimed(id: StringName, reduced: bool = false) -> void:
	_pending_stamps.erase(id)
	_crumbling.erase(id)
	portrait_goal.stamp(id, reduced)
	if _stamps.has(id):
		return
	var card: BountyCard = bounty_cards.get(id)
	if card == null:
		return
	_stamps[id] = card
	var now := Time.get_ticks_msec() / 1000.0
	var delay := 0.0
	if now - _last_stamp_at < STAMP_STAGGER:
		_stamp_queue += 1
		delay = STAMP_STAGGER * _stamp_queue
	else:
		_stamp_queue = 0
	_last_stamp_at = now
	if reduced:
		card.set_state("claimed", false)
	else:
		card.state = "claimed"
		card.ghost.visible = false
		card.pending_label.visible = false
		card.seal.visible = true
		card._stamp_in(delay)


func has_stamp(id: StringName) -> bool:
	return _stamps.has(id)


func has_pending_stamp(id: StringName) -> bool:
	return _pending_stamps.has(id)


## Bust: the PENDING ghosts crumble (0.25 s: scale 1 -> 1.1, fade, and a
## little bone dust), and the cards go back to open.
## Bounty ids showing a PENDING stamp right now.
func pending_cards() -> Array:
	return _pending_stamps.keys()


func crumble_pending(reduced: bool = false) -> int:
	portrait_goal.lost(_pending_stamps.keys())
	var n := 0
	for id in _pending_stamps.keys():
		var card: BountyCard = _pending_stamps[id]
		_pending_stamps.erase(id)
		n += 1
		if not is_instance_valid(card):
			continue
		if reduced:
			card.set_state("open")
			continue
		_crumbling[id] = true
		card.pending_label.visible = false
		var g := card.ghost
		var at := g.global_position + g.size * g.get_global_transform().get_scale() * 0.5
		var tw := g.create_tween().set_ignore_time_scale(true).set_parallel(true)
		tw.tween_property(g, "scale", Vector2.ONE * 1.1, 0.25)
		tw.tween_property(g, "modulate:a", 0.0, 0.25)
		tw.chain().tween_callback(func() -> void:
			_crumbling.erase(id)
			g.scale = Vector2.ONE
			g.modulate.a = 1.0
			if card.state == "pending":
				card.set_state("open"))
		for k in 6:
			var dust := ColorRect.new()
			dust.color = Palette.BONE
			dust.size = Vector2(8, 8)
			dust.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(dust)
			dust.global_position = at + Vector2((k - 2.5) * 14.0, 0)
			var dt := dust.create_tween().set_ignore_time_scale(true).set_parallel(true)
			dt.tween_property(dust, "position", dust.position + Vector2(randf_range(-24, 24), 50 + k * 8), 0.45)
			dt.tween_property(dust, "modulate:a", 0.0, 0.45)
			dt.chain().tween_callback(dust.queue_free)
	return n
