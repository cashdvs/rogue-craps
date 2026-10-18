## The Soul meter (poc_feel.md 5): a vertical brass-framed tank of Soul
## Flame, the ONLY cyan on screen. Loss is red: when Soul burns the frame
## shakes, a crack flashes across the fill line, DANGER embers rise, a red
## ghost bar shrinks to the new value and "-N" floats up. No cyan on loss.
## At <= 25% Soul the flame flickers faster, the border tints red and a
## heartbeat signal fires every 1.2 s (the table plays the sound).
class_name SoulMeter
extends Control

signal heartbeat

const FRAME := Vector2(100, 580)
const BORDER: float = 6.0
const INSET: float = 12.0

var soul: int = 40
var soul_max: int = 40
## Particle multiplier (reduced motion uses 0.3) and no-shake flag.
var particle_scale: float = 1.0
var reduced: bool = false

var _ghost_from: float = 40.0
var _ghost: float = 40.0
var _t: float = 0.0
var _shake_t: float = 0.0
var _crack_a: float = 0.0
var _crack_pts := PackedVector2Array()
var _beat_t: float = 0.0
var _pulse: float = 0.0
var _embers: CPUParticles2D
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	custom_minimum_size = FRAME
	size = FRAME
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_embers = CPUParticles2D.new()
	_embers.emitting = false
	_embers.one_shot = true
	_embers.explosiveness = 0.9
	_embers.lifetime = 0.9
	_embers.amount = 10
	_embers.direction = Vector2(0, -1)
	_embers.spread = 50.0
	_embers.gravity = Vector2(0, -120)
	_embers.initial_velocity_min = 60.0
	_embers.initial_velocity_max = 160.0
	_embers.scale_amount_min = 3.0
	_embers.scale_amount_max = 6.0
	_embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_embers.emission_rect_extents = Vector2(36, 4)
	var ramp := Gradient.new()
	ramp.set_color(0, Palette.DANGER)
	ramp.add_point(0.5, Palette.EMBER)
	ramp.set_color(ramp.get_point_count() - 1, Color(Palette.SMOKE, 0.0))
	_embers.color_ramp = ramp
	add_child(_embers)


func setup(current: int, maximum: int) -> void:
	soul = current
	soul_max = maxi(maximum, 1)
	_ghost = current
	_ghost_from = current
	queue_redraw()


func is_low() -> bool:
	return soul > 0 and float(soul) <= float(soul_max) * 0.25


func _fill_rect(value: float) -> Rect2:
	var inner := Rect2(Vector2(INSET, INSET), FRAME - Vector2(INSET, INSET) * 2.0)
	var hgt := inner.size.y * clampf(value / float(soul_max), 0.0, 1.0)
	return Rect2(inner.position.x, inner.end.y - hgt, inner.size.x, hgt)


## Global position of the current fill line (top of the flame).
func fill_top_global() -> Vector2:
	var r := _fill_rect(soul)
	return global_position + Vector2(r.get_center().x, r.position.y)


