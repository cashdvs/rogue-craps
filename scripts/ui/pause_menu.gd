## In-game pause menu (Esc): Resume / Options / Quit to title. Pauses the
## tree while open; this layer keeps processing.
class_name PauseMenu
extends CanvasLayer

const TITLE_SCENE := "res://scenes/title.tscn"

signal resumed

var panel: PanelContainer
var options: OptionsPanel
var resume_button: Button


func _init() -> void:
	name = "PauseMenu"
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Palette.ink_box(Color(Palette.PIT_BLACK, 0.96), 16, 5, Palette.BRASS))
	center.add_child(panel)
	var m := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 40)
	panel.add_child(m)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	m.add_child(box)
	var title := Label.new()
	title.text = "PAUSED"
	title.label_settings = Palette.label_settings(64, Palette.BRASS_HI, 8, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	resume_button = OptionsPanel.menu_button("RESUME")
	resume_button.pressed.connect(close)
	box.add_child(resume_button)
	var opt := OptionsPanel.menu_button("OPTIONS", Palette.FELT_DARK)
	opt.pressed.connect(func() -> void:
		panel.visible = false
		options.visible = true)
	box.add_child(opt)
	var quit := OptionsPanel.menu_button("QUIT TO TITLE", Palette.PIT_BLACK)
	quit.pressed.connect(quit_to_title)
	box.add_child(quit)
	options = OptionsPanel.new()
	options.visible = false
	center.add_child(options)
	options.closed.connect(func() -> void: panel.visible = true)


func open() -> void:
	visible = true
	panel.visible = true
	options.visible = false
	get_tree().paused = true
	resume_button.grab_focus()


func close() -> void:
	visible = false
	get_tree().paused = false
	resumed.emit()


func quit_to_title() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(TITLE_SCENE)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		if options.visible:
			options.visible = false
			panel.visible = true
		else:
			close()
		get_viewport().set_input_as_handled()
