## In-game pause menu (Esc): Resume / Options / Quit to title. Pauses the
## tree while open; this layer keeps processing. In run mode (set_run_mode)
## "Quit to title" is replaced by "Forfeit table" with a confirm step; the
## menu then only emits forfeit_confirmed and never changes scenes.
class_name PauseMenu
extends CanvasLayer

const TITLE_SCENE := "res://scenes/title.tscn"

signal resumed
signal forfeit_confirmed

var panel: PanelContainer
var options: OptionsPanel
var resume_button: Button
var quit_button: Button
var forfeit_button: Button
var confirm_panel: PanelContainer
var confirm_yes: Button
var confirm_no: Button
var run_mode: bool = false


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
	quit_button = OptionsPanel.menu_button("QUIT TO TITLE", Palette.PIT_BLACK)
	quit_button.pressed.connect(quit_to_title)
	box.add_child(quit_button)
	forfeit_button = OptionsPanel.menu_button("FORFEIT TABLE", Palette.BURGUNDY)
	forfeit_button.visible = false
	forfeit_button.pressed.connect(ask_forfeit)
	box.add_child(forfeit_button)
	_build_confirm(center)
	options = OptionsPanel.new()
	options.visible = false
	center.add_child(options)
	options.closed.connect(func() -> void: panel.visible = true)


func _build_confirm(center: Control) -> void:
	confirm_panel = PanelContainer.new()
	confirm_panel.add_theme_stylebox_override("panel", Palette.ink_box(Color(Palette.PIT_BLACK, 0.98), 16, 5, Palette.BURGUNDY))
	confirm_panel.visible = false
	center.add_child(confirm_panel)
	var m := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 40)
	confirm_panel.add_child(m)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	m.add_child(box)
	var q := Label.new()
	q.text = "FORFEIT THIS TABLE?"
	q.label_settings = Palette.label_settings(52, Palette.BRASS_HI, 8, true)
	q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(q)
	var why := Label.new()
	why.text = "The hand in play is lost and every unclaimed\nbounty costs Soul, like running out of hands."
	why.label_settings = Palette.label_settings(26, Palette.BONE, 4)
	why.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(why)
	confirm_yes = OptionsPanel.menu_button("FORFEIT", Palette.BURGUNDY)
	confirm_yes.pressed.connect(confirm_forfeit)
	box.add_child(confirm_yes)
	confirm_no = OptionsPanel.menu_button("KEEP PLAYING", Palette.FELT_DARK)
	confirm_no.pressed.connect(cancel_forfeit)
	box.add_child(confirm_no)


## Run mode swaps "Quit to title" for "Forfeit table".
func set_run_mode(on: bool) -> void:
	run_mode = on
	quit_button.visible = not on
	forfeit_button.visible = on


## Optional: asked when the menu opens (true = Forfeit allowed now). The
## table sets it so Forfeit is greyed out while a throw is in flight.
var can_forfeit: Callable


## Grey out Forfeit (e.g. the table is already over).
func set_forfeit_enabled(on: bool) -> void:
	forfeit_button.disabled = not on


func ask_forfeit() -> void:
	if not run_mode or forfeit_button.disabled:
		return
	panel.visible = false
	confirm_panel.visible = true
	confirm_no.grab_focus()


func cancel_forfeit() -> void:
	confirm_panel.visible = false
	panel.visible = true


func confirm_forfeit() -> void:
	confirm_panel.visible = false
	close()
	forfeit_confirmed.emit()


func open() -> void:
	visible = true
	panel.visible = true
	options.visible = false
	confirm_panel.visible = false
	if can_forfeit.is_valid():
		set_forfeit_enabled(bool(can_forfeit.call()))
	get_tree().paused = true
	resume_button.grab_focus()


func close() -> void:
	visible = false
	get_tree().paused = false
	resumed.emit()


func quit_to_title() -> void:
	if run_mode:
		return
	get_tree().paused = false
	get_tree().change_scene_to_file(TITLE_SCENE)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		if options.visible:
			options.visible = false
			panel.visible = true
		elif confirm_panel.visible:
			cancel_forfeit()
		else:
			close()
		get_viewport().set_input_as_handled()
