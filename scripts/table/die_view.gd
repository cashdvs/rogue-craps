## One plain bone die (poc_feel.md section 2): draws itself and plays the
## tweened throw: wind-up, arc, two bounces, settle on a GIVEN face.
##
## Why tweens and not physics? The rules pick the faces first (DiceRoller,
## seeded), so the animation must land on exactly those faces. Tweens give
## the spec's exact timings and still read as a real throw: fake height
## (scale + shadow), tumbling rotation, face flicks, squash on each bounce.
class_name DieView
extends Node2D

## Emitted on each landing. strength 0..1 (first bounce is the biggest).
signal impact(die: DieView, strength: float)
signal settled(die: DieView)

const SIZE: float = 120.0
const RADIUS: int = 22

## Face currently drawn.
var shown_value: int = 1
## Fake height 0..1 (0 = on the felt).
var h: float = 0.0
## Extra squash/stretch on top of the height scale.
var squash := Vector2.ONE
## 0..1 white outline flash for the reveal punch.
var outline_flash: float = 0.0

var _rng := RandomNumberGenerator.new()
var _flicking: bool = false
var _flick_timer: float = 0.0
var _flick_min: float = 0.045
var _flick_max: float = 0.07
var _squash_frame: bool = false


func set_cosmetic_seed(s: int) -> void:
	_rng.seed = s


func _process(delta: float) -> void:
	if _flicking:
		_flick_timer -= delta
		if _flick_timer <= 0.0:
			_flick()
			_flick_timer = _rng.randf_range(_flick_min, _flick_max)
	queue_redraw()


## Swap to a random different face, squashing X for one frame.
func _flick() -> void:
	var v := _rng.randi_range(1, 5)
	shown_value = v if v < shown_value else v + 1
	_squash_frame = true


## The full throw along a planned path (see ThrowGesture.plan_path): the
## path's inner points are rim hits. Await it: `await die.throw_along(...)`.
## throw_time: arc duration (faster flicks are shorter).
signal wall_hit(die: DieView, at: Vector2)

var _path := PackedVector2Array()
var _cum: Array[float] = []
var _walls_hit: int = 0


func roll_to(final_value: int, origin: Vector2, land: Vector2, t: TuningData, reduced: bool) -> void:
	await throw_along(PackedVector2Array([origin, land]), final_value, t, reduced, t.throw_time)


