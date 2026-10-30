## Phone landscape (844x390) camera for #204: the home pitch, 1.2x closer (AD)
## than BonfireTuning.cam_phone_landscape_distance, with the pivot slid along
## the felt so the dice rest band sits centred between the Target plate
## (ends at y138 pt) and the phone bottom bar (PhoneBottomBar, 44 pt tall).
class_name PhoneFrame
extends RefCounted

## How much closer than the old whole-felt phone framing (AD: 1.2x).
const CLOSER := 1.2
## Bottom of the Target plate on phone (pt).
const PLATE_BOTTOM_PT := 138.0
## Clear gap kept between the resting dice and the HUD (AD: 24 pt).
const GAP_PT := 24.0
## Screen-edge safe area for the throw zone and pot row (AD: 16 pt).
const EDGE_PT := 16.0
## Dice rest rows kept on phone: settled dice are nudged to |z| <= this
## (the inner rows; the outer rows at z 0.4 fall under the plate / bar).
const REST_Z := 0.16
## Dice rest columns: |x| <= this (the throw zone's width).
const REST_X := 0.8
## Throw zone depth (the felt the dice fly over), |z| <= this.
const THROW_Z := 0.4
## Phone screen height (pt).
const SCREEN_PT := 390.0


## Places the camera; returns the smallest resting die (px).
static func fit_landscape(t: BonfireTableLayout) -> float:
	var rig := t.camera
	rig.fit_viewport(Vector2(t.get_viewport().get_visible_rect().size))
	rig.home_distance = t.bonfire_tuning.cam_phone_landscape_distance / CLOSER
	rig.distance = rig.home_distance
	var pivot: Vector3 = t.bonfire_tuning.cam_phone_landscape_pivot
	var b := band(t)
	pivot = _solve(t, pivot, _mid, (b.x + b.y) * 0.5)
	# The throw zone's near edge must keep the 16 pt safe edge: slide up
	# (if that is the tight side) as far as the rest rows still fit.
	var px_pt := t.get_viewport().get_visible_rect().size.y / SCREEN_PT
	var low := (SCREEN_PT - EDGE_PT) * px_pt
	if _throw_low(t, pivot) > low:
		var room := span_of(rig.cam, rest_zone(t.tuning.die_size)).x - b.x
		pivot = _solve(t, pivot, _throw_low, maxf(low, _throw_low(t, pivot) - room))
	_aim(rig, pivot)
	var smallest := INF
	for s: float in CameraFraming.die_sizes(rig.cam, CameraFraming.rest_spots(t.tuning.die_size), t.tuning.die_size):
		smallest = minf(smallest, s)
	return smallest


## The free band for resting dice, screen px (top, bottom).
static func band(t: BonfireTableLayout) -> Vector2:
	var pt := t.get_viewport().get_visible_rect().size.y / SCREEN_PT
	return Vector2(PLATE_BOTTOM_PT + GAP_PT, SCREEN_PT - PhoneBottomBar.HEIGHT_PT - GAP_PT) * pt


## Screen y span (top, bottom px) of the resting dice, current camera.
## max_z: only rest spots with |z| <= max_z (the inner rows) count.
static func rest_span(t: BonfireTableLayout, max_z: float = INF) -> Vector2:
	var cam := t.camera.cam
	var die := t.tuning.die_size
	var span := Vector2(INF, -INF)
	for p in CameraFraming.rest_spots(die):
		if absf(p.z) > max_z:
			continue
		for dy in [-0.5, 0.5]:
			for dz in [-0.5, 0.5]:
				var y := cam.unproject_position(p + Vector3(0, dy, dz) * die).y
				span = Vector2(minf(span.x, y), maxf(span.y, y))
	return span


## Screen y span (top, bottom px) of felt points, current camera.
static func span_of(cam: Camera3D, pts: Array[Vector3]) -> Vector2:
	var span := Vector2(INF, -INF)
	for p in pts:
		var y := cam.unproject_position(p).y
		span = Vector2(minf(span.x, y), maxf(span.y, y))
	return span


## Nudges settled dice into the kept rows (|z| <= REST_Z), then pushes
## any two that now touch apart along x. Returns true if any die moved.
static func clamp_rest(dice: Array, die: float) -> bool:
	var moved := false
	var lim := REST_Z - die * 0.5
	for d: Node3D in dice:
		var p := d.global_position
		var q := Vector3(clampf(p.x, -REST_X, REST_X), p.y, clampf(p.z, -lim, lim))
		if not q.is_equal_approx(p):
			d.global_position = q
			moved = true
	# A few passes: two dice closer than 1.2 die sizes slide apart on x.
	for pass_i in 8:
		var clean := true
		for i in dice.size():
			for j in range(i + 1, dice.size()):
				var a := (dice[i] as Node3D).global_position
				var b := (dice[j] as Node3D).global_position
				var gap := Vector2(b.x - a.x, b.z - a.z)
				if gap.length() >= die * 1.2:
					continue
				clean = false
				moved = true
				var push := (die * 1.2 - gap.length()) * 0.5 + 0.001
				var sx := 1.0 if gap.x >= 0.0 else -1.0
				(dice[i] as Node3D).global_position.x = clampf(a.x - sx * push, -REST_X, REST_X)
				(dice[j] as Node3D).global_position.x = clampf(b.x + sx * push, -REST_X, REST_X)
		if clean:
			break
	return moved


## Felt points of the rest zone (kept rows) at die height, for tests.
static func rest_zone(die: float) -> Array[Vector3]:
	return _box(REST_X + die * 0.5, REST_Z, die)


## Felt points of the throw zone at die height, for tests.
static func throw_zone(die: float) -> Array[Vector3]:
	return _box(REST_X + die * 0.5, THROW_Z, die)


static func _box(hx: float, hz: float, die: float) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for x in [-hx, 0.0, hx]:
		for z in [-hz, hz]:
			for y in [0.0, die]:
				out.append(Vector3(x, y, z))
	return out


## Secant steps on pivot z until f(t, pivot) is on goal (screen px).
static func _solve(t: BonfireTableLayout, pivot: Vector3, f: Callable, goal: float) -> Vector3:
	for i in 6:
		var a: float = f.call(t, pivot)
		var b2: float = f.call(t, pivot + Vector3(0, 0, 0.05))
		if absf(a - goal) < 1.0 or is_equal_approx(a, b2):
			break
		pivot.z += 0.05 * (goal - a) / (b2 - a)
	return pivot


## Lowest screen y of the throw zone (its near edge), at this pivot.
static func _throw_low(t: BonfireTableLayout, pivot: Vector3) -> float:
	_aim(t.camera, pivot)
	return span_of(t.camera.cam, throw_zone(t.tuning.die_size)).y


static func _mid(t: BonfireTableLayout, pivot: Vector3) -> float:
	_aim(t.camera, pivot)
	var s := span_of(t.camera.cam, rest_zone(t.tuning.die_size))
	return (s.x + s.y) * 0.5


static func _aim(rig: CameraRig, pivot: Vector3) -> void:
	rig.home_pivot = pivot
	rig.position = pivot
	rig._apply()
