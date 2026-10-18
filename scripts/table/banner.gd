## Moment banners (poc_feel.md 6): a notched ribbon with chunky slab text,
## centered on the banner layer at (960, 470). Optional 12-ray starburst
## behind (Natural), optional jitter (Seven-out), optional subtext.
class_name Banner
extends Node2D

var text: String = ""
var subtext: String = ""
var ribbon_color: Color = Palette.BURGUNDY
var text_color: Color = Palette.BONE
var text_size: int = 120
var rays: bool = false
var jitter: bool = false
var _t: float = 0.0
var _rng := RandomNumberGenerator.new()


## Pops the banner in, holds, fades. Frees itself. `reduced` = fade only.
func play(duration: float, reduced: bool) -> void:
	modulate.a = 0.0
	if reduced:
		scale = Vector2.ONE
		var tr := create_tween()
		tr.tween_property(self, "modulate:a", 1.0, 0.12)
		tr.tween_interval(maxf(duration - 0.4, 0.1))
		tr.tween_property(self, "modulate:a", 0.0, 0.25)
		tr.tween_callback(queue_free)
		return
	scale = Vector2(0.3, 0.3)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.08)
	tw.parallel().tween_property(self, "scale", Vector2(1.12, 1.12), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", Vector2.ONE, 0.1)
	tw.tween_interval(maxf(duration - 0.55, 0.1))
	tw.tween_property(self, "modulate:a", 0.0, 0.25)
	tw.parallel().tween_property(self, "position:y", position.y - 30.0, 0.25)
	tw.tween_callback(queue_free)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var font := Palette.display_font()
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size).x + 160.0
	var hh := text_size * 0.62
	if rays:
		for i in 12:
			var a := _t * 0.6 + TAU * float(i) / 12.0
			var p0 := Vector2.from_angle(a - 0.09) * 900.0
			var p1 := Vector2.from_angle(a + 0.09) * 900.0
			draw_colored_polygon(PackedVector2Array([Vector2.ZERO, p0, p1]), Color(Palette.BRASS_HI, 0.22))
	var off := Vector2.ZERO
	if jitter:
		off = Vector2(_rng.randf_range(-4, 4), _rng.randf_range(-3, 3))
	var notch := 40.0
	var ribbon := PackedVector2Array([
		Vector2(-w * 0.5 - notch, -hh) + off, Vector2(w * 0.5 + notch, -hh) + off,
		Vector2(w * 0.5, 0) + off, Vector2(w * 0.5 + notch, hh) + off,
		Vector2(-w * 0.5 - notch, hh) + off, Vector2(-w * 0.5, 0) + off])
	draw_colored_polygon(PackedVector2Array(Array(ribbon).map(func(v: Vector2) -> Vector2: return v + Vector2(0, 10))), Color(0, 0, 0, 0.5))
	draw_colored_polygon(ribbon, ribbon_color)
	var closed := ribbon.duplicate()
	closed.append(ribbon[0])
	draw_polyline(closed, Palette.PIT_BLACK, 6.0, true)
	draw_line(Vector2(-w * 0.5, -hh + 12) + off, Vector2(w * 0.5, -hh + 12) + off, Color(Palette.BRASS, 0.8), 3.0)
	draw_line(Vector2(-w * 0.5, hh - 12) + off, Vector2(w * 0.5, hh - 12) + off, Color(Palette.BRASS, 0.8), 3.0)
	Palette.draw_ink_text(self, off + Vector2(0, -4), text, text_size, text_color, 14, true)
	if subtext != "":
		Palette.draw_ink_text(self, off + Vector2(0, hh + 44), subtext, 48, text_color, 10, true)
