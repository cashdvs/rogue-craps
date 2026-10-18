## The bare bulb hanging over the table on a cord. It sways a little and
## flickers; the table reads `flicker` to drive the light shaders.
class_name BulbView
extends Node2D

var anchor := Vector2(640, -10)
var length: float = 46.0
var flicker: float = 1.0
var _t: float = 0.0
var _rng := RandomNumberGenerator.new()
var _dip: float = 0.0


func _process(delta: float) -> void:
	_t += delta
	# Occasional brief dips, like a bad filament.
	if _rng.randf() < delta * 0.35:
		_dip = _rng.randf_range(0.25, 0.5)
	_dip = maxf(_dip - delta * 2.5, 0.0)
	flicker = 1.0 - _dip + sin(_t * 23.0) * 0.015
	var sway := sin(_t * 0.9) * 0.05
	position = anchor + Vector2(sin(sway) * length, cos(sway) * length)
	rotation = -sway
	queue_redraw()


func _draw() -> void:
	# Cord back up to the anchor (in local space the anchor is "up").
	draw_line(Vector2.ZERO, Vector2(0, -length - 20), Palette.PIT_BLACK, 4.0)
	# Socket.
	var sock := Palette.ink_box(Palette.BRASS.darkened(0.3), 4, 3)
	sock.draw(get_canvas_item(), Rect2(-9, -14, 18, 16))
	# Glow halo + bulb glass.
	var g := Color(1.0, 0.8, 0.45, 0.25 * flicker)
	draw_circle(Vector2(0, 12), 34, g)
	draw_circle(Vector2(0, 12), 15, Palette.PIT_BLACK)
	draw_circle(Vector2(0, 12), 12, Color(1.0, 0.93, 0.7).lerp(Palette.EMBER, 1.0 - flicker))
	draw_line(Vector2(-4, 8), Vector2(4, 16), Palette.EMBER, 2.0)
