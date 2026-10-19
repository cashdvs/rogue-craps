## HUD for the running-total mode (groundwork for Burn Line, spec pending):
## a big total that counts up after each die, a gauge with a placeholder
## target-line marker, the list of dice thrown so far, and a Stop button.
## It only displays a RunningTotal and forwards the Stop press; the rules
## live in RunningTotal (scripts/core) and the director (Table3D).
class_name RunningTotalHud
extends Control

## The player pressed Stop (button or S key, see Table3D).
signal stop_pressed

const PANEL_W: float = 300.0
const GAUGE_H: float = 420.0

var total_label: Label
var line_label: Label
var list_box: VBoxContainer
var stop_button: Button
var gauge: Control
## The number currently shown (animates toward the real total).
var shown_total: float = 0.0
var target_line: int = 21
var _gauge_total: float = 0.0
var _count_tween: Tween


func _init() -> void:
	name = "RunningTotalHud"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = Vector2(1920 - PANEL_W - 40, 230)
	size = Vector2(PANEL_W, 760)
	var bg := Panel.new()
	bg.add_theme_stylebox_override("panel", Palette.ink_box(Color(Palette.PIT_BLACK, 0.78)))
	bg.size = size
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var title := Label.new()
	title.text = "TOTAL"
	title.label_settings = Palette.label_settings(26, Palette.BRASS_HI, 6, true)
	title.position = Vector2(20, 12)
	add_child(title)
	total_label = Label.new()
	total_label.text = "0"
	total_label.label_settings = Palette.label_settings(96, Palette.BONE, 10, true)
	total_label.position = Vector2(20, 40)
	total_label.size = Vector2(150, 110)
	total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	total_label.pivot_offset = Vector2(75, 55)
	add_child(total_label)
	line_label = Label.new()
	line_label.label_settings = Palette.label_settings(22, Palette.EMBER, 5)
	line_label.position = Vector2(20, 150)
	add_child(line_label)
	# Gauge: fills with the total; a bright marker shows the target line.
	gauge = Control.new()
	gauge.position = Vector2(PANEL_W - 70, 24)
	gauge.size = Vector2(36, GAUGE_H)
	gauge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gauge.draw.connect(_draw_gauge)
	add_child(gauge)
	var thrown := Label.new()
	thrown.text = "THROWN"
	thrown.label_settings = Palette.label_settings(20, Palette.BRASS, 5)
	thrown.position = Vector2(20, 190)
	add_child(thrown)
	list_box = VBoxContainer.new()
	list_box.position = Vector2(20, 220)
	list_box.size = Vector2(PANEL_W - 110, 380)
	list_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(list_box)
	stop_button = Button.new()
	stop_button.text = "STOP  (S)"
	stop_button.position = Vector2(20, 670)
	stop_button.size = Vector2(PANEL_W - 40, 64)
	stop_button.add_theme_font_size_override("font_size", 30)
	stop_button.add_theme_stylebox_override("normal", Palette.ink_box(Palette.BURGUNDY))
	stop_button.add_theme_stylebox_override("hover", Palette.ink_box(Palette.DANGER_DARK))
	stop_button.add_theme_stylebox_override("pressed", Palette.ink_box(Palette.OXBLOOD))
	stop_button.add_theme_stylebox_override("disabled", Palette.ink_box(Color(Palette.OXBLOOD, 0.5)))
	stop_button.pressed.connect(func() -> void: stop_pressed.emit())
	add_child(stop_button)
	set_line(target_line)


## Shows the target-line value (placeholder number until the spec lands).
func set_line(line: int) -> void:
	target_line = line
	line_label.text = "LINE  %d" % line
	gauge.queue_redraw()


## Rebuilds the list and counts the big number up to `rt.total`.
func show_total(rt: RunningTotal, instant: bool = false) -> void:
	for c in list_box.get_children():
		c.queue_free()
	for i in rt.throws.size():
		var t: Dictionary = rt.throws[i]
		var row := Label.new()
		row.text = "%d.  %s   +%d" % [i + 1, String(t["die"]), int(t["value"])]
		row.label_settings = Palette.label_settings(22, Palette.BONE, 4)
		list_box.add_child(row)
	stop_button.disabled = rt.count() == 0
	if _count_tween != null and _count_tween.is_valid():
		_count_tween.kill()
	if instant or rt.total < shown_total:
		_set_shown(float(rt.total))
		return
	# Count up (about 0.08 s per point, max 0.5 s), then a small punch.
	var dur := clampf((rt.total - shown_total) * 0.08, 0.12, 0.5)
	_count_tween = create_tween()
	_count_tween.tween_method(_set_shown, shown_total, float(rt.total), dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_count_tween.tween_property(total_label, "scale", Vector2.ONE * 1.18, 0.06)
	_count_tween.tween_property(total_label, "scale", Vector2.ONE, 0.12)


## A short "stopped at" note after Stop (the total itself is already reset).
func show_stopped(final_total: int) -> void:
	line_label.text = "STOPPED AT %d  (line %d)" % [final_total, target_line]


func _set_shown(v: float) -> void:
	shown_total = v
	total_label.text = str(int(round(v)))
	var over := int(round(v)) > target_line
	total_label.label_settings.font_color = Palette.DANGER if over else (Palette.BRASS_HI if int(round(v)) == target_line else Palette.BONE)
	_gauge_total = v
	gauge.queue_redraw()


func _draw_gauge() -> void:
	var top := float(target_line) * 1.3  # the gauge shows a bit past the line
	var r := Rect2(Vector2.ZERO, gauge.size)
	gauge.draw_rect(r, Palette.FELT_DARK)
	var fill := clampf(_gauge_total / maxf(top, 1.0), 0.0, 1.0) * r.size.y
	var col := Palette.DANGER if _gauge_total > target_line else Palette.SOUL_FLAME
	gauge.draw_rect(Rect2(0, r.size.y - fill, r.size.x, fill), col)
	var ly := r.size.y - float(target_line) / maxf(top, 1.0) * r.size.y
	gauge.draw_rect(Rect2(-8, ly - 2, r.size.x + 16, 4), Palette.EMBER)
	gauge.draw_rect(r, Palette.PIT_BLACK, false, 3.0)
