## A tarnished-brass plaque screwed onto the felt that names the table rule.
class_name RulePlaque
extends Node2D

var rule: TableRuleData
var rect := Rect2(0, 0, 170, 140)
var pulse: float = 0.0


func _draw() -> void:
	if rule == null:
		return
	var shadow := Palette.ink_box(Color(0, 0, 0, 0.45), 10, 0)
	shadow.draw(get_canvas_item(), Rect2(rect.position + Vector2(5, 7), rect.size))
	var plate := Palette.ink_box(Palette.BRASS.darkened(0.15).lerp(Palette.EMBER, pulse * 0.5), 10, 4)
	plate.draw(get_canvas_item(), rect)
	var inner := Palette.ink_box(Color(0, 0, 0, 0), 6, 2, Palette.BRASS.lightened(0.3))
	inner.draw(get_canvas_item(), rect.grow(-7))
	for c in [rect.position + Vector2(12, 12), Vector2(rect.end.x - 12, rect.position.y + 12), Vector2(rect.position.x + 12, rect.end.y - 12), rect.end - Vector2(12, 12)]:
		draw_circle(c, 4.0, Palette.PIT_BLACK)
		draw_line(c - Vector2(2.5, 2.5), c + Vector2(2.5, 2.5), Palette.BRASS.lightened(0.2), 1.5)
	var cx := rect.get_center().x
	Palette.draw_ink_text(self, Vector2(cx, rect.position.y + 26), "HOUSE RULE", 13, Palette.PIT_BLACK, 0)
	Palette.draw_ink_text(self, Vector2(cx, rect.position.y + 54), rule.display_name.to_upper(), 24, Palette.EMBER.lightened(0.15), 7)
	var font := ThemeDB.fallback_font
	draw_multiline_string(font, Vector2(rect.position.x + 16, rect.position.y + 86), rule.description, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 32, 14, 3, Palette.PIT_BLACK)
