## Options panel (title screen and pause menu): Master / SFX / Music volume,
## Fullscreen, VSync, Throw sensitivity. Reads and writes GameSettings.
class_name OptionsPanel
extends PanelContainer

signal closed

var sliders: Dictionary = {}
var fullscreen_check: CheckButton
var vsync_check: CheckButton
var tutorial_check: CheckButton
var back_button: Button


func _init() -> void:
	name = "OptionsPanel"
	add_theme_stylebox_override("panel", Palette.ink_box(Color(Palette.PIT_BLACK, 0.96), 16, 5, Palette.BRASS))
	custom_minimum_size = Vector2(760, 0)
	process_mode = Node.PROCESS_MODE_ALWAYS
	var m := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 36)
	add_child(m)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	m.add_child(box)
	var title := Label.new()
	title.text = "OPTIONS"
	title.label_settings = Palette.label_settings(56, Palette.BRASS_HI, 8, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	_slider(box, &"master_volume", "Master volume", 0.0, 1.0, 0.05, true)
	_slider(box, &"sfx_volume", "SFX volume", 0.0, 1.0, 0.05, true)
	_slider(box, &"music_volume", "Music volume", 0.0, 1.0, 0.05, true)
	_slider(box, &"throw_sensitivity", "Throw sensitivity", 0.5, 2.0, 0.05, false)
	fullscreen_check = _check(box, &"fullscreen", "Fullscreen")
	fullscreen_check.visible = _gs() == null or _gs().can_window()
	vsync_check = _check(box, &"vsync", "VSync")
	tutorial_check = _check(box, &"tutorial_enabled", "Table 1 tutorial")
	back_button = OptionsPanel.menu_button("BACK")
	back_button.pressed.connect(func() -> void:
		visible = false
		closed.emit())
	box.add_child(back_button)


func _ready() -> void:
	sync_from_settings()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and visible and is_inside_tree():
		sync_from_settings()


func _gs() -> Node:
	return get_node_or_null("/root/GameSettings") if is_inside_tree() else null


func sync_from_settings() -> void:
	var gs := _gs()
	if gs == null:
		return
	for k: StringName in sliders:
		(sliders[k] as HSlider).set_value_no_signal(float(gs.get(k)))
		_update_value_label(k)
	fullscreen_check.set_pressed_no_signal(bool(gs.get("fullscreen")))
	vsync_check.set_pressed_no_signal(bool(gs.get("vsync")))
	tutorial_check.set_pressed_no_signal(bool(gs.get("tutorial_enabled")))


func _apply_option(key: StringName, value: Variant) -> void:
	var gs := _gs()
	if gs != null:
		gs.set_option(key, value)


func _slider(parent: Control, key: StringName, text: String, lo: float, hi: float, step: float, percent: bool) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	parent.add_child(row)
	var l := Label.new()
	l.text = text
	l.label_settings = Palette.label_settings(28, Palette.BONE, 5)
	l.custom_minimum_size = Vector2(270, 0)
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.custom_minimum_size = Vector2(300, 36)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.set_meta("percent", percent)
	s.add_theme_stylebox_override("slider", Palette.ink_box(Palette.FELT_DARK, 8, 3))
	s.add_theme_stylebox_override("grabber_area", Palette.ink_box(Palette.EMBER, 8, 3))
	s.add_theme_stylebox_override("grabber_area_highlight", Palette.ink_box(Palette.BRASS_HI, 8, 3))
	row.add_child(s)
	var v := Label.new()
	v.label_settings = Palette.label_settings(26, Palette.BRASS_HI, 5)
	v.custom_minimum_size = Vector2(90, 0)
	row.add_child(v)
	s.set_meta("value_label", v)
	sliders[key] = s
	s.value_changed.connect(func(x: float) -> void:
		_apply_option(key, x)
		_update_value_label(key))


func _update_value_label(key: StringName) -> void:
	var s: HSlider = sliders[key]
	var v: Label = s.get_meta("value_label")
	v.text = ("%d%%" % roundi(s.value * 100.0)) if s.get_meta("percent") else ("%.2fx" % s.value)


func _check(parent: Control, key: StringName, text: String) -> CheckButton:
	var c := CheckButton.new()
	c.text = text
	c.add_theme_font_size_override("font_size", 28)
	c.add_theme_color_override("font_color", Palette.BONE)
	c.focus_mode = Control.FOCUS_ALL
	c.toggled.connect(func(on: bool) -> void: _apply_option(key, on))
	parent.add_child(c)
	return c


## A menu button in the noir style (title, pause, options).
static func menu_button(text: String, fill: Color = Palette.BURGUNDY) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(380, 76)
	var f := Palette.display_font()
	if f != null:
		b.add_theme_font_override("font", f)
	b.add_theme_font_size_override("font_size", 36)
	b.add_theme_color_override("font_color", Palette.BONE)
	b.add_theme_color_override("font_hover_color", Palette.BRASS_HI)
	b.add_theme_stylebox_override("normal", Palette.ink_box(fill))
	b.add_theme_stylebox_override("hover", Palette.ink_box(fill.lightened(0.12), 12, 4, Palette.BRASS))
	b.add_theme_stylebox_override("focus", Palette.ink_box(fill.lightened(0.12), 12, 4, Palette.BRASS_HI))
	b.add_theme_stylebox_override("pressed", Palette.ink_box(fill.darkened(0.2)))
	b.add_theme_stylebox_override("disabled", Palette.ink_box(Color(fill, 0.4)))
	return b
