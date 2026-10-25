## Ashmouth boss dealer: particle puffs on his taunt (3D Artist's rig v2).
## The firebox door flings open at DOOR_OPEN_T: an ash puff from the
## FireboxDoor socket. It slams at DOOR_SLAM_T: a soot puff from the
## PipeMouth socket. Add as a child of the Ashmouth scene root.
##
## The rig has no method track or signal for those beats, so this listener
## watches the AnimationPlayer's position while "taunt" plays and fires when
## the playhead crosses each time (works at any speed, and on replay).
## It never edits the rig, the clip or the scene.
##
## Each puff is a soft cloud ~10-12 cm across: a few large overlapping soft
## dots that grow 1.5x as they fade. On emit, a copy of the socket's emitter is
## moved to the board's FX root (Table3D.fx_root, else current_scene) with its
## global transform kept, so the burst outlives the dealer scene; it frees
## itself after its lifetime.
##
## Framing (AD option a, game_phone): the door sits behind the board's far
## rail, so the ash spawns at the door socket's XZ but lifted to just over the
## rail lip (top of the board's Backboard / WallBack mesh + ASH_RAIL_CLEAR) and
## billows up from there. With no rail found, [member ash_lift] is used. The
## soot rise is capped so the whole cloud stays [member soot_top_margin] of the
## viewport height inside the top of the active camera's frame.
##
## Art rules: greys / soot only (no fire, no cyan, red or violet), each burst
## under 0.6 s. Mobile: CPUParticles3D on Compatibility, low counts. Reduced
## motion: about a third of the particles.
class_name AshmouthPuffFx
extends Node

## Fired when a puff starts: &"ash" (door opens) or &"soot" (door slams).
signal puffed(kind: StringName)
## Fired with the live burst node (already under the FX root).
signal burst_spawned(kind: StringName, burst: Node3D)

const TAUNT := &"taunt"
const DOOR_OPEN_T := 0.19
const DOOR_SLAM_T := 1.2
const DOOR_SOCKET := "Model/Smiles/Skeleton3D/FireboxDoorAttach/FireboxDoor"
const PIPE_SOCKET := "Model/Smiles/Skeleton3D/PipeMouthAttach/PipeMouth"
## Per puff: colour, particle count (Forward+ / Compatibility), lifetime (s),
## speed (m/s), size (m), gravity (m/s^2, y).
## dot (m, start size), grow (end/start scale), radius (emission sphere, m),
## damping (m/s^2), dir (dealer-local; +Z is out of his front, -Z is back).
const PUFFS := {
	&"ash": {"color": Color("#A8A49C"), "count": 14, "count_mobile": 8, "life": 0.45, "speed": 0.095, "dot": 0.045, "grow": 1.5, "radius": 0.008, "damping": 0.25, "gravity": 0.05, "dir": Vector3(0, 1, 0.5)},
	&"soot": {"color": Color("#6E6A64"), "count": 10, "count_mobile": 6, "life": 0.55, "speed": 0.09, "dot": 0.05, "grow": 1.5, "radius": 0.006, "damping": 0.25, "gravity": 0.05, "dir": Vector3(0, 1, -0.35)},
}
## Rail meshes the ash must clear (Hearth board, then Table3D).
const RAIL_NAMES := ["Backboard", "WallBack"]
## Gap between the rail lip and the ash spawn (m).
const ASH_RAIL_CLEAR := 0.03
## Extra time before a spawned burst frees itself.
const FREE_PAD := 0.1
const REDUCED_MOTION_SCALE := 0.3

