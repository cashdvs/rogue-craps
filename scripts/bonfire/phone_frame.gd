## Phone landscape (844x390) camera for #204: the home pitch, 1.41x closer
## than BonfireTuning.cam_phone_landscape_distance, with the pivot slid along
## the felt so the dice rest band sits centred between the Target plate
## (ends at y138 pt) and the phone bottom bar (PhoneBottomBar, 44 pt tall).
class_name PhoneFrame
extends RefCounted

## How much closer than the old whole-felt phone framing (AD: 1.41x).
const CLOSER := 1.41
## Bottom of the Target plate on phone (pt).
const PLATE_BOTTOM_PT := 138.0
## Clear gap kept above and below the resting dice (pt).
const GAP_PT := 8.0
## Phone screen height (pt).
const SCREEN_PT := 390.0


## Places the camera; returns the smallest resting die (px).
static func fit_landscape(t: BonfireTableLayout) -> float:
	var rig := t.camera
	rig.fit_viewport(Vector2(t.get_viewport().get_visible_rect().size))
	rig.home_distance = t.bonfire_tuning.cam_phone_landscape_distance / CLOSER
	rig.distance = rig.home_distance
	var pivot: Vector3 = t.bonfire_tuning.cam_phone_landscape_pivot
	var goal := (band(t).x + band(t).y) * 0.5
	# Secant steps on pivot z until the rest band's middle is on the goal.
	for i in 6:
		var a := _mid(t, pivot)
		var b := _mid(t, pivot + Vector3(0, 0, 0.05))
		if absf(a - goal) < 1.0 or is_equal_approx(a, b):
			break
		pivot.z += 0.05 * (goal - a) / (b - a)
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


static func _mid(t: BonfireTableLayout, pivot: Vector3) -> float:
	_aim(t.camera, pivot)
	var s := rest_span(t)
	return (s.x + s.y) * 0.5


static func _aim(rig: CameraRig, pivot: Vector3) -> void:
	rig.home_pivot = pivot
	rig.position = pivot
	rig._apply()
