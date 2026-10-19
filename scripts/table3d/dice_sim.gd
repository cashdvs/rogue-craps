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
		var box := BoxShape3D.new()
		box.size = Vector3.ONE * tuning.die_size
		cs.shape = box
		b.add_child(cs)
		add_child(b)
		bodies.append(b)
		_prev_lin.append(Vector3.ZERO)
		_prev_ang.append(Vector3.ZERO)
		_touching.append({})
		_rest_since.append(-1.0)
		_spun_up.append(false)


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
	# Settle assist: anything still moving now gets eased onto its face.
	if _t >= assist_time():
		_assist()
		return
	var at_rest := true
	for i in active:
		var b := bodies[i]
		var still := b.linear_velocity.length() <= tuning.sim_rest_linear and b.angular_velocity.length() <= tuning.sim_rest_angular
		if not still:
			at_rest = false
			_rest_since[i] = -1.0
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
	for i in active:
		var b := bodies[i]
		var from := b.global_transform.orthonormalized()
		var moving := b.linear_velocity.length() > tuning.sim_rest_linear or b.angular_velocity.length() > tuning.sim_rest_angular
		if moving:
			_rec.assisted_dice += 1
			_rest_since[i] = -1.0
		var drift := Vector3(b.linear_velocity.x, 0.0, b.linear_velocity.z) * minf(dur, 0.25) * 0.5
		var target := _flat(Transform3D(from.basis, from.origin + drift))
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
		var up := DieVisual.value_up(basis)
		var d := (basis * (DieVisual.FACE_AXES[up] as Vector3)).dot(Vector3.UP)
		var too_high := b.global_position.y > tuning.die_size * 0.62
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


func _finish(already_flat: bool = false) -> void:
	running = false
	Engine.physics_ticks_per_second = _saved_ticks
	Engine.time_scale = _saved_scale
	Engine.max_physics_steps_per_frame = _saved_steps
	# Guarantee: end exactly flat on the felt with a short settle (normally
	# a fraction of a degree; the fallback for a throw that timed out).
	for i in active:
		var last := bodies[i].global_transform.orthonormalized()
		var target := _flat(last)
		var room := maxi(int((end_time() - _t) / _rec.dt), 1)
		var steps := mini(12, room) if last.basis.get_rotation_quaternion().angle_to(target.basis.get_rotation_quaternion()) > 0.02 else 1
		if already_flat:
			steps = 0
			target = last
		for k in steps:
			var p := float(k + 1) / float(steps)
			(_rec.frames[i] as Array).append(last.interpolate_with(target, p))
		_rec.up_values[i] = DieVisual.value_up(target.basis)
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


## The nearest orientation that sits perfectly flat, resting on the felt,
## kept inside the felt (the walls should already guarantee that).
func _flat(t: Transform3D) -> Transform3D:
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
