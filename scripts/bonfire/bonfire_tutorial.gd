## The one-time, skippable Table 1 tutorial (bonfire_map_events_juice.md
## section 4). Five hints in order, each shown when its moment comes; "seen"
## is saved in GameSettings (user://settings.cfg) so it shows once.
class_name BonfireTutorial
extends PanelContainer

signal skipped
signal done

const HINTS: Array[String] = [
	"Glowing dice score. Click them into your pot.",
	"Bank to keep your points, or pick up the cold dice and throw again.",
	"If nothing lights, the hand burns and you lose 1 Soul.",
	"Land every bounty card to clear the table. Points become Embers for the shop.",
	"All dice scored! Throw them all again at higher mult.",
]

var label: Label
var step_label: Label
var ok_button: Button
var skip_button: Button
## Index of the hint on screen (-1 none); hints already shown.
var current: int = -1
var shown: Array[int] = []
var active: bool = false


func _init() -> void:
	name = "BonfireTutorial"
	add_theme_stylebox_override("panel", Palette.ink_box(Color(Palette.PIT_BLACK, 0.92), 14, 5, Palette.BRASS))
	position = Vector2(560, 118)
	custom_minimum_size = Vector2(800, 0)
	visible = false
	var m := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 18)
	add_child(m)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	m.add_child(box)
	step_label = Label.new()
	step_label.label_settings = Palette.label_settings(22, Palette.BRASS_HI, 4, true)
	box.add_child(step_label)
	label = Label.new()
	label.label_settings = Palette.label_settings(30, Palette.BONE, 5)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(760, 0)
	box.add_child(label)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.alignment = BoxContainer.ALIGNMENT_END
	box.add_child(row)
	ok_button = OptionsPanel.menu_button("GOT IT", Palette.FELT_DARK)
	ok_button.custom_minimum_size = Vector2(180, 54)
	ok_button.pressed.connect(dismiss)
	row.add_child(ok_button)
	skip_button = OptionsPanel.menu_button("SKIP TUTORIAL")
	skip_button.custom_minimum_size = Vector2(260, 54)
	skip_button.pressed.connect(skip)
	row.add_child(skip_button)


func start() -> void:
	active = true
	shown.clear()
	current = -1


## Shows hint k once (only while active, in order: earlier unseen hints are
## skipped over, never shown late).
func hint(k: int) -> bool:
	if not active or shown.has(k) or k < 0 or k >= HINTS.size():
		return false
	shown.append(k)
	current = k
	step_label.text = "TUTORIAL  %d / %d" % [k + 1, HINTS.size()]
	label.text = HINTS[k]
	visible = true
	if shown.size() == HINTS.size():
		_finish()
	return true


func dismiss() -> void:
	visible = false
	current = -1


func skip() -> void:
	visible = false
	current = -1
	active = false
	skipped.emit()
	done.emit()


func _finish() -> void:
	active = false
	done.emit()