func throw_along(path: PackedVector2Array, final_value: int, t: TuningData, reduced: bool, throw_time: float) -> void:
	_flick_min = t.flick_min
	_flick_max = t.flick_max
	modulate.a = 1.0
	_set_path(path)
	var total: float = _cum[_cum.size() - 1]
	if reduced:
		await _roll_reduced(final_value, path[0], path[path.size() - 1], t)
		return

	var slide1 := minf(_rng.randf_range(30.0, 60.0), total * 0.25)
	var slide2 := minf(_rng.randf_range(10.0, 20.0), total * 0.1)
	var d_land := total - slide1 - slide2
	var d_b1 := total - slide2
	var dir := (path[1] - path[0]).normalized()

	# Wind-up: shrink a touch and pull back against the flick.
	position = path[0]
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(0.9, 0.9), t.windup_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(self, "position", path[0] - dir * 20.0, t.windup_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tw.finished

	# Throw arc along the path: position eases out, height is a parabola,
	# lots of spin, faces flicking. Rim hits on the way emit wall_hit.
	_flicking = true
	_walls_hit = 0
	var spin := deg_to_rad(_rng.randf_range(540.0, 900.0)) * (1.0 if _rng.randf() < 0.5 else -1.0)
	tw = create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "scale", Vector2.ONE, 0.1)
	tw.tween_method(_travel.bind(0.0, d_land, 1.0), 0.0, 1.0, throw_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "rotation", rotation + spin, throw_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tw.finished

	# Bounce 1: squash, hop to 0.25, slide on.
	_land_squash()
	impact.emit(self, 1.0)
	tw = create_tween()
	tw.set_parallel(true)
	tw.tween_method(_travel.bind(d_land, d_b1, 0.25), 0.0, 1.0, t.bounce1_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "rotation", rotation + spin * 0.15, t.bounce1_time)
	await tw.finished

	# Bounce 2: a small hop.
	_land_squash()
	impact.emit(self, 0.5)
	tw = create_tween()
	tw.tween_method(_travel.bind(d_b1, total, 0.08), 0.0, 1.0, t.bounce2_time).set_trans(Tween.TRANS_QUAD)
	await tw.finished

	# Settle: steer to the predetermined face, snap to a quarter turn + jitter.
	_flicking = false
	shown_value = final_value
	h = 0.0
	impact.emit(self, 0.2)
	var target := roundf(rotation / (PI * 0.5)) * PI * 0.5 + deg_to_rad(_rng.randf_range(-6.0, 6.0))
	tw = create_tween()
	tw.tween_property(self, "rotation", target, t.settle_time).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	await tw.finished
	settled.emit(self)


func _set_path(path: PackedVector2Array) -> void:
	_path = path
	_cum = [0.0]
	for i in range(1, path.size()):
		_cum.append(_cum[i - 1] + path[i - 1].distance_to(path[i]))
	if _cum[_cum.size() - 1] < 1.0:
		_path.append(path[path.size() - 1] + Vector2(1, 0))
		_cum.append(_cum[_cum.size() - 1] + 1.0)


func _point_at(d: float) -> Vector2:
	for i in range(1, _path.size()):
		if d <= _cum[i] or i == _path.size() - 1:
			var seg := maxf(_cum[i] - _cum[i - 1], 0.0001)
			return _path[i - 1].lerp(_path[i], clampf((d - _cum[i - 1]) / seg, 0.0, 1.0))
	return _path[_path.size() - 1]


## Moves along the path from d0 to d1 (progress p) with a hop of `peak`.
func _travel(p: float, d0: float, d1: float, peak: float) -> void:
	var d := lerpf(d0, d1, p)
	position = _point_at(d)
	h = 4.0 * peak * p * (1.0 - p)
	# Rim hits are the inner path points.
	while _walls_hit < _path.size() - 2 and d >= _cum[_walls_hit + 1]:
		_walls_hit += 1
		squash = Vector2(0.85, 1.15)
		wall_hit.emit(self, _path[_walls_hit])
		var tw := create_tween()
		tw.tween_property(self, "squash", Vector2.ONE, 0.06)


## Reduced motion: a straight slide with two face flicks, no arc or bounces.
func _roll_reduced(final_value: int, origin: Vector2, land: Vector2, t: TuningData) -> void:
	position = origin
	var dur := 0.4
	var tw := create_tween()
	tw.tween_property(self, "position", land, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_callback(_flick).set_delay(dur * 0.3)
	tw.parallel().tween_callback(_flick).set_delay(dur * 0.65)
	await tw.finished
	shown_value = final_value
	rotation = 0.0
	impact.emit(self, 0.2)
	settled.emit(self)


func _land_squash() -> void:
	h = 0.0
	squash = Vector2(1.15, 0.85)
	var tw := create_tween()
	tw.tween_property(self, "squash", Vector2.ONE, 0.05)


## Reveal punch: 1.0 -> 1.18 -> 1.0 with a bone outline flash.
func punch(seconds: float) -> void:
	outline_flash = 1.0
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.18, 1.18), seconds * 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", Vector2.ONE, seconds * 0.6).set_trans(Tween.TRANS_BACK)
	tw.parallel().tween_property(self, "outline_flash", 0.0, seconds)


# --- Drawing (poc_feel.md 2) ---------------------------------------------------

func _draw() -> void:
	var half := SIZE * 0.5
	# Drop shadow: offset/alpha/size scale with height. Drawn unrotated in
	# world space would be nicer, but rotating with the die reads fine.
	var sh_off := Vector2(6, 10) * (1.0 + 2.0 * h)
	var sh_scale := 1.0 + 0.3 * h
	var shadow := StyleBoxFlat.new()
	shadow.bg_color = Color(Palette.PIT_BLACK, 0.45 * (1.0 - 0.5 * h))
	shadow.set_corner_radius_all(RADIUS)
	shadow.shadow_color = Color(Palette.PIT_BLACK, 0.25 * (1.0 - 0.5 * h))
	shadow.shadow_size = 8
	draw_set_transform(sh_off.rotated(-rotation), 0.0, Vector2(sh_scale, sh_scale))
	shadow.draw(get_canvas_item(), Rect2(-half, -half, SIZE, SIZE))

	# Body: lifted (bigger) by height, squashed on bounces and flicks.
	var s := (1.0 + 0.35 * h)
	var sq := squash
	if _squash_frame:
		sq.x *= 0.85
		_squash_frame = false
	draw_set_transform(Vector2(0, -h * 30.0).rotated(-rotation), 0.0, Vector2(s * sq.x, s * sq.y))
	var rect := Rect2(-half, -half, SIZE, SIZE)
	var body := Palette.ink_box(Palette.BONE, RADIUS, int(Palette.INK))
	body.draw(get_canvas_item(), rect)
	# Edge shade: bottom and right 10% blended to BONE_SHADE.
	var shade := Color(Palette.BONE_SHADE, 0.85)
	draw_rect(Rect2(-half + 6, half - SIZE * 0.1 - 4, SIZE - 14, SIZE * 0.1), shade)
	draw_rect(Rect2(half - SIZE * 0.1 - 4, -half + 8, SIZE * 0.1, SIZE - 16), shade)
	# 2 px top-left highlight.
	draw_line(Vector2(-half + 14, -half + 6), Vector2(half - 20, -half + 6), Color("#FFF6E0"), 2.0)
	draw_line(Vector2(-half + 6, -half + 14), Vector2(-half + 6, half - 20), Color("#FFF6E0"), 2.0)
	if outline_flash > 0.0:
		var flash := Palette.ink_box(Color(0, 0, 0, 0), RADIUS + 3, 3, Color(Palette.BONE, outline_flash))
		flash.draw(get_canvas_item(), rect.grow(4))
	_draw_pips(shown_value, rect)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_pips(value: int, rect: Rect2) -> void:
	var f: Array[Vector2] = []
	match value:
		1: f = [Vector2(0.5, 0.5)]
		2: f = [Vector2(0.27, 0.27), Vector2(0.73, 0.73)]
		3: f = [Vector2(0.27, 0.27), Vector2(0.5, 0.5), Vector2(0.73, 0.73)]
		4: f = [Vector2(0.27, 0.27), Vector2(0.73, 0.27), Vector2(0.27, 0.73), Vector2(0.73, 0.73)]
		5: f = [Vector2(0.27, 0.27), Vector2(0.73, 0.27), Vector2(0.5, 0.5), Vector2(0.27, 0.73), Vector2(0.73, 0.73)]
		6: f = [Vector2(0.27, 0.27), Vector2(0.73, 0.27), Vector2(0.27, 0.5), Vector2(0.73, 0.5), Vector2(0.27, 0.73), Vector2(0.73, 0.73)]
	var r := SIZE * 0.18 * 0.5
	for p in f:
		var c := rect.position + p * SIZE
		draw_circle(c, r, Palette.PIT_BLACK)
		draw_arc(c, r - 1.5, 0.0, TAU, 20, Palette.BONE_SHADE, 1.0)
