## The Dealer's speech bubble. It is only ever visible with its full line
## already in the label (no typewriter): it pops in with a squash, holds,
## then fades away. A newer taunt replaces the current one. Its tweens
## ignore Engine.time_scale, so hit-stop (time_scale 0.05) and fast-forward
## never leave it half-drawn.
class_name DealerBubble
extends Node2D

const WIDTH: float = 520.0

var label: Label
var _panel: PanelContainer
var _tw: Tween


func _init() -> void:
	visible = false
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", _panel_style())
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)
	label = Label.new()
	label.custom_minimum_size = Vector2(WIDTH - 48.0, 0)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var ls := LabelSettings.new()
	ls.font = Palette.number_font()
	ls.font_size = 34
	ls.font_color = Palette.OXBLOOD
	label.label_settings = ls
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(label)


func _panel_style() -> StyleBoxFlat:
	var box := Palette.ink_box(Palette.BONE, 26, 5)
	box.content_margin_left = 24
	box.content_margin_right = 24
	box.content_margin_top = 14
	box.content_margin_bottom = 14
	return box


## Shows a line. Empty lines are ignored (the bubble never shows empty).
func say(line: String, hold: float = 2.4, reduced: bool = false) -> void:
	if line.strip_edges() == "":
		return
	if _tw != null and _tw.is_valid():
		_tw.kill()
	label.text = line
	_panel.reset_size()
	# Tail tip at the local origin (the Dealer's mouth); panel to the right.
	var h := maxf(_panel.get_combined_minimum_size().y, 80.0)
	_panel.position = Vector2(40, -h * 0.5)
	modulate.a = 1.0
	visible = true
	queue_redraw()
	_tw = create_tween()
	_tw.set_ignore_time_scale(true)
	if reduced:
		scale = Vector2.ONE
	else:
		scale = Vector2(0.6, 0.6)
		_tw.tween_property(self, "scale", Vector2(1.06, 0.96), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_tw.tween_property(self, "scale", Vector2.ONE, 0.08)
	_tw.tween_interval(hold)
	_tw.tween_property(self, "modulate:a", 0.0, 0.25)
	_tw.tween_callback(_finish)


func _finish() -> void:
	visible = false
	label.text = ""


func _draw() -> void:
	# Tail (ink, then bone fill over it; the panel covers the seam).
	draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(56, -18), Vector2(56, 14)]), Palette.PIT_BLACK)
	draw_colored_polygon(PackedVector2Array([Vector2(8, -1), Vector2(60, -12), Vector2(60, 8)]), Palette.BONE)
