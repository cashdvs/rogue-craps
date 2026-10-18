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

var coin_label: Label
var points_label: Label
var checklist: VBoxContainer
var bounty_rows: Dictionary = {}
var hands_label: Label
var pot_label: Label
var throw_label: Label
var mult_label: Label
var result_label: Label
var bank_button: Button
var throw_button: Button
var end_panel: PanelContainer
var end_title: Label
var end_body: Label
var restart_button: Button
var continue_button: Button


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
	checklist = VBoxContainer.new()
	checklist.add_theme_constant_override("separation", 4)
	panel.add_child(checklist)
	pot_label = _label(64, Palette.BRASS_HI, Vector2(560, 870), Vector2(800, 80))
	throw_label = _label(34, Palette.EMBER, Vector2(360, 950), Vector2(1200, 46))
	mult_label = _label(34, Color("#FF2E3E"), Vector2(1260, 880), Vector2(260, 60))
	result_label = _label(64, Palette.BRASS_HI, Vector2(460, 380), Vector2(1000, 90))
	result_label.modulate.a = 0.0
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


func refresh(run: BonfireRun, can_act: bool) -> void:
	coin_label.text = "EMBERS %d" % run.embers
	points_label.text = "points %d  (1 Ember / %d)" % [run.points, run.tuning.points_per_ember]
	hands_label.text = "HANDS LEFT %d" % run.hands_left
	_refresh_checklist(run)
	pot_label.text = "POT %d" % run.hand_pot()
	var picking := run.state == BonfireRun.State.PICK
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
		throw_button.disabled = not (can_act and run.can_continue())
		throw_button.text = "HOT HAND! ALL %d" % run.dice_count if run.is_hot() else "THROW %d AGAIN" % (run.throw_faces.size() - run.potted.size())
	else:
		throw_button.disabled = not can_act
		throw_button.text = "THROW %d  (Space)" % run.cold


func _refresh_checklist(run: BonfireRun) -> void:
	if bounty_rows.is_empty() or not bounty_rows.has(run.goal.required[0].id) or bounty_rows.size() != run.all_bounties().size():
		for c in checklist.get_children():
			c.queue_free()
		bounty_rows.clear()
		var title := Label.new()
		title.text = "%s BOUNTIES" % run.goal.display_name.to_upper()
		title.label_settings = Palette.label_settings(24, Palette.BRASS_HI, 5, true)
		checklist.add_child(title)
		for b: BountyData in run.all_bounties():
			var l := Label.new()
			l.label_settings = Palette.label_settings(24, Palette.BONE, 4)
			l.tooltip_text = b.description
			checklist.add_child(l)
			bounty_rows[b.id] = l
	for b: BountyData in run.all_bounties():
		var l: Label = bounty_rows[b.id]
		var bonus := run.goal.bonus.has(b)
		var mark := "[x]" if run.is_ticked(b) else ("[?]" if run.is_pending(b) else "[ ]")
		l.text = "%s %s%s" % [mark, b.display_name, ("  +%d Embers" % b.bonus_embers) if bonus else ""]
		l.label_settings.font_color = Color("#9FE08A") if run.is_ticked(b) else (Palette.EMBER if run.is_pending(b) else (Palette.BONE if not bonus else Color(Palette.BONE, 0.7)))


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
			end_body.text = "Every bounty banked with %d hands to spare.\n%s\nSoul %d." % [run.hands_left, ember_line, run.soul]
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
