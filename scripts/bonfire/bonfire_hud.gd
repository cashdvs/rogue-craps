## Bonfire HUD (plain Controls, 1920x1080 design space): coin vs target,
## hands left, the hand's pot (+ this throw, x2 tag), BANK / THROW buttons and
## the end screen with Restart.
class_name BonfireHud
extends Control

signal bank_pressed
signal throw_pressed
signal restart_pressed

var coin_label: Label
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


func _init() -> void:
	name = "BonfireHud"
	size = Vector2(1920, 1080)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	coin_label = _label(40, Palette.BONE, Vector2(1560, 30), Vector2(340, 50))
	hands_label = _label(30, Palette.BONE, Vector2(1560, 84), Vector2(340, 40))
	pot_label = _label(64, Palette.BRASS_HI, Vector2(660, 880), Vector2(600, 80))
	throw_label = _label(30, Palette.EMBER, Vector2(660, 960), Vector2(600, 40))
	mult_label = _label(34, Color("#FF2E3E"), Vector2(1180, 890), Vector2(200, 60))
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


func refresh(run: BonfireRun, can_act: bool) -> void:
	coin_label.text = "COIN %d / %d" % [run.coin, run.tuning.coin_target]
	hands_label.text = "HANDS LEFT %d" % run.hands_left
	pot_label.text = "POT %d" % run.hand_pot()
	var picking := run.state == BonfireRun.State.PICK
	if picking:
		var pts := run.throw_points()
		throw_label.text = ("this throw +%d" % pts) if pts > 0 else "Click burning dice to pot them"
	else:
		throw_label.text = "Grab the %d dice and flick" % run.cold
	mult_label.text = ("x%d" % run.multiplier) if run.multiplier > 1 else ""
	bank_button.disabled = not (can_act and run.can_continue())
	if picking:
		throw_button.disabled = not (can_act and run.can_continue())
		throw_button.text = "HOT HAND! ALL %d x%d" % [run.tuning.dice_count, run.tuning.hot_hand_multiplier] if run.is_hot() else "THROW %d AGAIN" % (run.throw_faces.size() - run.potted.size())
	else:
		throw_button.disabled = not can_act
		throw_button.text = "THROW %d  (Space)" % run.cold


func flash(text: String, col: Color) -> void:
	result_label.text = text
	result_label.label_settings.font_color = col
	result_label.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(1.0)
	tw.tween_property(result_label, "modulate:a", 0.0, 0.4)


func show_end(run: BonfireRun) -> void:
	match run.state:
		BonfireRun.State.CLEARED:
			end_title.text = "TABLE CLEARED"
			end_body.text = "%d coin (target %d) with %d hands to spare. Soul %d." % [run.coin, run.tuning.coin_target, run.hands_left, run.soul]
		BonfireRun.State.RUN_OVER:
			end_title.text = "SOUL BURNED OUT"
			end_body.text = "The bonfire took everything. %d coin." % run.coin
		_:
			end_title.text = "TABLE LOST"
			end_body.text = "Out of hands at %d of %d coin." % [run.coin, run.tuning.coin_target]
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
