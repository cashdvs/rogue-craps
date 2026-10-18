## A clickable bet area painted on the felt (Pass Line, Field, Any Craps).
## Draws its own markings; the table scene handles clicks and chip stacks.
class_name BetZone
extends Node2D

enum Look { PASS_LINE, FIELD, HARD_WAY, ANY_CRAPS }

var bet_type: BetType
var look: Look = Look.PASS_LINE
## Clickable rectangle in local coordinates.
var rect := Rect2(0, 0, 200, 80)
## Where the stake's chip stack sits (local).
var chip_anchor := Vector2(40, 40)
var hovered: bool = false
var locked: bool = false
## Brief glow after a win (0..1), animated by the table.
var glow: float = 0.0
var glow_color: Color = Palette.BRASS


func contains_global(p: Vector2) -> bool:
	return rect.has_point(to_local(p))


func chip_anchor_global() -> Vector2:
	return to_global(chip_anchor)


func set_glow(v: float) -> void:
	glow = v
	queue_redraw()


func _draw() -> void:
	var line := Palette.BONE
	line.a = 0.85
	var fill := Palette.UNDERFELT.lightened(0.04)
	fill.a = 0.0
	if hovered and not locked:
		fill = Palette.BONE
		fill.a = 0.08
	draw_rect(rect, fill)
	if glow > 0.0:
		var g := glow_color
		g.a = glow * 0.35
		draw_rect(rect, g)
	# Painted lines: thick Bone over a darker ink line for the toon look.
	draw_rect(rect.grow(2), Palette.PIT_BLACK.lerp(Palette.UNDERFELT, 0.4), false, 7.0)
	draw_rect(rect, line, false, 3.0)
	match look:
		Look.PASS_LINE:
			_draw_pass()
		Look.FIELD:
			_draw_field()
		Look.HARD_WAY:
			_draw_hard()
		Look.ANY_CRAPS:
			_draw_any_craps()
	if locked:
		var shade := Palette.PIT_BLACK
		shade.a = 0.45
		draw_rect(rect, shade)
		Palette.draw_ink_text(self, rect.get_center() + Vector2(0, rect.size.y * 0.32), "LOCKED: POINT IS ON", 14, Palette.BONE, 5)


func _draw_pass() -> void:
	var c := rect.get_center()
	Palette.draw_ink_text(self, c + Vector2(40, -6), "PASS LINE", 44, Palette.BONE, 10)
	Palette.draw_ink_text(self, c + Vector2(40, 26), "NATURAL  ·  PAYS 1 TO 1", 15, Palette.BRASS, 5)


func _draw_field() -> void:
	var c := rect.get_center()
	Palette.draw_ink_text(self, Vector2(c.x, rect.position.y + 24), "F I E L D", 26, Palette.BONE, 8)
	var nums := ["2", "3", "4", "9", "10", "11", "12"]
	var span := rect.size.x - 190.0
	for i in nums.size():
		var x := rect.position.x + 120.0 + span * i / float(nums.size() - 1)
		var y := rect.position.y + rect.size.y * 0.64
		if nums[i] == "2" or nums[i] == "12":
			draw_circle(Vector2(x, y), 26, Palette.PIT_BLACK)
			draw_circle(Vector2(x, y), 22, Palette.BURGUNDY)
			Palette.draw_ink_text(self, Vector2(x, y + 38), "x2" if nums[i] == "2" else "x3", 15, Palette.EMBER, 5)
		Palette.draw_ink_text(self, Vector2(x, y), nums[i], 28, Palette.BONE, 7)


func _draw_hard() -> void:
	var c := rect.get_center()
	Palette.draw_ink_text(self, Vector2(c.x, rect.position.y + 22), "HARD 8", 22, Palette.BONE, 7)
	# Two little 4-dice.
	for k in 2:
		var center := Vector2(c.x - 24 + 48 * k, c.y + 4)
		var box := Palette.ink_box(Palette.BONE, 6, 3)
		box.draw(get_canvas_item(), Rect2(center - Vector2(17, 17), Vector2(34, 34)))
		for s in [Vector2(-7, -7), Vector2(7, -7), Vector2(-7, 7), Vector2(7, 7)]:
			draw_circle(center + s, 3.5, Palette.PIT_BLACK)
	Palette.draw_ink_text(self, Vector2(c.x, rect.end.y - 18), "9 TO 1", 16, Palette.BRASS, 5)


func _draw_any_craps() -> void:
	var c := rect.get_center()
	Palette.draw_ink_text(self, Vector2(c.x, rect.position.y + 22), "ANY CRAPS", 20, Palette.BONE, 7)
	# The three craps totals in burgundy coins.
	var nums := ["2", "3", "12"]
	for i in nums.size():
		var p := Vector2(c.x - 46 + 46 * i, c.y + 6)
		draw_circle(p, 20, Palette.PIT_BLACK)
		draw_circle(p, 16.5, Palette.BURGUNDY)
		Palette.draw_ink_text(self, p, nums[i], 20, Palette.BONE, 6)
	Palette.draw_ink_text(self, Vector2(c.x + 22, rect.end.y - 18), "7 TO 1", 16, Palette.BRASS, 5)
