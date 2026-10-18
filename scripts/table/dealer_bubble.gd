## The Dealer's speech bubble: pops in with a squash, types the line out,
## holds, then pops away. A newer taunt replaces the current one.
class_name DealerBubble
extends Node2D

var text: String = ""
var _shown_chars: float = 0.0
var _tw: Tween
var bubble_size := Vector2(520, 110)


func say(line: String, hold: float = 2.4, reduced: bool = false) -> void:
	text = line
	visible = true
	if _tw != null and _tw.is_valid():
		_tw.kill()
	_tw = create_tween()
	if reduced:
		scale = Vector2.ONE
		modulate.a = 0.0
		_shown_chars = float(text.length())
		_tw.tween_property(self, "modulate:a", 1.0, 0.12)
	else:
		modulate.a = 1.0
		scale = Vector2(0.2, 0.2)
		_shown_chars = 0.0
		_tw.tween_property(self, "scale", Vector2(1.08, 0.94), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_tw.tween_property(self, "scale", Vector2.ONE, 0.08)
		_tw.tween_property(self, "_shown_chars", float(text.length()), minf(text.length() * 0.014, 0.45))
	_tw.tween_interval(hold)
	_tw.tween_property(self, "modulate:a", 0.0, 0.25)
	_tw.tween_callback(hide)


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _draw() -> void:
	# Local origin = the tail tip (at the Dealer's mouth).
	var r := Rect2(Vector2(40, -bubble_size.y * 0.5 - 10), bubble_size)
	draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(56, -18), Vector2(56, 14)]), Palette.PIT_BLACK)
	draw_style_box(Palette.ink_box(Palette.BONE, 26, 5), r)
	draw_colored_polygon(PackedVector2Array([Vector2(8, -1), Vector2(60, -14), Vector2(60, 9)]), Palette.BONE)
	var font := Palette.number_font()
	var shown := text.substr(0, int(_shown_chars))
	draw_multiline_string(font, r.position + Vector2(24, 46), shown, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 48, 34, 2, Palette.OXBLOOD)
