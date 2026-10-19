## The REAL physics for a throw: N invisible RigidBody3D dice (1 or more) that bounce
## off the table's rails and felt (Table3DBuilder adds those colliders).
##
## How the seeded result and live physics fit together (Cash's override of
## poc_3d.md's "bake 256 throws"):
##   1. At release, the director asks the seeded DiceRoller for the faces.
##   2. simulate() throws these bodies with the flick's velocity and spin,
##      with the physics clock sped up (tuning.sim_warp) so the whole throw is
##      computed during the 0.12 s wind-up. Every tick is recorded.
##   3. The recording says which face each body ended on. The visible die's
##      inner faces node is turned (DieVisual.remap_basis) so the wanted face
##      sits where that physical top face is. It is set before playback, so
##      it never shows: you see the true physical tumble, with the right face up.
##   4. The director plays the recording back at normal speed.
## If a die comes to rest cocked against a rail, a small nudge (part of the
## recorded physics) tips it flat.
## Timing (design doc 5b): a die still moving at tuning.assist_start after
## release is eased smoothly flat (the "settle assist"; no snap), so the
## reveal always completes by tuning.reveal_cap.
class_name DiceSim
extends Node3D

signal finished(rec: ThrowRecording)

var tuning: TuningData
var bodies: Array[RigidBody3D] = []
var running: bool = false

var _rec: ThrowRecording
var _t: float = 0.0
var _rest_t: float = 0.0
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


## Throws one die per entry of `starts` (1 or more) with the given velocities
## and spins; other bodies stay parked.
## Returns (via `finished` and as the awaited value) the full recording.
func simulate(starts: Array[Transform3D], lin: Array[Vector3], ang: Array[Vector3], nudge_seed: int = 0) -> ThrowRecording:
	active = starts.size()
	ensure_bodies(active)
	_rec = ThrowRecording.new()
	_rec.init(active)
	_rec.dt = 1.0 / float(tuning.physics_hz)
	_rng.seed = nudge_seed
	_t = 0.0
	_rest_t = 0.0
	_watch_t = -1.0
	for i in active:
		var b := bodies[i]
		b.linear_damp = tuning.die_linear_damp
		b.angular_damp = tuning.die_angular_damp
		b.global_transform = starts[i]
		b.freeze = false
		b.linear_velocity = lin[i]
		b.angular_velocity = ang[i]
		b.sleeping = false
		_prev_lin[i] = lin[i]
		_prev_ang[i] = ang[i]
		_touching[i] = {}
		_rest_since[i] = -1.0
		_spun_up[i] = false
		_coin_stuck[i] = 0.0
		_coin_nudges[i] = 0
		_poly_prev_w[i] = ang[i].length()
		_poly_min_w[i] = INF
	# Bodies not in this throw go back under the table. Left frozen where
	# the last throw ended, they were invisible obstacles on the felt (on a
	# rethrow, the potted dice's old landing spots).
	for i in range(active, bodies.size()):
		bodies[i].freeze = true
		bodies[i].global_transform = Transform3D(Basis.IDENTITY, Vector3(i * 0.2, -1.0, 0.0))
	# Speed the physics clock up: W times more ticks per second, each still
	# 1/physics_hz long (time_scale stretches the step, ticks shrink it back).
	_saved_ticks = Engine.physics_ticks_per_second
	_saved_scale = Engine.time_scale
	_saved_steps = Engine.max_physics_steps_per_frame
	var w := maxf(tuning.sim_warp, 1.0)
	Engine.physics_ticks_per_second = int(tuning.physics_hz * w)
	Engine.time_scale = w
	Engine.max_physics_steps_per_frame = maxi(int(tuning.physics_hz * w / 40.0), 8)
	running = true
	var rec: ThrowRecording = await finished
	return rec


