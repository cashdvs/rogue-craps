## The Burn Line HUD (2D, 1920x1080 design space): coin vs target, hands
## left, the total-vs-Line track with its payout bands, the two die buttons,
## the bet selector, the Exact Hit toggle, Stop, the "Change dice" picker and
## the end-of-table screen. It only shows BurnLineRun state and emits what
## the player pressed; BurnLine3D applies it.
class_name BurnLineHud
extends Control

signal die_pressed(index: int)
signal stop_pressed
signal bet_step(step: int)
signal side_toggled(on: bool)
signal loadout_chosen(ids: Array[StringName])
signal end_action(action: StringName)

const TRACK_POS := Vector2(460, 900)
const TRACK_SIZE := Vector2(1000, 54)

var coin_label: Label
var hands_label: Label
var table_label: Label
var total_label: Label
var line_label: Label
var result_label: Label
var bet_label: Label
var side_button: Button
var stop_button: Button
var change_button: Button
var die_buttons: Array[Button] = []
var track: Control
var picker: PanelContainer
var picker_checks: Array[CheckBox] = []
var picker_ids: Array[StringName] = []
var end_panel: PanelContainer
var end_title: Label
var end_body: Label
var end_button: Button
var _end_action: StringName = &"restart"
var _line: int = 15
var _total: int = 0
var _tuning: BurnLineTuning


func _init() -> void:
	name = "BurnLineHud"
	size = Vector2(1920, 1080)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Top: table, coin vs target, hands left.
	table_label = _label(28, Palette.BRASS_HI, Vector2(760, 18), Vector2(400, 40), true)
	coin_label = _label(40, Palette.BONE, Vector2(1580, 30), Vector2(320, 50), true)
	hands_label = _label(30, Palette.BONE, Vector2(1580, 84), Vector2(320, 40), true)
	# Total vs Line, over the track.
	total_label = _label(84, Palette.BONE, Vector2(860, 790), Vector2(200, 100), true)
	line_label = _label(28, Palette.EMBER, Vector2(1060, 820), Vector2(260, 40), true)
	line_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	result_label = _label(56, Palette.BRASS_HI, Vector2(460, 380), Vector2(1000, 80), true)
	result_label.modulate.a = 0.0
	track = Control.new()
	track.position = TRACK_POS
	track.size = TRACK_SIZE
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.draw.connect(_draw_track)
	add_child(track)
	# Right column: dice, bet, side bet, Stop, Change dice.
	var col := VBoxContainer.new()
	col.position = Vector2(1580, 160)
	col.custom_minimum_size = Vector2(310, 0)
	col.add_theme_constant_override("separation", 12)
	add_child(col)
	for i in 2:
		var b := _button("", 24, Palette.FELT_DARK)
		b.custom_minimum_size = Vector2(310, 96)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.pressed.connect(func() -> void: die_pressed.emit(i))
		col.add_child(b)
		die_buttons.append(b)
	var bet_row := HBoxContainer.new()
	bet_row.add_theme_constant_override("separation", 8)
	col.add_child(bet_row)
	var minus := _button("-", 34, Palette.BURGUNDY)
	minus.custom_minimum_size = Vector2(64, 64)
	minus.pressed.connect(func() -> void: bet_step.emit(-1))
	bet_row.add_child(minus)
	bet_label = _label(30, Palette.BONE, Vector2.ZERO, Vector2(166, 64), true)
	bet_label.custom_minimum_size = Vector2(166, 64)
	remove_child(bet_label)
	bet_row.add_child(bet_label)
	var plus := _button("+", 34, Palette.BURGUNDY)
	plus.custom_minimum_size = Vector2(64, 64)
	plus.pressed.connect(func() -> void: bet_step.emit(1))
	bet_row.add_child(plus)
	side_button = _button("", 22, Palette.FELT_DARK)
	side_button.toggle_mode = true
	side_button.custom_minimum_size = Vector2(310, 60)
	side_button.toggled.connect(func(on: bool) -> void: side_toggled.emit(on))
	col.add_child(side_button)
	stop_button = _button("STOP  (S)", 38, Palette.BURGUNDY)
	stop_button.custom_minimum_size = Vector2(310, 84)
	stop_button.pressed.connect(func() -> void: stop_pressed.emit())
	col.add_child(stop_button)
	change_button = _button("Change dice", 22, Palette.PIT_BLACK)
	change_button.custom_minimum_size = Vector2(310, 48)
	change_button.pressed.connect(_open_picker)
	col.add_child(change_button)
	_build_picker()
	_build_end()


