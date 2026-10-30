## DiceSim's bodies and their shapes (d6 box, coin hull, PolyDie hulls),
## the per-body state, and the odd-die felt rules (coin edge rule, hull
## rolling resistance, cocked-die nudge). DiceSim extends this; split out
## only to keep each file short (no behaviour of its own).
class_name DiceSimBodies
extends Node3D

signal finished(rec: ThrowRecording)

var tuning: TuningData
var bodies: Array[RigidBody3D] = []
var running: bool = false

var _rec: ThrowRecording
var _t: float = 0.0
## Physics frames in a row with every die still (DiceSim.rest_frames()).
var _rest_frames: int = 0
# Previous tick's velocities (pre-impact) for relative contact speed.
var _prev_lin: Array[Vector3] = []
var _prev_ang: Array[Vector3] = []
# Contacts touching last tick, per die: "collider_id:shape" keys.
var _touching: Array[Dictionary] = []
var _rest_since: Array[float] = []
var _spun_up: Array[bool] = []
var _saved_ticks: int = 60
var _saved_scale: float = 1.0
var _saved_steps: int = 8
var _rng := RandomNumberGenerator.new()
var _mat: PhysicsMaterial
## Dice in the current throw (bodies past this stay parked and frozen).
var active: int = 0
## Shape per body (&"d6" box or &"coin" barrelled convex hull, see CoinPhysics); set
## with set_body_shapes() before simulate().
var shapes: Array[StringName] = []
## Coin edge rule (_coin_on_felt): how long a slow coin may stand on its rim
## or lean before it's tipped, and how many tips per throw.
const COIN_STUCK_TIME: float = 0.05
const COIN_MAX_NUDGES: int = 8
var _coin_stuck: Array[float] = []
var _coin_nudges: Array[int] = []


## Tests only: after a natural settle keep the dice live this many seconds
## and record their speeds (ThrowRecording.post_rest_*), to catch jitter. The
## rest time stamps are unchanged. 0 = off (the game).
var post_rest_watch: float = 0.0
var _watch_t: float = -1.0
var _watch_moving: Array[bool] = []
## Per body: last tick's spin (rad/s), for the hull dice's creep check.
var _poly_prev_w: Array[float] = []
## Slowest spin of each hull die since it last came to rest (creep check).
var _poly_min_w: Array[float] = []


func setup(t: TuningData, count: int = 2) -> void:
	tuning = t
	_mat = PhysicsMaterial.new()
	_mat.friction = t.die_friction
	_mat.bounce = t.die_bounce
	ensure_bodies(count)


## Makes sure there are at least `n` die bodies (added on demand, never removed).
func ensure_bodies(n: int) -> void:
	while bodies.size() < n:
		var i := bodies.size()
		var b := RigidBody3D.new()
		b.name = "DieBody%d" % i
		b.mass = tuning.die_mass
		b.physics_material_override = _mat
		b.linear_damp = tuning.die_linear_damp
		b.angular_damp = tuning.die_angular_damp
		b.gravity_scale = tuning.die_gravity_scale
		b.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
		b.angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
		b.continuous_cd = true
		b.contact_monitor = true
		b.max_contacts_reported = 16
		b.can_sleep = false
		b.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
		b.freeze = true
		b.position = Vector3(i * 0.2, -1.0, 0.0)  # parked under the table
		b.set_meta("die_index", i)
		var cs := CollisionShape3D.new()
		cs.name = "Shape"
		cs.shape = _box_shape()
		b.add_child(cs)
		add_child(b)
		bodies.append(b)
		shapes.append(&"d6")
		_prev_lin.append(Vector3.ZERO)
		_prev_ang.append(Vector3.ZERO)
		_touching.append({})
		_rest_since.append(-1.0)
		_spun_up.append(false)
		_coin_stuck.append(0.0)
		_coin_nudges.append(0)
		_poly_prev_w.append(0.0)
		_poly_min_w.append(INF)


func _box_shape() -> BoxShape3D:
	var box := BoxShape3D.new()
	box.size = Vector3.ONE * tuning.die_size
	return box