## Fewer particles (REDUCED_MOTION_SCALE) when true.
@export var reduced_motion: bool = false
## Forces the CPUParticles3D path (Compatibility / mobile); else read from the renderer.
var mobile: bool = false
## Fallback ash lift above the door socket (m) when no rail mesh is found:
## Hearth far rail lip (y 0.066) - door socket (y -0.373) + ASH_RAIL_CLEAR.
@export var ash_lift: float = 0.47
## Soot cloud top must stay this fraction of the viewport height below the
## frame top (8 px of a 390 pt phone at 2x = 780 px is 1.03%; 1.6% for slack).
@export var soot_top_margin: float = 0.016
## When false, _ready keeps [member mobile] as set (tests).
var detect_renderer: bool = true
## The AnimationPlayer driving the taunt (found under the parent's Model).
var player: AnimationPlayer
## Socket name -> its burst emitter (GPUParticles3D or CPUParticles3D).
var emitters: Dictionary = {}
var _last_pos: float = -1.0


func _ready() -> void:
	if detect_renderer:
		mobile = mobile or RenderingServer.get_current_rendering_method() != "forward_plus"
	setup(get_parent())


## Finds the player and sockets under [param root] and builds the emitters.
## Missing sockets just mean no puff there.
func setup(root: Node) -> void:
	if root == null:
		return
	var model := root.get_node_or_null("Model")
	if model != null:
		var found := model.find_children("*", "AnimationPlayer", true, false)
		if not found.is_empty():
			player = found[0] as AnimationPlayer
	for kind: StringName in [&"ash", &"soot"]:
		var socket := root.get_node_or_null(DOOR_SOCKET if kind == &"ash" else PIPE_SOCKET) as Node3D
		if socket != null and not emitters.has(kind):
			var e := _make_emitter(kind)
			socket.add_child(e)
			emitters[kind] = e


func _process(_dt: float) -> void:
	tick()


## Fires the puffs whose time the taunt playhead crossed since the last tick.
func tick() -> void:
	if player == null or player.current_animation != TAUNT or not player.is_playing():
		_last_pos = -1.0
		return
	var pos := player.current_animation_position
	if pos < _last_pos:
		_last_pos = -1.0
	if _last_pos < DOOR_OPEN_T and pos >= DOOR_OPEN_T:
		puff(&"ash")
	if _last_pos < DOOR_SLAM_T and pos >= DOOR_SLAM_T:
		puff(&"soot")
	_last_pos = pos


## Plays one puff now (also usable from a future method track). The burst is
## a copy of the socket emitter, moved under [method fx_root] with its global
## transform, and freed after its lifetime.
func puff(kind: StringName) -> void:
	var e := emitters.get(kind) as Node3D
	if e == null or particle_count(kind) <= 0 or not e.is_inside_tree():
		return
	var host := fx_root()
	if host == null:
		return
	var b := e.duplicate() as Node3D
	b.set_meta("kind", kind)
	b.name = "%s_%d" % [e.name, Time.get_ticks_usec()]
	b.set("amount", particle_count(kind))
	# Socket position, dealer facing (so "up / back / out of the door" read in his frame).
	var at := e.global_position
	if kind == &"ash":
		at.y = ash_spawn_y(at)
	var xf := Transform3D(_facing_basis(), at)
	host.add_child(b)
	b.global_transform = xf
	if kind == &"soot":
		_cap_soot(b)
	b.set("emitting", true)
	b.call(&"restart")
	var t := float(PUFFS[kind]["life"]) + FREE_PAD
	b.get_tree().create_timer(t, false).timeout.connect(b.queue_free)
	puffed.emit(kind)
	burst_spawned.emit(kind, b)


## Where bursts live: the nearest ancestor's Table3D-style `fx_root`, else
## current_scene, else the tree root.
func fx_root() -> Node:
	if not is_inside_tree():
		return null
	var n := get_parent()
	while n != null:
		var r = n.get("fx_root")
		if r is Node3D and is_instance_valid(r) and (r as Node).is_inside_tree():
			return r
		n = n.get_parent()
	var tree := get_tree()
	return tree.current_scene if tree.current_scene != null else tree.root


## Ash spawn height: just over the rail lip in front of the door, or the
## socket + [member ash_lift] when there is no rail. Never below the socket.
func ash_spawn_y(socket_pos: Vector3) -> float:
	var top := rail_top_y()
	if is_nan(top):
		return socket_pos.y + ash_lift
	return maxf(socket_pos.y, top + ASH_RAIL_CLEAR)


