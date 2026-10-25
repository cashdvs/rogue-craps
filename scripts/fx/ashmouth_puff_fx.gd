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
## Art rules: greys / soot only (no fire, no cyan, red or violet), each burst
## under 0.6 s. Mobile: CPUParticles3D on Compatibility, low counts. Reduced
## motion: about a third of the particles.
class_name AshmouthPuffFx
extends Node

## Fired when a puff starts: &"ash" (door opens) or &"soot" (door slams).
signal puffed(kind: StringName)

const TAUNT := &"taunt"
const DOOR_OPEN_T := 0.19
const DOOR_SLAM_T := 1.2
const DOOR_SOCKET := "Model/Smiles/Skeleton3D/FireboxDoorAttach/FireboxDoor"
const PIPE_SOCKET := "Model/Smiles/Skeleton3D/PipeMouthAttach/PipeMouth"
## Per puff: colour, particle count (Forward+ / Compatibility), lifetime (s),
## speed (m/s), size (m), gravity (m/s^2, y).
const PUFFS := {
	&"ash": {"color": Color("#A8A49C"), "count": 14, "count_mobile": 8, "life": 0.45, "speed": 0.45, "size": 0.055, "gravity": -0.6},
	&"soot": {"color": Color("#56524D"), "count": 10, "count_mobile": 6, "life": 0.55, "speed": 0.35, "size": 0.065, "gravity": 0.15},
}
const REDUCED_MOTION_SCALE := 0.3

## Fewer particles (REDUCED_MOTION_SCALE) when true.
var reduced_motion: bool = false
## Forces the CPUParticles3D path (Compatibility / mobile); else read from the renderer.
var mobile: bool = false
## The AnimationPlayer driving the taunt (found under the parent's Model).
var player: AnimationPlayer
## Socket name -> its burst emitter (GPUParticles3D or CPUParticles3D).
var emitters: Dictionary = {}
var _last_pos: float = -1.0


func _ready() -> void:
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


## Plays one puff now (also usable from a future method track).
func puff(kind: StringName) -> void:
	var e: Node = emitters.get(kind)
	if e == null or particle_count(kind) <= 0:
		return
	e.set("amount", particle_count(kind))
	e.set("emitting", false)
	e.call(&"restart")
	puffed.emit(kind)


## Particles per burst for this renderer and motion setting.
func particle_count(kind: StringName) -> int:
	var spec: Dictionary = PUFFS[kind]
	var n: int = spec["count_mobile"] if mobile else spec["count"]
	return maxi(1, ceili(n * REDUCED_MOTION_SCALE)) if reduced_motion else n


func _make_emitter(kind: StringName) -> Node3D:
	var spec: Dictionary = PUFFS[kind]
	var col: Color = spec["color"]
	var fade := Gradient.new()
	fade.set_color(0, Color(col, 0.85))
	fade.set_color(1, Color(col, 0.0))
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * float(spec["size"])
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = _round_dot()
	quad.material = mat
	# Ash spills out of the door (socket +Z), soot puffs up out of the pipe.
	var dir := Vector3(0, 0.2, 1) if kind == &"ash" else Vector3.UP
	var e: Node3D
	if mobile:
		var c := CPUParticles3D.new()
		c.mesh = quad
		c.direction = dir
		c.spread = 35.0
		c.initial_velocity_min = float(spec["speed"]) * 0.6
		c.initial_velocity_max = float(spec["speed"])
		c.gravity = Vector3(0, float(spec["gravity"]), 0)
		c.damping_min = 0.6
		c.damping_max = 0.9
		c.scale_amount_min = 0.7
		c.scale_amount_max = 1.3
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
		pm.damping_min = 0.6
		pm.damping_max = 0.9
		pm.scale_min = 0.7
		pm.scale_max = 1.3
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


## Flat toon dot: hard-edged round alpha so a puff reads as a cloud, not chips.
static func _round_dot() -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.8, 0.86])
	g.colors = PackedColorArray([Color.WHITE, Color.WHITE, Color(1, 1, 1, 0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 32
	t.height = 32
	return t