## Gives body i the collider and mass of its die's shape: a coin is a thin
## ConvexPolygonShape3D (CoinPhysics.hull_points, 72 points) at half a d6's mass; any
## other shape is the d6 box (the table has no other meshes yet). Bodies
## past the list keep their shape.
func set_body_shapes(list: Array) -> void:
	ensure_bodies(list.size())
	for i in list.size():
		var want := StringName(list[i])
		if want != &"coin" and not PolyDie.has_shape(want):
			want = &"d6"
		if shapes[i] == want:
			continue
		shapes[i] = want
		var cs := bodies[i].get_node("Shape") as CollisionShape3D
		if want == &"coin":
			cs.shape = CoinPhysics.make_shape()
		elif want == &"d6":
			cs.shape = _box_shape()
		else:
			# PM ruling: a hull of the die's mobile mesh, d6 mass.
			cs.shape = PolyDie.make_shape(want)
		bodies[i].mass = tuning.die_mass * (CoinPhysics.MASS_FACTOR if want == &"coin" else 1.0)


func is_coin(i: int) -> bool:
	return i >= 0 and i < shapes.size() and shapes[i] == &"coin"


## Body i is a hull die with its own face table (PolyDie: d4, d8, ...).
func is_poly(i: int) -> bool:
	return i >= 0 and i < shapes.size() and PolyDie.has_shape(shapes[i])


## Tilt off clean rest (deg) of body i in pose b: the coin off flat, a hull
## die its up slot off vertical, a cube 0 (not tracked).
func rest_tilt(i: int, b: Basis) -> float:
	if is_coin(i):
		return CoinPhysics.tilt_deg(b)
	if is_poly(i):
		return PolyDie.tilt_deg(shapes[i], b)
	return 0.0


## Height of body i's centre when it lies flat on the felt.
func rest_height(i: int) -> float:
	return CoinPhysics.THICKNESS * 0.5 if is_coin(i) else tuning.die_size * 0.5


## Radius of body i's footprint on the felt (for pushing flattened dice apart).
func footprint(i: int) -> float:
	if is_poly(i):
		return PolyDie.radius(shapes[i]) * 0.85
	return CoinPhysics.RADIUS if is_coin(i) else tuning.die_size * 0.5

## A die resting tilted (on the rail, or on the other die) gets a small
## push: up, toward the table center, with a tip-over spin. Returns true if
## any die was nudged.
func _nudge_cocked() -> bool:
	if _rec.nudges >= 8:
		return false
	var any := false
	for i in active:
		var b := bodies[i]
		var basis := b.global_transform.basis.orthonormalized()
		if is_coin(i):
			if _nudge_coin(i):
				any = true
			continue
		var d := 0.0
		var too_high := false
		if is_poly(i):
			# Resting on an edge or point (or on another die): tip it over.
			d = cos(deg_to_rad(PolyDie.tilt_deg(shapes[i], basis)))
			too_high = b.global_position.y > PolyDie.rest_height(shapes[i], PolyDie.flat_basis(shapes[i], basis)) + tuning.die_size * 0.12
		else:
			var up := DieVisual.value_up(basis)
			d = (basis * (DieVisual.FACE_AXES[up] as Vector3)).dot(Vector3.UP)
			too_high = b.global_position.y > tuning.die_size * 0.62
		if d < tuning.sim_cocked_dot or too_high:
			var to_center := Vector3(-b.global_position.x, 0.0, -b.global_position.z).normalized()
			b.linear_velocity = Vector3(0, 0.35, 0) + to_center * 0.25
			var axis := Vector3.UP.cross(to_center).normalized()
			if axis == Vector3.ZERO:
				axis = Vector3.RIGHT
			b.angular_velocity = axis.rotated(Vector3.UP, _rng.randf_range(-0.6, 0.6)) * _rng.randf_range(6.0, 9.0)
			_rec.nudges += 1
			any = true
	return any