## World Y of the rail lip in front of the door: the top of the visible rail
## meshes (RAIL_NAMES, nearest ancestor first) that span the door's X and sit
## in front of it (dealer +Z). NAN when none.
func rail_top_y() -> float:
	var door := get_parent().get_node_or_null(DOOR_SOCKET) as Node3D if get_parent() != null else null
	if door == null or not door.is_inside_tree():
		return NAN
	var at := door.global_position
	var fwd := _facing_basis().z
	var n: Node = get_parent().get_parent()
	while n != null:
		var top := -INF
		for nm: String in RAIL_NAMES:
			for r in n.find_children(nm, "", true, false):
				var meshes: Array = [r] if r is MeshInstance3D else []
				meshes.append_array(r.find_children("*", "MeshInstance3D", true, false))
				for m in meshes:
					var mi := m as MeshInstance3D
					if not mi.is_visible_in_tree():
						continue
					var ab := mi.global_transform * mi.get_aabb()
					if at.x < ab.position.x or at.x > ab.end.x:
						continue
					if (ab.get_center() - at).dot(fwd) <= 0.0:
						continue
					top = maxf(top, ab.end.y)
		if top > -INF:
			return top
		n = n.get_parent()
	return NAN


## Highest world point a puff cloud reaches above its spawn (m).
static func cloud_rise(kind: StringName, k: float = 1.0) -> float:
	var s: Dictionary = PUFFS[kind]
	var v := float(s["speed"]) * k
	var d := float(s["damping"])
	var life := float(s["life"])
	var t := minf(life, v / d) if d > 0.0 else life
	var dir: Vector3 = (s["dir"] as Vector3).normalized()
	var travel := v * t - 0.5 * d * t * t
	return maxf(0.0, dir.y) * travel + 0.5 * maxf(0.0, float(s["gravity"]) * k) * life * life \
		+ float(s["radius"]) + 0.5 * float(s["dot"]) * float(s["grow"])


## Highest world Y at (x, z) that stays soot_top_margin inside the top of the
## active camera's frame, or INF without a camera.
func frame_top_y(at: Vector3) -> float:
	var vp := get_viewport()
	var cam := vp.get_camera_3d() if vp != null else null
	if cam == null:
		return INF
	var min_px := soot_top_margin * vp.get_visible_rect().size.y
	# Search below the camera's height only: points above it can project back
	# into the frame (wrap) and fool the test.
	var lo := at.y - 1.0
	var hi := minf(at.y + 2.0, cam.global_position.y - 0.05)
	if hi <= at.y:
		return INF
	var inside := func(y: float) -> bool:
		var p := Vector3(at.x, y, at.z)
		return not cam.is_position_behind(p) and cam.unproject_position(p).y >= min_px
	if inside.call(hi):
		return INF
	for i in 30:
		var mid := (lo + hi) * 0.5
		if inside.call(mid):
			lo = mid
		else:
			hi = mid
	return lo


## Scales the soot burst's speed (then lowers it) so its cloud top stays
## inside the frame. Returns the speed scale used.
func _cap_soot(b: Node3D) -> float:
	var at := b.global_position
	var room := frame_top_y(at) - at.y
	if room == INF or room >= cloud_rise(&"soot"):
		return 1.0
	var k := 1.0
	while k > 0.0 and cloud_rise(&"soot", k) > room:
		k -= 0.05
	k = maxf(k, 0.0)
	var spec: Dictionary = PUFFS[&"soot"]
	var v := float(spec["speed"]) * k
	var g := Vector3(0, float(spec["gravity"]) * k, 0)
	if b is CPUParticles3D:
		(b as CPUParticles3D).initial_velocity_min = v * 0.6
		(b as CPUParticles3D).initial_velocity_max = v
		(b as CPUParticles3D).gravity = g
	else:
		var pm := ((b as GPUParticles3D).process_material as ParticleProcessMaterial).duplicate() as ParticleProcessMaterial
		pm.initial_velocity_min = v * 0.6
		pm.initial_velocity_max = v
		pm.gravity = g
		(b as GPUParticles3D).process_material = pm
	var over := cloud_rise(&"soot", k) - room
	if over > 0.0:
		b.global_position.y -= over
	b.set_meta("soot_k", k)
	return k