## Call when Soul is lost. Plays the red drain; returns immediately.
func burn(amount: int, new_soul: int) -> void:
	var old := float(soul)
	soul = new_soul
	_ghost_from = old
	_ghost = old
	_shake_t = 0.0 if reduced else 0.25
	# Crack across the old fill line.
	var y := _fill_rect(old).position.y
	_crack_pts = PackedVector2Array()
	var x := INSET
	while x < FRAME.x - INSET:
		_crack_pts.append(Vector2(x, y + _rng.randf_range(-7.0, 7.0)))
		x += _rng.randf_range(10.0, 18.0)
	_crack_pts.append(Vector2(FRAME.x - INSET, y))
	_crack_a = 1.0
	# Ghost: hold 0.1 s, then shrink over 0.5 s.
	var tw := create_tween()
	tw.tween_interval(0.1)
	tw.tween_property(self, "_ghost", float(new_soul), 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	var tc := create_tween()
	tc.tween_property(self, "_crack_a", 0.0, 0.6)
	# DANGER embers out of the fill line.
	_embers.position = Vector2(FRAME.x * 0.5, y)
	_embers.amount = maxi(1, int(round(10.0 * particle_scale)))
	_embers.restart()
	# Floating "-N".
	var lbl := Label.new()
	lbl.text = "-%d" % amount
	lbl.label_settings = Palette.label_settings(48, Palette.DANGER, 8, true)
	lbl.position = Vector2(FRAME.x + 14, y - 30)
	add_child(lbl)
	var tl := lbl.create_tween()
	tl.set_parallel(true)
	tl.tween_property(lbl, "position:y", lbl.position.y - 40.0, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tl.tween_property(lbl, "modulate:a", 0.0, 0.7).set_delay(0.2)
	tl.chain().tween_callback(lbl.queue_free)


## A small upward fill for Soul healed (not used by the POC, kept honest).
func heal(new_soul: int) -> void:
	soul = new_soul
	_ghost = soul
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	_shake_t = maxf(_shake_t - delta, 0.0)
	_pulse = maxf(_pulse - delta * 3.0, 0.0)
	if is_low():
		_beat_t += delta
		if _beat_t >= 1.2:
			_beat_t = 0.0
			_pulse = 1.0
			heartbeat.emit()
	else:
		_beat_t = 0.0
	queue_redraw()


func _draw() -> void:
	var off := Vector2.ZERO
	if _shake_t > 0.0:
		off = Vector2(_rng.randf_range(-4.0, 4.0), _rng.randf_range(-4.0, 4.0))
	var low := is_low()
	draw_set_transform(off, 0.0, Vector2.ONE)
	var frame := Rect2(Vector2.ZERO, FRAME)
	# Glow behind (pulses on heartbeat).
	if low and _pulse > 0.0:
		draw_style_box(Palette.ink_box(Color(Palette.DANGER, 0.25 * _pulse), 18, 0), frame.grow(10.0 * _pulse))
	var border_col := Palette.BRASS.lerp(Palette.DANGER, 0.7) if low else Palette.BRASS
	draw_style_box(Palette.ink_box(Palette.PIT_BLACK, 16, int(BORDER), border_col), frame)
	draw_rect(frame.grow(2.0), Palette.PIT_BLACK, false, 3.0)

	# Ghost (red) behind the fill.
	if _ghost > float(soul) + 0.01:
		var gr := _fill_rect(_ghost)
		draw_rect(gr, Palette.DANGER)

	# Fill: SOUL_DEEP at the bottom -> SOUL_FLAME at the top, core strip.
	var fr := _fill_rect(soul)
	if fr.size.y > 0.5:
		var bands := 24
		for i in bands:
			var k0 := float(i) / bands
			var y0 := fr.end.y - fr.size.y * float(i + 1) / bands
			var c := Palette.SOUL_DEEP.lerp(Palette.SOUL_FLAME, k0)
			draw_rect(Rect2(fr.position.x, y0, fr.size.x, fr.size.y / bands + 1.0), c)
		draw_rect(Rect2(fr.get_center().x - 6.0, fr.position.y + 6.0, 12.0, fr.size.y - 6.0), Color(Palette.SOUL_CORE, 0.6))
		# Flame top: an animated wavy tongue 18 px tall.
		var hz := 5.0 if low else 2.2
		var pts := PackedVector2Array()
		pts.append(Vector2(fr.position.x, fr.position.y + 1.0))
		var steps := 8
		for i in steps + 1:
			var px := fr.position.x + fr.size.x * float(i) / steps
			var n := sin(_t * TAU * hz + float(i) * 1.7) * 0.5 + sin(_t * TAU * hz * 1.9 + float(i) * 3.1) * 0.5
			var tall := 18.0 * (0.55 + 0.45 * n) * (1.0 - absf(float(i) / steps - 0.5) * 0.8)
			pts.append(Vector2(px, fr.position.y - tall))
		pts.append(Vector2(fr.end.x, fr.position.y + 1.0))
		draw_colored_polygon(pts, Color(Palette.SOUL_FLAME, 0.85))
		draw_rect(Rect2(fr.position.x, fr.position.y - 2.0, fr.size.x, 4.0), Color(Palette.SOUL_CORE, 0.7))

	# Tick marks every 10 Soul.
	var inner_h := FRAME.y - INSET * 2.0
	var ticks := soul_max / 10
	for i in range(1, ticks):
		var ty := FRAME.y - INSET - inner_h * float(i * 10) / soul_max
		draw_line(Vector2(INSET, ty), Vector2(INSET + 14, ty), Color(Palette.BRASS, 0.7), 2.0)

	if _crack_a > 0.0 and _crack_pts.size() > 1:
		draw_polyline(_crack_pts, Color(Palette.DANGER, _crack_a), 4.0)
		draw_polyline(_crack_pts, Color(Palette.BURGUNDY, _crack_a), 1.5)

	# Value above, label below.
	var vc := Palette.DANGER if low else Palette.SOUL_FLAME
	Palette.draw_ink_text(self, Vector2(FRAME.x * 0.5, -34), str(soul), 48, vc, 8, true)
	Palette.draw_ink_text(self, Vector2(FRAME.x * 0.5, FRAME.y + 30), "SOUL", 30, Palette.BONE, 6, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