func refresh(run: BurnLineRun, selected: int, shown_total: int, can_act: bool) -> void:
	_tuning = run.tuning
	_line = run.line()
	_total = shown_total
	var t := run.table()
	table_label.text = "%s  -  LINE %d" % [t.display_name.to_upper(), _line]
	coin_label.text = "COIN %d / %d" % [run.bankroll(), t.coin_target]
	hands_label.text = "HANDS LEFT %d" % run.hands_left
	total_label.text = str(shown_total)
	var d := _line - shown_total
	total_label.label_settings.font_color = Color("#FF2E3E") if d < 0 else (Palette.BRASS_HI if d == 0 else Palette.BONE)
	line_label.text = "/ LINE %d" % _line
	for i in die_buttons.size():
		var b := die_buttons[i]
		b.visible = i < run.loadout.size()
		if not b.visible:
			continue
		var die := run.loadout[i]
		var left := run.throws_left(die)
		b.text = "%d  %s%s\n%s" % [i + 1, die.display_name.to_upper(), "" if left < 0 else ("  (%d left)" % left), die.faces_text()]
		b.disabled = left == 0 or not can_act
		var fill := die.body_color.darkened(0.55) if i == selected else Palette.PIT_BLACK
		b.add_theme_stylebox_override("normal", Palette.ink_box(fill, 12, 6 if i == selected else 3, Palette.BRASS_HI if i == selected else Palette.PIT_BLACK))
		b.add_theme_stylebox_override("hover", Palette.ink_box(fill.lightened(0.1), 12, 6 if i == selected else 3, Palette.BRASS_HI))
	var locked := run.hand_started()
	bet_label.text = "BET %d%s" % [run.bet, "" if locked else ""]
	side_button.set_pressed_no_signal(run.side_bet)
	side_button.text = "EXACT HIT %s  (%d, pays %d:1)" % ["ON" if run.side_bet else "off", run.tuning.exact_side_cost, run.tuning.exact_side_pay]
	side_button.disabled = locked or not can_act
	stop_button.disabled = not (can_act and run.can_stop())
	change_button.disabled = locked or not can_act
	track.queue_redraw()


func show_result(r: Dictionary, gain: int) -> void:
	var kind: StringName = r["kind"]
	var text := ""
	var col := Palette.BONE
	match kind:
		&"burn":
			text = "BURN!  -%d SOUL" % int(r["soul_lost"])
			col = Color("#FF2E3E")
		&"exact":
			text = "EXACT!  +%d" % gain
			col = Palette.BRASS_HI
		&"close":
			text = "1 UNDER  +%d" % gain
			col = Color("#9FE08A")
		&"near":
			text = "%d UNDER  +%d" % [int(r["line"]) - int(r["total"]), gain]
			col = Palette.EMBER
		_:
			text = "TOO LOW  +0"
	result_label.text = text
	result_label.label_settings.font_color = col
	var tw := create_tween()
	result_label.modulate.a = 1.0
	result_label.scale = Vector2.ONE * 1.2
	result_label.pivot_offset = result_label.size * 0.5
	tw.tween_property(result_label, "scale", Vector2.ONE, 0.15)
	tw.tween_interval(1.1)
	tw.tween_property(result_label, "modulate:a", 0.0, 0.4)


# --- Track: 0..Line+3 with the payout bands ---------------------------------

func _draw_track() -> void:
	var top := _line + 3
	var w := TRACK_SIZE.x / float(top)
	var h := TRACK_SIZE.y
	for v in range(1, top + 1):
		var d := _line - v
		var col := Color(Palette.FELT_DARK, 0.9)
		if d < 0:
			col = Color("#5A0A14")
		elif d == 0:
			col = Palette.BRASS
		elif d == 1:
			col = Color("#3C6A34")
		elif _tuning != null and _tuning.return_for(d) > 0.0:
			col = Color("#7A3A16")
		var r := Rect2((v - 1) * w + 2, 0, w - 4, h)
		track.draw_rect(r, col)
		if v <= _total:
			track.draw_rect(r, Color(1, 1, 1, 0.18))
		if v == _line or v == _line - 1 or v == _line - 3 or v % 5 == 0:
			Palette.draw_ink_text(track, r.position + Vector2(w * 0.5 - 10, h + 26), str(v), 20, Palette.BONE, 4)
	# The Burn Line itself and the total marker.
	var lx := _line * w
	track.draw_rect(Rect2(lx - 3, -10, 6, h + 20), Palette.EMBER)
	if _total > 0:
		var mx := clampf((_total - 0.5) * w, 0.0, TRACK_SIZE.x)
		track.draw_colored_polygon(PackedVector2Array([Vector2(mx - 14, -22), Vector2(mx + 14, -22), Vector2(mx, -4)]), Palette.BONE)
	Palette.draw_ink_text(track, Vector2(0, -30), "EXACT x%.1f   1 UNDER x%.1f   2-3 UNDER x%.1f   OVER = BURN" % [_ret(0), _ret(1), _ret(2)], 20, Palette.BONE, 4)


