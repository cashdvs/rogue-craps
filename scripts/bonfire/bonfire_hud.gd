## Bonfire HUD (plain Controls, 1920x1080 design space): Embers / points,
## hands left, the bounty cards, the hand's pot with the live pot preview
## "TRIPS: (30+12) x3 = 126", the rethrow risk "Throw 2 cold dice: 1 in 3
## burns", BANK / THROW and the end screen (how_bonfire_plays.md section 4).
## The combo table is printed on the felt (FeltComboTable), not here.
class_name BonfireHud
extends Control

signal bank_pressed
signal throw_pressed
signal restart_pressed
## Run mode: the end panel's CONTINUE (hand the outcome back to the run).
signal continue_pressed
## A cleared table: the player taps Leave table (between hands only).
signal leave_pressed

var coin_label: Label
var points_label: Label
## The bounty cards' home: a 2 x 2 grid of BountyCards in the top-right
## corner (PC and phone landscape). Hidden in phone portrait, where the goal
## readout at the top shows the same thing.
var checklist_panel: Control
## "CLAIM ALL 3 · 5 hands" over the cards.
var card_header: Label
## Bounty id -> a hidden Label with the bounty's mark ("[x] Triple"): the
## same text the old checklist showed, kept for tests and screen readers.
var bounty_rows: Dictionary = {}
var hands_label: Label
var pot_label: Label
var throw_label: Label
## Under the pot preview: what changed the numbers ("Hot Hand +1 mult ·
## Hellfire x1.5").
var notes_label: Label
## The rethrow prompt with the bust risk ("Throw 2 cold dice: 1 in 3 burns").
var risk_label: Label
## Set by Bonfire3D before each refresh (it knows which dice will be thrown).
var rethrow_prompt: String = ""
## Design px per pt: 2.0 on PC (the Art Director's UI scale), bigger on a
## phone so the cards keep their 136 x 72 pt size (Bonfire3D sets it).
var ui_pt_px: float = 2.0
var mult_label: Label
var result_label: Label
var bank_button: Button
## "LEAVE TABLE": shown between hands once the table is cleared (Bonfire3D
## decides when; see Bonfire3D.can_leave_now).
var leave_button: Button
## The "TABLE CLEARED" banner shown at the clearing bank (ClearedBanner).
var cleared_banner: ClearedBanner
var throw_button: Button
## Why the THROW / BANK button is greyed out (QA full run pass 1): a small
## caption just above THROW (a child of the button, outside the column's
## layout) plus the buttons' tooltips. Empty while the buttons work.
var action_reason: Label
var end_panel: PanelContainer
var end_title: Label
var end_body: Label
var restart_button: Button
var continue_button: Button
## Active table rules (twists / boss cheats / special dice): name + one line.
var rules_panel: PanelContainer
var rules_box: VBoxContainer
## Juice / onboarding (bonfire_map_events_juice.md sections 3-4).
var countup: BonfireCountUp
var tutorial: BonfireTutorial
## Bounty id -> its BountyCard.
var bounty_cards: Dictionary = {}
## Phone portrait only: the goal + bounty readout near the top (see
## portrait_goal_hud.gd). Hidden on PC and phone landscape.
var portrait_goal: PortraitGoalHud
var _stamps: Dictionary = {}
var _pending_stamps: Dictionary = {}
var _pulse: Array = []
var _t: float = 0.0
## Top-left of the THROW / BANK column (1920x1080 design px). Kept clear of
## the hand (bottom-right) at 16:9, phone landscape and phone portrait.
const BUTTONS_POS := Vector2(184, 790)