## Approximate cloud diameter (m): dot at full grow plus twice the travel.
static func cloud_diameter(kind: StringName) -> float:
	var s: Dictionary = PUFFS[kind]
	var v := float(s["speed"])
	var d := float(s["damping"])
	var life := float(s["life"])
	var t := minf(life, v / d) if d > 0.0 else life
	var travel := v * t - 0.5 * d * t * t
	return float(s["dot"]) * float(s["grow"]) + 2.0 * (float(s["radius"]) + travel)


func _facing_basis() -> Basis:
	var p := get_parent() as Node3D
	return p.global_basis.orthonormalized() if p != null and p.is_inside_tree() else Basis.IDENTITY


## Particles per burst for this renderer and motion setting.
func particle_count(kind: StringName) -> int:
	var spec: Dictionary = PUFFS[kind]
	var n: int = spec["count_mobile"] if mobile else spec["count"]
	return maxi(1, ceili(n * REDUCED_MOTION_SCALE)) if reduced_motion else n


func _make_emitter(kind: StringName) -> Node3D:
	var spec: Dictionary = PUFFS[kind]
	var col: Color = spec["color"]
	var fade := Gradient.new()
	fade.set_color(0, Color(col, 0.7))
	fade.set_color(1, Color(col, 0.0))
	var grow := Curve.new()
	grow.add_point(Vector2(0, 1.0 / float(spec["grow"])))
	grow.add_point(Vector2(1, 1.0))
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * float(spec["dot"]) * float(spec["grow"])
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = _round_dot()
	quad.material = mat
	# Ash spills out of the door (front), soot puffs up and slightly back.
	var dir: Vector3 = spec["dir"]
	var r := float(spec["radius"])
	var damp := float(spec["damping"])
	var e: Node3D
	if mobile:
		var c := CPUParticles3D.new()
		c.mesh = quad
		c.direction = dir
		c.spread = 35.0
		c.initial_velocity_min = float(spec["speed"]) * 0.6
		c.initial_velocity_max = float(spec["speed"])
		c.gravity = Vector3(0, float(spec["gravity"]), 0)
		c.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		c.emission_sphere_radius = r
		c.damping_min = damp
		c.damping_max = damp
		c.scale_amount_min = 0.9
		c.scale_amount_max = 1.1
		c.scale_amount_curve = grow
		c.color_ramp = fade
		e = c
	else:
		var g := GPUParticles3D.new()
		var pm := ParticleProcessMaterial.new()
		pm.direction = dir
		pm.spread = 35.0
		pm.initial_velocity_min = float(spec["speed"]) * 0.6
		pm.initial_velocity_max = float(spec["speed"])
		pm.gravity = Vector3(0, float(spec["gravity"]), 0)
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		pm.emission_sphere_radius = r
		pm.damping_min = damp
		pm.damping_max = damp
		pm.scale_min = 0.9
		pm.scale_max = 1.1
		var gc := CurveTexture.new()
		gc.curve = grow
		pm.scale_curve = gc
		var gt := GradientTexture1D.new()
		gt.gradient = fade
		pm.color_ramp = gt
		g.process_material = pm
		g.draw_pass_1 = quad
		e = g
	e.name = "%sPuff" % String(kind).capitalize()
	e.set("one_shot", true)
	e.set("emitting", false)
	e.set("explosiveness", 0.9)
	e.set("lifetime", float(spec["life"]))
	e.set("amount", particle_count(kind))
	e.set("local_coords", false)
	e.set_meta("kind", kind)
	return e


## Soft dot: solid core, alpha falling off to the rim so dots blend into one cloud.
static func _round_dot() -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	g.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0.8), Color(1, 1, 1, 0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 64
	t.height = 64
	return t
