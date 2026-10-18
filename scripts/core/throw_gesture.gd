## Turns a mouse drag into a throw (Cash: grab the dice, drag, flick).
##
## Pure logic so it can be tested without a mouse: feed it press / move /
## release samples with timestamps, and it reports the release velocity and
## whether that counts as a throw. A plain click, a tiny nudge, or a slow
## let-go is NOT a throw: the dice drop back into the hand.
class_name ThrowGesture
extends RefCounted

var tuning: TuningData
var active: bool = false
var grab_point := Vector2.ZERO
var last_point := Vector2.ZERO
var _samples: Array[Vector3] = []  # x, y, time


func _init(tuning_data: TuningData) -> void:
	tuning = tuning_data


func press(p: Vector2, time_s: float) -> void:
	active = true
	grab_point = p
	last_point = p
	_samples.clear()
	_samples.append(Vector3(p.x, p.y, time_s))


func move(p: Vector2, time_s: float) -> void:
	if not active:
		return
	last_point = p
	_samples.append(Vector3(p.x, p.y, time_s))
	# Keep only what the velocity window needs (plus one older sample).
	while _samples.size() > 2 and time_s - _samples[1].z > tuning.throw_sample_window:
		_samples.pop_front()


## Ends the drag. Returns the release velocity (px/s); ZERO if not dragging.
func release(p: Vector2, time_s: float) -> Vector2:
	if not active:
		return Vector2.ZERO
	move(p, time_s)
	active = false
	return velocity_at(time_s)


## Average velocity over the last throw_sample_window seconds.
func velocity_at(time_s: float) -> Vector2:
	if _samples.size() < 2:
		return Vector2.ZERO
	var newest := _samples[_samples.size() - 1]
	var oldest := _samples[0]
	for s in _samples:
		if time_s - s.z <= tuning.throw_sample_window:
			oldest = s
			break
	var dt := newest.z - oldest.z
	if dt <= 0.0001:
		return Vector2.ZERO
	return Vector2(newest.x - oldest.x, newest.y - oldest.y) / dt


func drag_distance() -> float:
	return grab_point.distance_to(last_point)


## The threshold rule: fast enough AND moved far enough.
static func is_throw(velocity: Vector2, drag: float, t: TuningData) -> bool:
	return velocity.length() >= t.min_throw_speed and drag >= t.min_throw_drag


## Plans where a throw goes: travels along the flick, reflects off the felt
## edge (the rim) and comes to rest inside `rest_rect`. Returns the path
## [start, (wall hit)..., rest]. Deterministic for a given velocity.
static func plan_path(start: Vector2, velocity: Vector2, bounds: Rect2, rest_rect: Rect2, t: TuningData) -> PackedVector2Array:
	var path := PackedVector2Array([start])
	var speed := clampf(velocity.length(), t.min_throw_speed, t.max_throw_speed)
	if velocity.length() < 0.001:
		path.append(rest_rect.get_center())
		return path
	var dir := velocity.normalized()
	var remaining := speed * t.throw_distance_per_speed
	# The hand sits on the rim outside the felt: start from the nearest felt point.
	var p := Vector2(clampf(start.x, bounds.position.x + 1.0, bounds.end.x - 1.0), clampf(start.y, bounds.position.y + 1.0, bounds.end.y - 1.0))
	# Up to 2 rim bounces.
	for i in 3:
		var hit := _ray_exit(p, dir, bounds)
		var to_wall := p.distance_to(hit.position) if hit.size.x >= 0.0 else INF
		if to_wall >= remaining or hit.size.x < 0.0:
			p += dir * remaining
			break
		p = hit.position
		path.append(p)
		remaining = (remaining - to_wall) * t.rim_restitution
		dir = dir.bounce(_wall_normal(p, bounds)).normalized()
	var rest := Vector2(clampf(p.x, rest_rect.position.x, rest_rect.end.x), clampf(p.y, rest_rect.position.y, rest_rect.end.y))
	if path[path.size() - 1].distance_to(rest) > 1.0:
		path.append(rest)
	return path


## Where a ray from p (inside or outside) along dir leaves `r`. Rect2 is used
## as a tiny struct: position = hit point, size.x = -1 when there is no hit.
static func _ray_exit(p: Vector2, dir: Vector2, r: Rect2) -> Rect2:
	var best := INF
	if dir.x > 0.0001:
		best = minf(best, (r.end.x - p.x) / dir.x)
	elif dir.x < -0.0001:
		best = minf(best, (r.position.x - p.x) / dir.x)
	if dir.y > 0.0001:
		best = minf(best, (r.end.y - p.y) / dir.y)
	elif dir.y < -0.0001:
		best = minf(best, (r.position.y - p.y) / dir.y)
	if best == INF or best < 0.0:
		return Rect2(Vector2.ZERO, Vector2(-1, 0))
	return Rect2(p + dir * best, Vector2(1, 0))


static func _wall_normal(p: Vector2, r: Rect2) -> Vector2:
	var d := [absf(p.x - r.position.x), absf(r.end.x - p.x), absf(p.y - r.position.y), absf(r.end.y - p.y)]
	var normals: Array[Vector2] = [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP]
	var best := 0
	for i in range(1, 4):
		if d[i] < d[best]:
			best = i
	return normals[best]