func _physics_process(_delta: float) -> void:
	if not running:
		return
	var dt := _rec.dt
	for i in active:
		(_rec.frames[i] as Array).append(bodies[i].global_transform)
	_scan_contacts()
	_t += dt
	# After a while, damp hard so every throw ends.
	if _t >= tuning.sim_damp_after:
		for i in active:
			var b := bodies[i]
			b.linear_damp = tuning.die_linear_damp * 3.0
			b.angular_damp = tuning.die_angular_damp * 3.0
	if _watch_t >= 0.0:
		# Test-only watch after a natural settle (post_rest_watch): the dice
		# stay live; record the largest speeds and any restart (jitter).
		_watch_t += dt
		for i in active:
			var bw := bodies[i]
			# Same felt as during the throw (roll damping keeps acting).
			if is_coin(i):
				_coin_on_felt(i, dt)
			elif is_poly(i):
				_poly_on_felt(i, dt)
			_rec.post_rest_max_lin[i] = maxf(_rec.post_rest_max_lin[i], bw.linear_velocity.length())
			_rec.post_rest_max_ang[i] = maxf(_rec.post_rest_max_ang[i], bw.angular_velocity.length())
			var moving_now := bw.linear_velocity.length() > tuning.sim_rest_linear or bw.angular_velocity.length() > tuning.sim_rest_angular
			if moving_now and not _watch_moving[i]:
				_rec.post_rest_restarts[i] += 1
			_watch_moving[i] = moving_now
		if _watch_t >= post_rest_watch:
			_finish()
		return
	# Settle assist: anything still moving now gets eased onto its face.
	if _t >= assist_time():
		_assist()
		return
	for i in active:
		if is_coin(i):
			_coin_on_felt(i, dt)
		elif is_poly(i):
			_poly_on_felt(i, dt)
	var at_rest := true
	for i in active:
		var b := bodies[i]
		var still := b.linear_velocity.length() <= tuning.sim_rest_linear and b.angular_velocity.length() <= tuning.sim_rest_angular
		if still and is_poly(i):
			# A hull die balanced just off a face can creep over slowly (spin
			# under the rest threshold but growing): not at rest until it
			# stops speeding up, or it would "settle" and then move again.
			# It can also rock off a ridge (the Powder Keg's bowed staves):
			# spin swings down and then grows again, so compare to the
			# slowest spin since it came to rest too.
			var wn := b.angular_velocity.length()
			_poly_min_w[i] = minf(_poly_min_w[i], wn)
			if wn > 0.003 and (wn > _poly_prev_w[i] * PolyDie.CREEP_GROWTH or wn > _poly_min_w[i] * PolyDie.CREEP_REBOUND):
				still = false
		if i < _poly_prev_w.size():
			_poly_prev_w[i] = b.angular_velocity.length()
		if not still:
			at_rest = false
			_rest_since[i] = -1.0
			if i < _poly_min_w.size():
				_poly_min_w[i] = INF
		elif _rest_since[i] < 0.0:
			_rest_since[i] = _t
		# The tumble is ending: spin drops under the threshold (once per throw).
		var w := b.angular_velocity.length()
		if w > tuning.tumble_end_rad_s:
			_spun_up[i] = true
		elif _spun_up[i] and _rec.tumble_end_t[i] < 0.0:
			_rec.tumble_end_t[i] = _t
			_rec.tumble_end_speed[i] = w
	_rest_t = _rest_t + dt if at_rest else 0.0
	if _rest_t >= tuning.sim_rest_time:
		if _nudge_cocked():
			_rest_t = 0.0
		else:
			_rec.settled = true
			if post_rest_watch > 0.0:
				_watch_t = 0.0
				_watch_moving.clear()
				for i in active:
					_watch_moving.append(false)
				return
			_finish()
			return
	if _t >= tuning.sim_max_time:
		_finish()


## Simulation time (from the dice leaving the hand) when the assist starts.
## Release -> wind-up -> throw, so the wind-up comes off the clock.
func assist_time() -> float:
	return maxf(tuning.assist_start - tuning.windup_time, 0.2)


## Latest simulation time the dice may still be moving: the reveal (rest +
## settle wobble) must be done by reveal_cap after release.
func end_time() -> float:
	return tuning.reveal_cap - tuning.windup_time - tuning.settle_wobble_time - 0.02


## The settle assist: each die glides from where it is to the nearest flat
## pose a few cm along its travel, easing out (no snap). Recorded like the
## physics, so playback just shows a die rolling to a stop.
func _assist() -> void:
	_rec.assisted = true
	var dur := maxf(end_time() - _t, 0.06)
	var steps := maxi(int(ceil(dur / _rec.dt)), 2)
	var froms: Array[Transform3D] = []
	var targets: Array[Transform3D] = []
	for i in active:
		var b := bodies[i]
		var from := b.global_transform.orthonormalized()
		var moving := b.linear_velocity.length() > tuning.sim_rest_linear or b.angular_velocity.length() > tuning.sim_rest_angular
		if moving:
			_rec.assisted_dice += 1
			_rest_since[i] = -1.0
		var drift := Vector3(b.linear_velocity.x, 0.0, b.linear_velocity.z) * minf(dur, 0.25) * 0.5
		froms.append(from)
		targets.append(_flat(Transform3D(from.basis, from.origin + drift), i))
		_rec.rest_tilt_deg[i] = rest_tilt(i, from.basis)
		_rec.end_moving[i] = moving
	_separate(targets, froms)
	for i in active:
		var b := bodies[i]
		var from := froms[i]
		var target := targets[i]
		var qa := from.basis.get_rotation_quaternion()
		var qb := target.basis.get_rotation_quaternion()
		for k in steps:
			var p := float(k + 1) / float(steps)
			var e := 1.0 - pow(1.0 - p, 3.0)  # ease out: fast first, gentle stop
			var pos := from.origin.lerp(target.origin, e)
			# A die in the air still falls to the felt on a smooth curve.
			pos.y = lerpf(from.origin.y, target.origin.y, smoothstep(0.0, 1.0, minf(p * 1.6, 1.0)))
			(_rec.frames[i] as Array).append(Transform3D(Basis(qa.slerp(qb, e)), pos))
		b.global_transform = target
	_t += steps * _rec.dt
	_rec.settled = false
	_finish(true)


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