func _init() -> void:
	name = "BonfireHud"
	size = Vector2(1920, 1080)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	coin_label = _label(40, Palette.EMBER, Vector2(1560, 24), Vector2(340, 50))
	points_label = _label(26, Palette.BONE, Vector2(1560, 72), Vector2(340, 34))
	hands_label = _label(30, Palette.BONE, Vector2(1560, 108), Vector2(340, 40))
	checklist_panel = Control.new()
	checklist_panel.name = "BountyCards"
	checklist_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(checklist_panel)
	card_header = Label.new()
	card_header.name = "CardHeader"
	card_header.label_settings = Palette.label_settings(30, Palette.BRASS_HI, 6, true)
	card_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	card_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	checklist_panel.add_child(card_header)
	pot_label = _label(64, Palette.BRASS_HI, Vector2(560, 860), Vector2(800, 80))
	# x 520-1400: clear of the bottom-left THROW / BANK column (ends at x 494).
	throw_label = _label(36, Palette.EMBER, Vector2(520, 936), Vector2(880, 46))
	notes_label = _label(24, Palette.BONE, Vector2(520, 982), Vector2(880, 32))
	notes_label.name = "PotNotes"
	risk_label = _label(30, Palette.BRASS_HI, Vector2(520, 1014), Vector2(880, 40))
	risk_label.name = "RethrowRisk"
	mult_label = _label(34, Color("#FF2E3E"), Vector2(1260, 880), Vector2(260, 60))
	result_label = _label(64, Palette.BRASS_HI, Vector2(460, 380), Vector2(1000, 90))
	result_label.modulate.a = 0.0
	# The refused-die callout ("doesn't score"), placed over the die.
	callout_label = _label(40, Palette.BONE, Vector2.ZERO, Vector2(420, 56))
	callout_label.name = "Callout"
	callout_label.modulate.a = 0.0
	var col := VBoxContainer.new()
	# Bottom-left, beside the Soul meter: the hand of dice sits bottom-right,
	# and buttons over it ate the grab (QA full run pass 1, M1).
	col.position = BUTTONS_POS
	col.add_theme_constant_override("separation", 14)
	add_child(col)
	throw_button = _button("THROW  (Space)", 32, Palette.BURGUNDY)
	throw_button.custom_minimum_size = Vector2(310, 84)
	throw_button.pressed.connect(func() -> void: throw_pressed.emit())
	col.add_child(throw_button)
	action_reason = Label.new()
	action_reason.name = "ActionReason"
	action_reason.label_settings = Palette.label_settings(20, Palette.BONE, 4, true)
	action_reason.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	action_reason.position = Vector2(0, -32)
	action_reason.size = Vector2(310, 28)
	action_reason.mouse_filter = Control.MOUSE_FILTER_IGNORE
	throw_button.add_child(action_reason)
	bank_button = _button("BANK  (B)", 36, Color("#3C6A34"))
	bank_button.custom_minimum_size = Vector2(310, 84)
	bank_button.pressed.connect(func() -> void: bank_pressed.emit())
	col.add_child(bank_button)
	leave_button = _button("LEAVE TABLE  (L)", 32, Palette.FELT_DARK)
	leave_button.name = "LeaveButton"
	leave_button.custom_minimum_size = Vector2(310, 84)
	leave_button.visible = false
	leave_button.pressed.connect(func() -> void: leave_pressed.emit())
	col.add_child(leave_button)
	rules_panel = PanelContainer.new()
	rules_panel.name = "RulesPanel"
	rules_panel.add_theme_stylebox_override("panel", Palette.ink_box(Color(Palette.PIT_BLACK, 0.8)))
	# Right column, under the bounty checklist (placed in _refresh_rules).
	rules_panel.position = Vector2(1580, 380)
	rules_panel.custom_minimum_size = Vector2(310, 0)
	rules_panel.size = Vector2(310, 0)
	rules_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rules_panel.visible = false
	add_child(rules_panel)
	checklist_panel.resized.connect(_place_rules)
	rules_box = VBoxContainer.new()
	rules_box.add_theme_constant_override("separation", 6)
	rules_panel.add_child(rules_box)
	# Added before the end panel so the end screen draws over it.
	portrait_goal = PortraitGoalHud.new()
	add_child(portrait_goal)
	end_panel = PanelContainer.new()
	end_panel.add_theme_stylebox_override("panel", Palette.ink_box(Color(Palette.PIT_BLACK, 0.94)))
	end_panel.position = Vector2(560, 300)
	end_panel.custom_minimum_size = Vector2(800, 360)
	end_panel.visible = false
	add_child(end_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	end_panel.add_child(box)
	end_title = Label.new()
	end_title.label_settings = Palette.label_settings(64, Palette.BRASS_HI, 8, true)
	end_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(end_title)
	end_body = Label.new()
	end_body.label_settings = Palette.label_settings(28, Palette.BONE, 5)
	end_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(end_body)
	restart_button = _button("RESTART", 34, Palette.BURGUNDY)
	restart_button.custom_minimum_size = Vector2(360, 80)
	restart_button.pressed.connect(func() -> void: restart_pressed.emit())
	box.add_child(restart_button)
	continue_button = _button("CONTINUE", 34, Palette.FELT_DARK)
	continue_button.custom_minimum_size = Vector2(360, 80)
	continue_button.visible = false
	continue_button.pressed.connect(func() -> void: continue_pressed.emit())
	box.add_child(continue_button)
	countup = BonfireCountUp.new()
	add_child(countup)
	move_child(countup, end_panel.get_index())
	# Over the table, under the end panel and the tutorial.
	cleared_banner = ClearedBanner.new()
	add_child(cleared_banner)
	move_child(cleared_banner, end_panel.get_index())
	tutorial = BonfireTutorial.new()
	add_child(tutorial)


## While a pot counts up, the HUD numbers show the values from before the
## commit (Bonfire3D sets this; the run state underneath is already final):
## {embers, points, pot_from, pot_add}. The pot counts up with the count-up.
var display_hold: Dictionary = {}


func refresh(run: BonfireRun, can_act: bool) -> void:
	coin_label.text = "EMBERS %d" % int(display_hold.get("embers", run.embers))
	# Points are income (section 4): "points 572 → +5 Embers".
	var pts := int(display_hold.get("points", run.points))
	points_label.text = "points %d → +%d Embers" % [pts, pts / maxi(run.tuning.points_per_ember, 1)]
	hands_label.text = "HANDS LEFT %d" % run.hands_left
	_refresh_checklist(run)
	portrait_goal.refresh(run)
	_place_result()
	_refresh_rules(run)
	var picking := run.state == BonfireRun.State.PICK
	if display_hold.has("pot_from"):
		hold_count(float(display_hold.get("f", 0.0)))
	elif picking and run.throw_points() > 0:
		# The selection is a preview until the count-up banks it into the pot.
		pot_label.text = "POT %d  (+%d)" % [run.pot, run.throw_points()]
	else:
		pot_label.text = "POT %d" % run.hand_pot()
	notes_label.text = ""
	risk_label.text = ""
	if picking:
		var sel := run.selection()
		if sel["valid"]:
			# The live pot preview, e.g. "TRIPS: (30+12) x3 = 126", and what
			# changed it (Hot Hand, Hellfire...), then the rethrow risk.
			throw_label.text = BonfireScoring.preview(sel)
			notes_label.text = "  ·  ".join(BonfireScoring.factor_notes(run.selection_faces(), sel, run.tuning, run.mult_bonus(), run.rule_ctx()))
			risk_label.text = rethrow_prompt
		elif run.potted.is_empty():
			throw_label.text = "Click burning dice: pot ONE combo"
		else:
			throw_label.text = "not a combo yet..."
	elif run.forfeited or run.is_over():
		throw_label.text = ""
	elif rethrow_prompt != "":
		# Cold dice waiting to be thrown again: say how risky it is.
		throw_label.text = rethrow_prompt
	else:
		throw_label.text = "Grab the %d dice and flick" % run.cold
	mult_label.text = ("+%d MULT" % run.mult_bonus()) if run.mult_bonus() > 0 else ""
	bank_button.disabled = not (can_act and run.can_continue())
	if picking:
		throw_button.disabled = not (can_act and run.rethrow_block_reason() == "")
		throw_button.text = "HOT HAND! ALL %d" % run.dice_count if run.is_hot() else "THROW %d AGAIN" % (run.throw_faces.size() - run.potted.size())
	else:
		throw_button.disabled = not can_act
		throw_button.text = "THROW %d  (Space)" % run.cold
	var why := action_reasons(run, can_act)
	throw_button.tooltip_text = why["throw"]
	bank_button.tooltip_text = why["bank"]
	# The caption names the first greyed-out button's reason while picking.
	action_reason.text = why["throw"] if why["throw"] != "" else (why["bank"] if picking else "")


## Why THROW / BANK can't be pressed right now ({throw, bank}; "" = it can,
## or the table is busy rolling / counting).
static func action_reasons(run: BonfireRun, can_act: bool) -> Dictionary:
	var out := {"throw": "", "bank": ""}
	if not can_act or run.is_over() or run.forfeited:
		return out
	if run.state == BonfireRun.State.PICK:
		var combo_why := ""
		if not run.can_continue():
			combo_why = "Pot a lit die first" if run.potted.is_empty() else "Not a combo yet: pot ONE combo"
		out["bank"] = combo_why
		if combo_why != "":
			out["throw"] = combo_why
		elif run.is_hot() and not run.hot_hand_allowed():
			out["throw"] = "No Hot Hand at this table: bank it"
	else:
		out["bank"] = "Throw, then pot a combo to bank"
	return out


## The held pot counts up with the count-up (f = 0..1).
func hold_count(f: float) -> void:
	if not display_hold.has("pot_from"):
		return
	display_hold["f"] = f
	pot_label.text = "POT %d" % (int(display_hold["pot_from"]) + int(round(int(display_hold.get("pot_add", 0)) * clampf(f, 0.0, 1.0))))


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
	card_header.text = "CLAIM ALL %d · %d hand%s" % [run.goal.required.size(), run.hands_left, "" if run.hands_left == 1 else "s"]
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


## The cards' top-right corner (design px): under the Ember / points / hands
## lines, at the screen's right edge.
const CARDS_RIGHT := 1906.0
const CARDS_TOP := 150.0


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


## Phone landscape: the cards at 0.72 of their PC pt size (9.4 pt title caps),
## so the grid takes ~24% of the width instead of a third.
const PHONE_LANDSCAPE_CARDS := 0.72
var card_mult: float = 1.0


# --- Juice / onboarding -------------------------------------------------------------

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


const STAMP_STAGGER := 0.12
var _last_stamp_at: float = -10.0
var _stamp_queue: int = 0
## Pending cards whose ghost is crumbling (bust), so refresh leaves them be.
var _crumbling: Dictionary = {}


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


## A die that can't join the combo: a short "doesn't score" callout over it
## (at `at`, canvas px), which rises a little and fades.
var callout_label: Label


## Pops a short callout ("doesn't score") just above screen point `at`,
## then fades it out.
func callout(at: Vector2, text: String = "doesn't score") -> void:
	callout_label.text = text
	callout_label.position = at - Vector2(callout_label.size.x * 0.5, callout_label.size.y + 30.0)
	callout_label.modulate.a = 1.0
	var tw := callout_label.create_tween().set_ignore_time_scale(true)
	tw.tween_property(callout_label, "position:y", callout_label.position.y - 24.0, 0.7)
	tw.parallel().tween_property(callout_label, "modulate:a", 0.0, 0.3).set_delay(0.5)


## Bank: embers fly from the pot into the Ember counter (the pile).
func ember_flow(count: int, seconds: float, reduced: bool = false) -> void:
	var from := pot_label.global_position + pot_label.size * 0.5
	var to := coin_label.global_position + Vector2(coin_label.size.x * 0.5, coin_label.size.y * 0.5)
	var n := clampi(count, 1, 6 if reduced else 24)
	for i in n:
		var e := ColorRect.new()
		e.color = Palette.EMBER if i % 3 else Palette.BRASS_HI
		e.size = Vector2(10, 10)
		e.rotation = PI / 4
		e.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(e)
		e.global_position = from + Vector2(randf_range(-40, 40), randf_range(-10, 10))
		var mid := (e.global_position + to) * 0.5 + Vector2(0, -160)
		var start := e.global_position
		var delay := seconds * 0.5 * float(i) / float(n)
		var tw := e.create_tween().set_ignore_time_scale(true)
		tw.tween_interval(delay)
		tw.tween_method(func(f: float) -> void:
			var a := start.lerp(mid, f)
			var b := mid.lerp(to, f)
			e.global_position = a.lerp(b, f), 0.0, 1.0, seconds * 0.5)
		tw.tween_callback(func() -> void:
			coin_label.pivot_offset = coin_label.size * 0.5
			coin_label.scale = Vector2.ONE * 1.08
			var t2 := coin_label.create_tween().set_ignore_time_scale(true)
			t2.tween_property(coin_label, "scale", Vector2.ONE, 0.08)
			e.queue_free())


## Bust: the Soul flask (the Soul meter) cracks and drips.
func flask_crack(rect: Rect2, reduced: bool = false) -> void:
	var o := FlaskCrack.new()
	o.rect = rect
	o.reduced = reduced
	add_child(o)


## Small flash on the bounties just banked.
func flash_ticks(ids: Array) -> void:
	for id in ids:
		var l: Label = bounty_rows.get(id)
		if l == null:
			continue
		l.pivot_offset = Vector2(0, 14)
		var tw := l.create_tween()
		l.modulate = Color(2.0, 2.0, 1.2)
		tw.tween_property(l, "scale", Vector2.ONE * 1.25, 0.1)
		tw.tween_property(l, "scale", Vector2.ONE, 0.2)
		tw.parallel().tween_property(l, "modulate", Color.WHITE, 0.5)


## The clearing bank (how_bonfire_plays.md §4): "TABLE CLEARED: chase the
## bonus or Leave table" (ClearedBanner: 1.8 s at 1x, never blocks input).
const CLEARED_TEXT := ClearedBanner.TEXT


## speed: 2.0 at the 2x roll speed; instant: the Instant speed / reduced motion.
func show_cleared(speed: float = 1.0, instant: bool = false) -> void:
	cleared_banner.pt_px = ui_pt_px
	cleared_banner.rest_center = _banner_center()
	cleared_banner.play(speed, instant)


## Where the banner rests: over the upper felt, clear of the BANKED flash.
func _banner_center() -> Vector2:
	if portrait_goal.visible:
		var vs := get_viewport_rect().size
		return Vector2(960, maxf(vs.y * 0.40, result_label.position.y + 600.0))
	return Vector2(960, 620)


func flash(text: String, col: Color) -> void:
	result_label.text = text
	result_label.label_settings.font_color = col
	result_label.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(1.0)
	tw.tween_property(result_label, "modulate:a", 0.0, 0.4)


## Phone portrait (the screen is taller than wide): the goal readout at the
## top replaces the bounty cards, so there is one list; the bank / bust
## banner moves down under the readout so both stay readable. PC and phone
## landscape keep the cards and the banner where they were.
func set_portrait(on: bool) -> void:
	if on == portrait_goal.visible:
		return
	portrait_goal.visible = on
	checklist_panel.visible = not on
	_place_rules()
	_place_result()


## The bank / bust banner: under the readout in portrait (its height can
## change when the goal's rows are built), else at RESULT_Y.
func _place_result() -> void:
	if portrait_goal.visible:
		result_label.position.y = portrait_goal.position.y + portrait_goal.get_combined_minimum_size().y + RESULT_GAP
	else:
		result_label.position.y = RESULT_Y


## Where the bank / bust banner sits (design px): its usual height, and in
## portrait this far under the goal readout.
const RESULT_Y := 380.0
const RESULT_GAP := 40.0


## Run mode: CONTINUE instead of RESTART on the end panel.
func set_run_mode(on: bool) -> void:
	restart_button.visible = not on
	continue_button.visible = on


func show_end(run: BonfireRun) -> void:
	var sm := run.table_summary
	var ember_line := "Points %d -> %d Embers%s.  Embers %d." % [run.points, int(sm.get("points_embers", 0)),
		(", clear +%d" % int(sm["clear_embers"])) if int(sm.get("clear_embers", 0)) > 0 else "", run.embers]
	match run.state:
		BonfireRun.State.CLEARED:
			end_title.text = "TABLE CLEARED"
			var bonus: Array[String] = []
			for b: BountyData in run.goal.bonus:
				if run.is_ticked(b):
					bonus.append("%s +%d" % [b.display_name, b.bonus_embers])
			end_body.text = "Every required bounty banked%s.\n%s\nSoul %d." % [
				(" (bonus: %s)" % ", ".join(bonus)) if not bonus.is_empty() else "", ember_line, run.soul]
		_ when run.forfeited and run.state != BonfireRun.State.RUN_OVER:
			end_title.text = "TABLE FORFEITED"
			end_body.text = "You walked away with %d bounties unticked: -%d Soul (Soul %d).\n%s" % [run.unticked_required(), int(sm.get("timeout_soul", 0)), run.soul, ember_line]
		BonfireRun.State.RUN_OVER:
			end_title.text = "SOUL BURNED OUT"
			end_body.text = "The bonfire took everything.\n%s" % ember_line
		_:
			end_title.text = "TABLE LOST"
			end_body.text = "Out of hands with %d bounties unticked: -%d Soul (Soul %d).\n%s" % [run.unticked_required(), int(sm.get("timeout_soul", 0)), run.soul, ember_line]
	end_panel.visible = true
	# A table can end mid-tutorial: the hint panel must not cover the end
	# panel (#103 N6). stop() also drops the waiting hints, so dismiss()
	# can't pop the next one over the end panel.
	tutorial.stop()


func _label(px: int, col: Color, pos: Vector2, sz: Vector2) -> Label:
	var l := Label.new()
	l.label_settings = Palette.label_settings(px, col, 6, true)
	l.position = pos
	l.size = sz
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


func _button(text: String, px: int, fill: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", px)
	b.add_theme_stylebox_override("normal", Palette.ink_box(fill))
	b.add_theme_stylebox_override("hover", Palette.ink_box(fill.lightened(0.12)))
	b.add_theme_stylebox_override("pressed", Palette.ink_box(fill.darkened(0.2)))
	b.add_theme_stylebox_override("disabled", Palette.ink_box(Color(fill, 0.4)))
	b.focus_mode = Control.FOCUS_NONE
	return b


## Crack lines and Soul drips over the Soul meter for ~1.2 s.
class FlaskCrack:
	extends Control
	var rect: Rect2
	var reduced: bool = false
	var _age: float = 0.0
	var _lines: Array = []

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		position = Vector2.ZERO
		size = Vector2(1920, 1080)
		var rng := RandomNumberGenerator.new()
		rng.seed = 77
		var c := rect.get_center() + Vector2(0, -rect.size.y * 0.2)
		for k in 5:
			var pts := PackedVector2Array([c])
			var p := c
			var dir := Vector2.from_angle(rng.randf_range(0, TAU))
			for j in 4:
				p += dir * rect.size.x * rng.randf_range(0.18, 0.32)
				dir = dir.rotated(rng.randf_range(-0.7, 0.7))
				p = p.clamp(rect.position, rect.end)
				pts.append(p)
			_lines.append(pts)

	func _process(delta: float) -> void:
		_age += delta / maxf(Engine.time_scale, 0.001)
		queue_redraw()
		if _age > 1.3:
			queue_free()

	func _draw() -> void:
		var a := clampf(1.3 - _age, 0.0, 1.0)
		var grow := clampf(_age / 0.2, 0.0, 1.0)
		for pts: PackedVector2Array in _lines:
			var n := maxi(2, int(pts.size() * grow))
			draw_polyline(pts.slice(0, n), Color(Palette.SOUL_CORE, a), 3.0)
		if not reduced:
			for k in 3:
				var x := rect.position.x + rect.size.x * (0.3 + 0.2 * k)
				var y := rect.end.y + _age * (140.0 + 40.0 * k)
				draw_circle(Vector2(x, y), 5.0, Color(Palette.SOUL_FLAME, a))
