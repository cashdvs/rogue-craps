## The angled overhead camera (poc_3d.md section 1): a pivot on the felt and
## a Camera3D pulled back along the pitch. Supports the reveal follow/zoom,
## a seven-out roll tilt, and trauma-based shake applied to h/v offset plus
## a small roll (the pivot itself never moves for shake).
##
## fit_viewport() also handles phone-shaped windows: portrait turns the view
## 90 degrees (the table's long side runs up the screen) and any window where
## a die would render under tuning.min_die_px moves the camera closer.
class_name CameraRig
extends Node3D

var cam: Camera3D
var tuning: TuningData
var reduced_motion: bool = false
var pitch_deg: float = 55.0
var yaw_deg: float = 0.0
var distance: float = 2.5
var home_distance: float = 2.5
var home_pivot := Vector3.ZERO
var tilt_deg: float = 0.0
## Lens tilt above the pivot (degrees, TuningData.cam_look_up_deg).
var look_up_deg: float = 0.0

var _trauma: float = 0.0
var _max_px: float = 0.0
var _t: float = 0.0
var _noise := FastNoiseLite.new()


func setup(t: TuningData) -> void:
	tuning = t
	cam = Camera3D.new()
	cam.name = "Camera3D"
	cam.fov = t.cam_fov
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.near = 0.1
	cam.far = 20.0
	cam.current = true
	add_child(cam)
	_noise.frequency = 1.0
	_noise.seed = 18
	pitch_deg = t.cam_pitch_deg
	look_up_deg = t.cam_look_up_deg
	home_distance = t.cam_distance
	distance = home_distance
	home_pivot = t.cam_pivot
	position = home_pivot
	_apply()


## Frames the table for a window size; returns the chosen distance.
## Desktop 16:9 keeps the spec's numbers. Portrait: yaw 90, pitch 60, FOV 40,
## 3.2 m (spec "Portrait (later)"). Then, if a die at rest would be smaller
## than min_die_px, the camera dollies in until it is not (phones).
func fit_viewport(size: Vector2) -> float:
	var portrait := size.y > size.x
	yaw_deg = 90.0 if portrait else 0.0
	pitch_deg = 60.0 if portrait else tuning.cam_pitch_deg
	look_up_deg = 0.0 if portrait else tuning.cam_look_up_deg
	cam.fov = 40.0 if portrait else tuning.cam_fov
	home_distance = 3.2 if portrait else tuning.cam_distance
	# Die size in px ~ edge * height_px / (2 * d * tan(fov / 2)) at the pivot.
	var k := tuning.die_size * size.y / (2.0 * tan(deg_to_rad(cam.fov) * 0.5))
	var max_d := k / (tuning.min_die_px * 1.05)  # small margin for dice off-center
	home_distance = minf(home_distance, max_d)
	distance = home_distance
	_apply()
	return home_distance


## Phones: dolly in until a die at every on-screen rest spot is >= min_die_px,
## and slide the view between the landing zone and the hand until both
## `must_see` points are on screen. Returns the smallest die size (px).
func fit_dice(size: Vector2, zone: Vector3, hand: Vector3, spots: Array[Vector3], must_see: Array[Vector3]) -> float:
	var best := 0.0
	for step in 11:
		fit_viewport(size)
		var focus := zone.lerp(hand, float(step) / 10.0)
		focus.y = 0.0
		home_pivot = focus
		position = focus
		best = _dolly_for_dice(size, spots)
		var all_seen := true
		for p in must_see:
			if not Rect2(Vector2.ZERO, size).has_point(cam.unproject_position(p)):
				all_seen = false
		if all_seen:
			break
	return best


func _dolly_for_dice(size: Vector2, spots: Array[Vector3]) -> float:
	var smallest := 0.0
	for it in 60:
		_apply()
		smallest = INF
		for p in spots:
			if cam.is_position_behind(p) or not Rect2(Vector2.ZERO, size).has_point(cam.unproject_position(p)):
				continue
			var px := DieVisual.projected_size(cam, Transform3D(Basis.IDENTITY, p), tuning.die_size)
			smallest = minf(smallest, minf(px.x, px.y))
		if smallest >= tuning.min_die_px * 1.02 or distance < 0.6:
			break
		distance *= 0.97
	home_distance = distance
	return smallest


## Trauma shake. `px` is the 2D game's shake size in pixels; it maps to
## metres of h/v offset and degrees of roll via tuning, capped.
func shake(px: float, seconds: float) -> void:
	if reduced_motion:
		px *= 0.3
	if px > _max_px or _trauma <= 0.0:
		_max_px = px
	_trauma = maxf(_trauma, maxf(seconds, 0.01))


## Reveal: glide the pivot toward the dice (clamped) and dolly in a little.
func follow(target: Vector3, seconds: float) -> void:
	var c := tuning.cam_follow_clamp
	var p := Vector3(clampf(target.x, -c, c), 0.0, clampf(target.z, -c, c) + home_pivot.z)
	if reduced_motion:
		p = home_pivot
	var close := minf(tuning.cam_reveal_distance, home_distance) if not reduced_motion else home_distance
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "position", p, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "distance", close, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## Back to the home framing.
func go_home(seconds: float) -> void:
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "position", home_pivot, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(self, "distance", home_distance, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(self, "tilt_deg", 0.0, seconds)


func snap_home() -> void:
	position = home_pivot
	distance = home_distance
	tilt_deg = 0.0
	_trauma = 0.0
	_apply()


## Seven-out: the world tilts a few degrees (eases back on go_home).
func roll_tilt(deg: float, seconds: float) -> void:
	if reduced_motion:
		return
	create_tween().tween_property(self, "tilt_deg", deg, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	_t += delta
	_trauma = maxf(_trauma - delta, 0.0)
	_apply()


## Places the camera: rotate the rig, pull the camera back along its local
## +Z by `distance`, then add shake as h/v offset and roll.
func _apply() -> void:
	rotation_degrees = Vector3(-pitch_deg, yaw_deg, 0.0)
	cam.position = Vector3(0, 0, distance)
	var roll := tilt_deg
	cam.h_offset = 0.0
	cam.v_offset = 0.0
	if _trauma > 0.0 and _max_px > 0.0:
		var m := minf(_max_px * tuning.shake_m_per_px, tuning.shake_cap_m)
		var k := clampf(_trauma * 6.0, 0.0, 1.0)
		cam.h_offset = _noise.get_noise_2d(_t * 40.0, 0.0) * m * k
		cam.v_offset = _noise.get_noise_2d(0.0, _t * 40.0) * m * k
		roll += _noise.get_noise_2d(_t * 30.0, 50.0) * _max_px * tuning.shake_deg_per_px * k
	cam.rotation_degrees = Vector3(look_up_deg, 0, roll)
