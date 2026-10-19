## Bonfire HUD (plain Controls, 1920x1080 design space): Embers / points,
## hands left, the bounty checklist, the hand's pot with the live combo
## formula "(base + faces) x mult = N", BANK / THROW and the end screen.
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
var checklist: VBoxContainer
var checklist_panel: PanelContainer
var bounty_rows: Dictionary = {}
var hands_label: Label
var pot_label: Label
var throw_label: Label
var mult_label: Label
var result_label: Label
var bank_button: Button
## "LEAVE TABLE": shown between hands once the table is cleared (Bonfire3D
## decides when; see Bonfire3D.can_leave_now).
var leave_button: Button
## The "TABLE CLEARED" banner shown at the clearing bank.
var cleared_banner: Label
var throw_button: Button
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
var combo_panel: PanelContainer
var combo_toggle: Button
var combo_grid: GridContainer
## Seal level column (hidden until Seals exist).
var show_seal_column: bool = false
## Bounty id -> its card (PanelContainer with icons + the row label).
var bounty_cards: Dictionary = {}
var _stamps: Dictionary = {}
var _pending_stamps: Dictionary = {}
var _pulse: Array = []
var _t: float = 0.0


func _init() -> void:
	name = "BonfireHud"
	size = Vector2(1920, 1080)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	coin_label = _label(40, Palette.EMBER, Vector2(1560, 24), Vector2(340, 50))
	points_label = _label(26, Palette.BONE, Vector2(1560, 72), Vector2(340, 34))
	hands_label = _label(30, Palette.BONE, Vector2(1560, 108), Vector2(340, 40))
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Palette.ink_box(Color(Palette.PIT_BLACK, 0.8)))
	panel.position = Vector2(1580, 160)
	panel.custom_minimum_size = Vector2(310, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	checklist_panel = panel
	checklist = VBoxContainer.new()
	checklist.add_theme_constant_override("separation", 4)
	panel.add_child(checklist)
	pot_label = _label(64, Palette.BRASS_HI, Vector2(560, 870), Vector2(800, 80))
	throw_label = _label(34, Palette.EMBER, Vector2(360, 950), Vector2(1200, 46))
	mult_label = _label(34, Color("#FF2E3E"), Vector2(1260, 880), Vector2(260, 60))
	result_label = _label(64, Palette.BRASS_HI, Vector2(460, 380), Vector2(1000, 90))
	result_label.modulate.a = 0.0
	# Two lines, centred, just under the bank / bust banner (see show_cleared).
	cleared_banner = _label(58, Palette.BRASS_HI, Vector2(360, 480), Vector2(1200, 150))
	cleared_banner.name = "ClearedBanner"
	cleared_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cleared_banner.modulate.a = 0.0
	var col := VBoxContainer.new()
	col.position = Vector2(1580, 760)
	col.add_theme_constant_override("separation", 14)
	add_child(col)
	throw_button = _button("THROW  (Space)", 32, Palette.BURGUNDY)
	throw_button.custom_minimum_size = Vector2(310, 84)
	throw_button.pressed.connect(func() -> void: throw_pressed.emit())
	col.add_child(throw_button)
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
	_build_combo_panel()
	tutorial = BonfireTutorial.new()
	add_child(tutorial)


## While a pot counts up, the HUD numbers show the values from before the
## commit (Bonfire3D sets this; the run state underneath is already final):
## {embers, points, pot_from, pot_add}. The pot counts up with the count-up.
var display_hold: Dictionary = {}


func refresh(run: BonfireRun, can_act: bool) -> void:
	coin_label.text = "EMBERS %d" % int(display_hold.get("embers", run.embers))
	points_label.text = "points %d  (1 Ember / %d)" % [int(display_hold.get("points", run.points)), run.tuning.points_per_ember]
	hands_label.text = "HANDS LEFT %d" % run.hands_left
	_refresh_checklist(run)
	_refresh_rules(run)
	var picking := run.state == BonfireRun.State.PICK
	if display_hold.has("pot_from"):
		hold_count(float(display_hold.get("f", 0.0)))
	elif picking and run.throw_points() > 0:
		# The selection is a preview until the count-up banks it into the pot.
		pot_label.text = "POT %d  (+%d)" % [run.pot, run.throw_points()]
	else:
		pot_label.text = "POT %d" % run.hand_pot()
	if picking:
		var sel := run.selection()
		if sel["valid"]:
			throw_label.text = BonfireScoring.formula(sel)
		elif run.potted.is_empty():
			throw_label.text = "Click burning dice: pot ONE combo"
		else:
			throw_label.text = "not a combo yet..."
	elif run.forfeited:
		throw_label.text = ""
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
		rules_box.add_child(row)
	rules_panel.reset_size()


func _place_rules() -> void:
	rules_panel.position.y = checklist_panel.position.y + checklist_panel.size.y + 14


## Names of the rules the HUD shows (tests).
func rule_rows() -> Array[String]:
	var out: Array[String] = []
	for c in rules_box.get_children():
		out.append(str(c.get_meta("key", "")))
	return out


func _refresh_checklist(run: BonfireRun) -> void:
	if bounty_rows.is_empty() or not bounty_rows.has(run.goal.required[0].id) or bounty_rows.size() != run.all_bounties().size():
		for c in checklist.get_children():
			c.queue_free()
		bounty_rows.clear()
		var title := Label.new()
		title.text = "%s BOUNTIES" % run.goal.display_name.to_upper()
		title.label_settings = Palette.label_settings(24, Palette.BRASS_HI, 5, true)
		checklist.add_child(title)
		bounty_cards.clear()
		_stamps.clear()
		_pending_stamps.clear()
		for b: BountyData in run.all_bounties():
			# A bounty card: mini dice icons of the pattern + the row text.
			var card := PanelContainer.new()
			card.add_theme_stylebox_override("panel", Palette.ink_box(Color(Palette.FELT_DARK, 0.9), 8, 2, Palette.BRASS))
			card.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var hb := HBoxContainer.new()
			hb.add_theme_constant_override("separation", 8)
			card.add_child(hb)
			var icons := DiceIcons.new()
			icons.set_values(DiceIcons.pattern(b))
			hb.add_child(icons)
			var l := Label.new()
			l.label_settings = Palette.label_settings(22, Palette.BONE, 4)
			l.tooltip_text = b.description
			hb.add_child(l)
			checklist.add_child(card)
			bounty_rows[b.id] = l
			bounty_cards[b.id] = card
	for b: BountyData in run.all_bounties():
		var l: Label = bounty_rows[b.id]
		var bonus := run.goal.bonus.has(b)
		var mark := "[x]" if run.is_ticked(b) else ("[?]" if run.is_pending(b) else "[ ]")
		l.text = "%s %s%s" % [mark, b.display_name, ("  +%d Embers" % b.bonus_embers) if bonus else ""]
		l.label_settings.font_color = Color("#9FE08A") if run.is_ticked(b) else (Palette.EMBER if run.is_pending(b) else (Palette.BONE if not bonus else Color(Palette.BONE, 0.7)))
		if not run.is_ticked(b) and _stamps.has(b.id):
			(_stamps[b.id] as Control).queue_free()
			_stamps.erase(b.id)
		if run.is_pending(b) and not _pending_stamps.has(b.id):
			_pending_stamps[b.id] = _stamp_label(b.id, "PENDING", Color(Palette.EMBER, 0.0), Palette.EMBER, 0.75)
		elif not run.is_pending(b) and _pending_stamps.has(b.id) and run.is_ticked(b):
			(_pending_stamps[b.id] as Control).queue_free()
			_pending_stamps.erase(b.id)


# --- Juice / onboarding -------------------------------------------------------------

## The always-visible, collapsible combo reference: combo, base x mult (and a
## Seal level column, hidden until Seals exist).
func _build_combo_panel() -> void:
	combo_panel = PanelContainer.new()
	combo_panel.name = "ComboPanel"
	combo_panel.add_theme_stylebox_override("panel", Palette.ink_box(Color(Palette.PIT_BLACK, 0.8)))
	combo_panel.position = Vector2(184, 118)
	combo_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(combo_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	combo_panel.add_child(box)
	combo_toggle = Button.new()
	combo_toggle.text = "COMBOS  -"
	combo_toggle.flat = true
	combo_toggle.add_theme_font_override("font", Palette.display_font())
	combo_toggle.add_theme_font_size_override("font_size", 22)
	combo_toggle.add_theme_color_override("font_color", Palette.BRASS_HI)
	combo_toggle.focus_mode = Control.FOCUS_NONE
	combo_toggle.pressed.connect(func() -> void: set_combo_panel_open(not combo_grid.visible))
	box.add_child(combo_toggle)
	combo_grid = GridContainer.new()
	combo_grid.add_theme_constant_override("h_separation", 14)
	box.add_child(combo_grid)


func set_combo_panel_open(open: bool) -> void:
	combo_grid.visible = open
	combo_toggle.text = "COMBOS  -" if open else "COMBOS  +"
	combo_panel.reset_size()


## Fills the combo panel from the tuning (Seal levels: combo id -> level).
func set_combos(t: BonfireTuning, seal_levels: Dictionary = {}) -> void:
	for c in combo_grid.get_children():
		combo_grid.remove_child(c)
		c.queue_free()
	combo_grid.columns = 3 if show_seal_column else 2
	for i in range(t.combos.size() - 1, -1, -1):
		var c: BonfireCombo = t.combos[i]
		var n := Label.new()
		n.text = c.display_name
		n.label_settings = Palette.label_settings(19, Palette.BONE, 4)
		combo_grid.add_child(n)
		var v := Label.new()
		v.text = "%d x %d" % [c.base, c.mult]
		v.label_settings = Palette.label_settings(19, Palette.BRASS_HI, 4)
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		combo_grid.add_child(v)
		if show_seal_column:
			var sl := Label.new()
			sl.text = "Lv %d" % int(seal_levels.get(c.id, 1))
			sl.label_settings = Palette.label_settings(19, Palette.EMBER, 4)
			combo_grid.add_child(sl)
	combo_panel.reset_size()


## Pulses the bounty cards in `ids` (the ones the selection could claim).
func pulse_cards(ids: Array) -> void:
	_pulse = ids.duplicate()
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


func _stamp_label(id: StringName, text: String, fill: Color, ink: Color, alpha: float) -> Label:
	var card: Control = bounty_cards.get(id)
	var l := Label.new()
	l.text = text
	l.label_settings = Palette.label_settings(15, ink, 3, true)
	var sb := Palette.ink_box(fill, 8, 3, ink)
	l.add_theme_stylebox_override("normal", sb)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.modulate.a = alpha
	l.rotation = -0.12
	if card != null:
		# A free layer over the card (the PanelContainer would stretch the
		# stamp over the text); the stamp sits on the card's right end.
		var layer := card.get_node_or_null("StampLayer") as Control
		if layer == null:
			layer = Control.new()
			layer.name = "StampLayer"
			layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card.add_child(layer)
		layer.add_child(l)
		l.anchor_left = 1.0
		l.anchor_right = 1.0
		l.offset_left = -86.0
		l.offset_right = -4.0
		l.offset_top = -3.0
		l.offset_bottom = 22.0
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	else:
		l.position = Vector2(170, 2)
	return l


## The wax "CLAIMED" stamp slams onto a bounty card.
func stamp_claimed(id: StringName, reduced: bool = false) -> void:
	if _pending_stamps.has(id):
		(_pending_stamps[id] as Control).queue_free()
		_pending_stamps.erase(id)
	if _stamps.has(id):
		return
	var l := _stamp_label(id, "CLAIMED", Color("#8E0F1C"), Palette.BRASS_HI, 1.0)
	_stamps[id] = l
	if not reduced:
		l.pivot_offset = Vector2(41, 12)
		l.scale = Vector2.ONE * 2.2
		var tw := l.create_tween().set_ignore_time_scale(true)
		tw.tween_property(l, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func has_stamp(id: StringName) -> bool:
	return _stamps.has(id)


func has_pending_stamp(id: StringName) -> bool:
	return _pending_stamps.has(id)


## Bust: the pending stamps crumble into falling shards.
func crumble_pending(reduced: bool = false) -> int:
	var n := 0
	for id in _pending_stamps.keys():
		var st: Control = _pending_stamps[id]
		_pending_stamps.erase(id)
		n += 1
		if not is_instance_valid(st):
			continue
		var at := st.global_position
		st.queue_free()
		if reduced:
			continue
		for k in 4:
			var shard := ColorRect.new()
			shard.color = Palette.EMBER
			shard.size = Vector2(16, 10)
			shard.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(shard)
			shard.global_position = at + Vector2(k * 22, 6)
			var tw := shard.create_tween().set_ignore_time_scale(true).set_parallel(true)
			tw.tween_property(shard, "position", shard.position + Vector2(randf_range(-20, 20), 60 + k * 10), 0.45)
			tw.tween_property(shard, "rotation", randf_range(-2.0, 2.0), 0.45)
			tw.tween_property(shard, "modulate:a", 0.0, 0.45)
			tw.chain().tween_callback(shard.queue_free)
	return n


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
## bonus or Leave table". Stays a little longer than a flash, then fades.
const CLEARED_TEXT := "TABLE CLEARED\nchase the bonus or Leave table"
const CLEARED_HOLD := 2.2


func show_cleared() -> void:
	cleared_banner.text = CLEARED_TEXT
	cleared_banner.modulate.a = 1.0
	var tw := cleared_banner.create_tween().set_ignore_time_scale(true)
	tw.tween_interval(CLEARED_HOLD)
	tw.tween_property(cleared_banner, "modulate:a", 0.0, 0.5)


func flash(text: String, col: Color) -> void:
	result_label.text = text
	result_label.label_settings.font_color = col
	result_label.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(1.0)
	tw.tween_property(result_label, "modulate:a", 0.0, 0.4)


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