func _finish(already_flat: bool = false) -> void:
	running = false
	Engine.physics_ticks_per_second = _saved_ticks
	Engine.time_scale = _saved_scale
	Engine.max_physics_steps_per_frame = _saved_steps
	# Guarantee: end exactly flat on the felt with a short settle (normally
	# a fraction of a degree; the fallback for a throw that timed out).
	var lasts: Array[Transform3D] = []
	var targets: Array[Transform3D] = []
	for i in active:
		lasts.append(bodies[i].global_transform.orthonormalized())
		targets.append(_flat(lasts[i], i))
		if not already_flat:
			_rec.rest_tilt_deg[i] = rest_tilt(i, lasts[i].basis)
	if not already_flat:
		_separate(targets, lasts)
	for i in active:
		var last := lasts[i]
		var target := targets[i]
		var room := maxi(int((end_time() - _t) / _rec.dt), 1)
		var steps := mini(12, room) if last.basis.get_rotation_quaternion().angle_to(target.basis.get_rotation_quaternion()) > 0.02 else 1
		if already_flat:
			steps = 0
			target = last
		for k in steps:
			var p := float(k + 1) / float(steps)
			(_rec.frames[i] as Array).append(last.interpolate_with(target, p))
		# Coin: cube face 1 (+Y, heads) or 6 (-Y, tails), so the cube remap
		# math works unchanged; CoinPhysics.slot_for_axis_id() reads it.
		_rec.up_values[i] = DieVisual.value_up(target.basis)
		if is_coin(i):
			_rec.up_values[i] = CoinPhysics.axis_id(CoinPhysics.face_slot(target.basis))
		elif is_poly(i):
			# A hull die: its face SLOT (1-based, PolyDie direction table).
			_rec.up_values[i] = PolyDie.up_slot(shapes[i], target.basis)
		# Physically at rest: when it stopped for good (or the end of the
		# assist / settle-to-flat frames if it never stopped on its own).
		var end_t := float((_rec.frames[i] as Array).size() - 1) * _rec.dt
		_rec.rest_t[i] = _rest_since[i] if _rest_since[i] >= 0.0 and not already_flat else end_t
		if _rec.tumble_end_t[i] < 0.0:
			_rec.tumble_end_t[i] = minf(_rec.rest_t[i], end_t)
			_rec.tumble_end_speed[i] = 0.0
		bodies[i].freeze = true
		bodies[i].global_transform = target
	# Keep every die's frame array the same length.
	var n := 0
	for i in active:
		n = maxi(n, (_rec.frames[i] as Array).size())
	for i in active:
		var f := _rec.frames[i] as Array
		while f.size() < n:
			f.append(f[f.size() - 1])
	finished.emit(_rec)


## Flattening drops every die onto the felt, so a die that came to rest on
## top of (or leaning on) another would land inside it. Push overlapping
## targets apart on the felt (the higher die, the one that was stacked,
## moves; otherwise both), staying inside the rails.
func _separate(targets: Array[Transform3D], from: Array[Transform3D]) -> void:
	var lim := Table3DBuilder.FELT_HALF - Vector2.ONE * tuning.die_size * 0.75
	for it in 16:
		var moved := false
		for i in targets.size():
			for j in range(i + 1, targets.size()):
				# Two cubes: 1.05 edges apart (as before); a coin needs its radius.
				var min_d := (footprint(i) + footprint(j)) * 1.05
				var a := Vector2(targets[i].origin.x, targets[i].origin.z)
				var c := Vector2(targets[j].origin.x, targets[j].origin.z)
				var d := a.distance_to(c)
				if d >= min_d:
					continue
				var dir := (a - c) / d if d > 0.0001 else Vector2.RIGHT.rotated(_rng.randf_range(0.0, TAU))
				var push := min_d - d + 0.001
				var wi := 0.5
				if it < 8:  # later rounds split evenly (gets out of corners)
					if from[i].origin.y > from[j].origin.y + tuning.die_size * 0.3:
						wi = 1.0
					elif from[j].origin.y > from[i].origin.y + tuning.die_size * 0.3:
						wi = 0.0
				a += dir * push * wi
				c -= dir * push * (1.0 - wi)
				a = Vector2(clampf(a.x, -lim.x, lim.x), clampf(a.y, -lim.y, lim.y))
				c = Vector2(clampf(c.x, -lim.x, lim.x), clampf(c.y, -lim.y, lim.y))
				targets[i].origin = Vector3(a.x, targets[i].origin.y, a.y)
				targets[j].origin = Vector3(c.x, targets[j].origin.y, c.y)
				moved = true
		if not moved:
			return