## The coin edge rule, checked every tick (not only once everything has
## stopped, since the settle assist can start first):
##  - Felt is soft: a coin rolling on its rim like a wheel loses that roll
##    fast (rolling resistance; Jolt has none). Only the spin about the
##    coin's own normal is damped, and only while it is low and steep on the
##    felt, so the end-over-end flip in the air is untouched.
##  - A coin that is nearly still but standing on its rim (or leaning on a
##    die / rail) for COIN_STUCK_TIME gets the tip-over nudge (_nudge_coin),
##    at most COIN_MAX_NUDGES times per throw.
func _coin_on_felt(i: int, dt: float) -> void:
	var b := bodies[i]
	var basis := b.global_transform.basis.orthonormalized()
	var tilt := CoinPhysics.tilt_deg(basis)
	if b.global_position.y <= CoinPhysics.RADIUS + 0.01 and tilt >= 45.0:
		var n := basis * Vector3.UP
		var roll := n * b.angular_velocity.dot(n)
		b.angular_velocity -= roll * clampf(CoinPhysics.FELT_ROLL_DAMP * dt, 0.0, 1.0)
	# "Stuck": nearly still; on its rim, also slowly rolling / rocking there.
	var slow := b.linear_velocity.length() < 0.12 and b.angular_velocity.length() < 2.0
	if CoinPhysics.is_on_edge(basis) and b.global_position.y <= CoinPhysics.RADIUS + 0.01:
		slow = b.linear_velocity.length() < 0.35 and b.angular_velocity.length() < 7.0
	if tilt > CoinPhysics.COCKED_DEG and slow:
		_coin_stuck[i] += dt
	else:
		_coin_stuck[i] = 0.0
	if _coin_stuck[i] >= COIN_STUCK_TIME and _coin_nudges[i] < COIN_MAX_NUDGES:
		_coin_stuck[i] = 0.0
		_coin_nudges[i] += 1
		_nudge_coin(i)


## A coin at rest must lie flat on the felt. Standing on its edge (within
## CoinPhysics.EDGE_DEG of vertical), leaning on a die / rail (more than
## COCKED_DEG off flat) or lying on top of a die, it gets a tip-over nudge:
## a little hop plus a spin about the horizontal axis that topples it
## (random direction, so the nudge doesn't pick the face). Returns true if
## nudged.
func _nudge_coin(i: int) -> bool:
	var b := bodies[i]
	var basis := b.global_transform.basis.orthonormalized()
	var tilt := CoinPhysics.tilt_deg(basis)
	var too_high := b.global_position.y > rest_height(i) + 0.02
	if tilt <= CoinPhysics.COCKED_DEG and not too_high:
		return false
	if CoinPhysics.is_on_edge(basis):
		_rec.edge_nudges += 1
	var n := basis * Vector3.UP
	# Topple axis: horizontal, at right angles to the face normal's lean.
	var lean := Vector3(n.x, 0.0, n.z)
	var axis := Vector3.UP.cross(lean.normalized()) if lean.length() > 0.001 else Vector3.RIGHT
	var to_center := Vector3(-b.global_position.x, 0.0, -b.global_position.z).normalized()
	var on_felt := CoinPhysics.is_on_edge(basis) and b.global_position.y <= CoinPhysics.RADIUS + 0.01
	# Which way to tip: toward the NEARER face (the way it already leans,
	# 3D Artist's ruling); a coin flip only when it stands dead upright
	# (within half a degree), so the nudge never picks the face itself.
	var sgn := 1.0 if _rng.randf() < 0.5 else -1.0
	if absf(n.y) > sin(deg_to_rad(0.5)):
		var ahead := n + axis.cross(n) * 0.01
		sgn = 1.0 if absf(ahead.dot(Vector3.UP)) > absf(n.dot(Vector3.UP)) else -1.0
	var w := axis * sgn * _rng.randf_range(9.0, 12.0)
	b.angular_velocity = w
	if on_felt:
		# Tip about the rim where it touches the felt (the contact point
		# stays put), firmly enough to pass the rim's balance point (~14 deg
		# for a 0.024 m thick coin). Spinning it about its centre instead
		# just scrubs the rim on the felt and it stands back up.
		b.linear_velocity = w.cross(Vector3(0, b.global_position.y, 0))
	else:
		# Leaning on a die / rail, or on top of one: a small hop toward the
		# middle too, so it comes away from what holds it up.
		b.linear_velocity = Vector3(0, 0.4, 0) + to_center * 0.15
	_rec.nudges += 1
	return true


## Felt rolling resistance for hull dice (Jolt has none): a die low on the
## felt and nearly stopped loses its slow rocking spin, so a rounded die (the
## Knucklebone's curved sides) doesn't rock on after it seemed at rest and
## start moving again (jitter). Fast tumbling and flight are untouched.
func _poly_on_felt(i: int, dt: float) -> void:
	var b := bodies[i]
	if b.angular_velocity.length() > PolyDie.ROLL_DAMP_MAX_SPIN or b.linear_velocity.length() > 0.3:
		return
	var low := PolyDie.rest_height(shapes[i], PolyDie.flat_basis(shapes[i], b.global_transform.basis)) + 0.01
	if b.global_position.y <= low:
		b.angular_velocity *= maxf(1.0 - PolyDie.FELT_ROLL_DAMP * dt, 0.0)