func _ret(d: int) -> float:
	return _tuning.return_for(d) if _tuning != null else 0.0


# --- Change dice -------------------------------------------------------------

func _build_picker() -> void:
	picker = PanelContainer.new()
	picker.add_theme_stylebox_override("panel", Palette.ink_box(Color(Palette.PIT_BLACK, 0.95)))
	picker.position = Vector2(560, 260)
	picker.custom_minimum_size = Vector2(800, 420)
	picker.visible = false
	add_child(picker)


func _open_picker() -> void:
	if _tuning == null:
		return
	for c in picker.get_children():
		c.queue_free()
	picker_checks.clear()
	picker_ids.clear()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	picker.add_child(box)
	var title := Label.new()
	title.text = "CHANGE DICE: pick %d" % _tuning.loadout_size
	title.label_settings = Palette.label_settings(34, Palette.BRASS_HI, 6, true)
	box.add_child(title)
	for d in _tuning.dice:
		var cb := CheckBox.new()
		cb.text = "%s   %s\n%s" % [d.display_name, d.faces_text(), d.perk_text]
		cb.add_theme_font_size_override("font_size", 24)
		box.add_child(cb)
		picker_checks.append(cb)
		picker_ids.append(d.id)
	var std := _tuning.find_loadout(_tuning.default_loadout)
	if std != null:
		for i in picker_ids.size():
			picker_checks[i].button_pressed = std.dice.has(picker_ids[i])
	var row := HBoxContainer.new()
	box.add_child(row)
	var ok := _button("Use these", 26, Palette.BURGUNDY)
	ok.pressed.connect(func() -> void:
		var ids: Array[StringName] = []
		for i in picker_checks.size():
			if picker_checks[i].button_pressed:
				ids.append(picker_ids[i])
		if ids.size() == _tuning.loadout_size:
			picker.visible = false
			loadout_chosen.emit(ids))
	row.add_child(ok)
	var cancel := _button("Cancel", 26, Palette.PIT_BLACK)
	cancel.pressed.connect(func() -> void: picker.visible = false)
	row.add_child(cancel)
	picker.visible = true


# --- End of table ------------------------------------------------------------

func _build_end() -> void:
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
	end_button = _button("", 34, Palette.BURGUNDY)
	end_button.custom_minimum_size = Vector2(360, 80)
	end_button.pressed.connect(func() -> void: end_action.emit(_end_action))
	box.add_child(end_button)


func show_end(run: BurnLineRun) -> void:
	var t := run.table()
	match run.state:
		BurnLineRun.State.TABLE_CLEARED:
			end_title.text = "TABLE CLEARED"
			end_body.text = "%d coin (target %d). Soul %d carries on.\nNext: %s, Line %d." % [run.coin, t.coin_target, run.soul, run.tuning.tables[run.table_index + 1].display_name, run.tuning.tables[run.table_index + 1].line]
			end_button.text = "Next table"
			_end_action = &"next"
		BurnLineRun.State.RUN_WON:
			end_title.text = "RUN WON!"
			end_body.text = "You beat %s with %d coin and %d Soul left." % [t.display_name, run.coin, run.soul]
			end_button.text = "Play again"
			_end_action = &"restart"
		BurnLineRun.State.RUN_OVER:
			end_title.text = "SOUL BURNED OUT"
			end_body.text = "The house keeps your soul."
			end_button.text = "Restart run"
			_end_action = &"restart"
		_:
			end_title.text = "TABLE LOST"
			end_body.text = "%d coin of %d%s." % [run.coin, t.coin_target, " and no hands left" if run.hands_left <= 0 else ", can't cover the minimum bet"]
			end_button.text = "Restart run"
			_end_action = &"restart"
	end_panel.visible = true


func hide_end() -> void:
	end_panel.visible = false


func _label(px: int, col: Color, pos: Vector2, sz: Vector2, display: bool = false) -> Label:
	var l := Label.new()
	l.label_settings = Palette.label_settings(px, col, 6, display)
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