## The nearest orientation that sits perfectly flat, resting on the felt,
## kept inside the felt (the walls should already guarantee that). Body i
## (optional) picks the shape: a coin lies on heads or tails, never its rim.
func _flat(t: Transform3D, i: int = -1) -> Transform3D:
	if is_coin(i):
		var cpos := t.origin
		var clim := Table3DBuilder.FELT_HALF - Vector2.ONE * tuning.die_size * 0.75
		cpos.x = clampf(cpos.x, -clim.x, clim.x)
		cpos.z = clampf(cpos.z, -clim.y, clim.y)
		cpos.y = rest_height(i)
		return Transform3D(CoinPhysics.flat_basis(t.basis, _rng), cpos)
	if is_poly(i):
		var pb := PolyDie.flat_basis(shapes[i], t.basis)
		var ppos := t.origin
		var plim := Table3DBuilder.FELT_HALF - Vector2.ONE * tuning.die_size * 0.75
		ppos.x = clampf(ppos.x, -plim.x, plim.x)
		ppos.z = clampf(ppos.z, -plim.y, plim.y)
		ppos.y = PolyDie.rest_height(shapes[i], pb)
		return Transform3D(pb, ppos)
	var b := t.basis.orthonormalized()
	var up := DieVisual.value_up(b)
	var axis_world := b * (DieVisual.FACE_AXES[up] as Vector3)
	var q := Quaternion(axis_world.normalized(), Vector3.UP)
	var nb := Basis(q) * b
	var pos := t.origin
	var lim := Table3DBuilder.FELT_HALF - Vector2.ONE * tuning.die_size * 0.75
	pos.x = clampf(pos.x, -lim.x, lim.x)
	pos.z = clampf(pos.z, -lim.y, lim.y)
	pos.y = tuning.die_size * 0.5
	return Transform3D(nb.orthonormalized(), pos)


## Finds contacts that began since the last tick (ignoring speculative
## contacts the solver hasn't pushed on yet, and stale ones left from where
## the body was before it was teleported) and records them with the
## RELATIVE speed at the contact point, measured from the previous tick's
## (pre-impact) velocities of both bodies, plus the solver's impulse.
## Die-die contacts are recorded once per pair, by the lower die id.
func _scan_contacts() -> void:
	for i in active:
		var b := bodies[i]
		var st := PhysicsServer3D.body_get_direct_state(b.get_rid())
		var now: Dictionary = {}
		if st != null:
			var com := st.transform.origin
			for c in st.get_contact_count():
				var other := st.get_contact_collider_object(c)
				var key := "%d:%d" % [st.get_contact_collider_id(c), st.get_contact_collider_shape(c)]
				# Stale contact: the first tick still lists where the body
				# rested before simulate() teleported it into the hand (the
				# point is then nowhere near the die). Not a hit.
				if (st.get_contact_local_position(c) - com).length() > tuning.die_size:
					continue
				# A speculative contact (no impulse yet: the bodies are only
				# close, e.g. a die released just above the felt) hasn't hit;
				# it begins once the solver pushes on it.
				if st.get_contact_impulse(c).length() <= 0.000001 and not _touching[i].has(key):
					continue
				now[key] = true
				if _touching[i].has(key) or now.has(key + "+"):
					continue
				now[key + "+"] = true
				var kind: StringName = &"felt"
				var other_id := -1
				if other is RigidBody3D and other.has_meta("die_index"):
					other_id = int(other.get_meta("die_index"))
					kind = &"die"
				elif other != null and other.has_meta("surface"):
					kind = other.get_meta("surface")
				if kind == &"die" and i > other_id:
					continue  # the lower id records the pair
				var p := st.get_contact_local_position(c)
				var v_self := _prev_lin[i] + _prev_ang[i].cross(p - com)
				var v_other := Vector3.ZERO
				if other_id >= 0:
					v_other = _prev_lin[other_id] + _prev_ang[other_id].cross(p - bodies[other_id].global_position)
				var impulse := st.get_contact_impulse(c).length()
				_rec.contacts.append({"t": _t, "die": i, "kind": kind, "speed": (v_self - v_other).length(), "impulse": impulse, "other": other_id})
		_touching[i] = now
	for i in active:
		_prev_lin[i] = bodies[i].linear_velocity
		_prev_ang[i] = bodies[i].angular_velocity
