## The Dealer (poc_3d.md section 6), greybox "bust": a pit-black silhouette
## behind the far rail with a dealer visor, two ember eyes and a grin slit
## that only shows when he wins. Plus his rake (stick + T-head + brass
## ferrule) resting on the far rail. Lit from behind by the burgundy rim
## light so his edge reads against the black walls.
class_name Dealer3D
extends Node3D

var eyes: Array[MeshInstance3D] = []
var eye_mat: ShaderMaterial
var grin: MeshInstance3D
var grin_mat: ShaderMaterial
var rake: Node3D
var head: Node3D
## Head position in world space (the speech bubble anchors here).
var head_anchor: Node3D
var reduced_motion: bool = false

var _blink_in: float = 4.0
var _blink: float = 0.0
var _narrow: float = 0.0
var _flare: float = 0.0
var _look_x: float = 0.0
var _look_target: float = 0.0
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.seed = 404
	# Spec: centered behind the far rail. With the spec camera (55 deg, FOV 36,
	# 2.5 m) a full-height bust at z = -0.95 sits above the frame, so the
	# greybox dealer stands lower and a little closer: his visor and eyes
	# loom just over the far rail near the top of the screen.
	position = Vector3(0, -0.5, -0.86)
	var body := Toon.inked(Palette.PIT_BLACK, Color.BLACK, Toon.INK_DEALER, {"rim_color": Palette.BURGUNDY, "rim_strength": 0.6, "rim_power": 2.0, "light_gain": 0.6})
	var body_box := Toon.inked(Palette.PIT_BLACK, Color.BLACK, Toon.INK_DEALER, {"rim_color": Palette.BURGUNDY, "rim_strength": 0.6, "rim_power": 2.0, "light_gain": 0.6}, 1)
	# Torso (mostly below the rail) and slumped shoulders.
	Toon.add_mesh(self, Toon.box(Vector3(0.62, 0.55, 0.3)), body_box, Vector3(0, 0.12, 0))
	var shoulders := CapsuleMesh.new()
	shoulders.radius = 0.12
	shoulders.height = 0.75
	Toon.add_mesh(self, shoulders, body, Vector3(0, 0.37, 0), Vector3(0, 0, 90)).name = "Shoulders"
	# Vest V hint.
	Toon.add_mesh(self, Toon.box(Vector3(0.05, 0.22, 0.01)), Toon.mat(Palette.OXBLOOD, Color.BLACK), Vector3(-0.04, 0.33, 0.155), Vector3(0, 0, 18))
	Toon.add_mesh(self, Toon.box(Vector3(0.05, 0.22, 0.01)), Toon.mat(Palette.OXBLOOD, Color.BLACK), Vector3(0.04, 0.33, 0.155), Vector3(0, 0, -18))
	Toon.add_mesh(self, Toon.cylinder(0.05, 0.12, 12), body, Vector3(0, 0.5, 0))
	head = Node3D.new()
	head.position = Vector3(0, 0.61, 0)
	add_child(head)
	var skull := SphereMesh.new()
	skull.radius = 0.14
	skull.height = 0.30
	Toon.add_mesh(head, skull, body)
	# The visor: a band and a forward-jutting brim (the key shape cue).
	Toon.add_mesh(head, Toon.cylinder(0.145, 0.04, 20), Toon.mat(Color("#14100E"), Color.BLACK, {"rim_color": Palette.BURGUNDY, "rim_strength": 0.5}), Vector3(0, 0.06, 0))
	var brim_mat := Toon.inked(Color("#1E3A2E"), Color.BLACK, Toon.INK_DEALER * 0.6, {"rim_color": Palette.BURGUNDY, "rim_strength": 0.5}, 1)
	Toon.add_mesh(head, Toon.box(Vector3(0.28, 0.01, 0.12)), brim_mat, Vector3(0, 0.075, 0.16), Vector3(-24, 0, 0)).name = "VisorBrim"
	# Eyes: two small emissive ovals under the brim.
	eye_mat = Toon.mat(Color("#FF7A1F"), Color("#FF7A1F"), {"emission_color": Color("#FFD27A"), "emission_energy": 3.0, "light_gain": 0.0})
	for sx in [-1.0, 1.0]:
		var e := Toon.add_mesh(head, Toon.sphere(0.02, 10), eye_mat, Vector3(sx * 0.028, -0.03, 0.125))
		e.scale = Vector3(1.0, 0.6, 0.6)
		eyes.append(e)
	grin_mat = Toon.mat(Palette.EMBER, Palette.EMBER, {"emission_color": Color("#FF7A1F"), "emission_energy": 3.0, "light_gain": 0.0})
	grin = Toon.add_mesh(head, Toon.box(Vector3(0.08, 0.008, 0.01)), grin_mat, Vector3(0, -0.085, 0.115))
	grin.scale = Vector3(0.001, 1, 1)
	grin.visible = false
	head_anchor = Node3D.new()
	head_anchor.position = Vector3(0.16, 0.12, 0.0)
	head.add_child(head_anchor)
	_build_rake()


func _build_rake() -> void:
	rake = Node3D.new()
	rake.name = "Rake"
	rake.top_level = true  # positioned in world space
	add_child(rake)
	var wood := Toon.inked(Palette.PIT_BLACK, Color.BLACK, 0.003, {"rim_color": Palette.BURGUNDY, "rim_strength": 0.4}, 1)
	var brass := Toon.inked(Palette.BRASS, Toon.SHADOW_BRASS, 0.003, {"spec_size": 0.92, "spec_color": Palette.BRASS_HI}, 1)
	# The stick runs from the head (local origin) back toward the dealer.
	Toon.add_mesh(rake, Toon.box(Vector3(0.012, 0.012, 1.0)), wood, Vector3(0, 0.02, -0.5))
	Toon.add_mesh(rake, Toon.box(Vector3(0.18, 0.02, 0.012)), wood, Vector3(0, 0.01, 0))
	Toon.add_mesh(rake, Toon.cylinder(0.01, 0.04, 10), brass, Vector3(0, 0.02, -0.03), Vector3(90, 0, 0))
	rake_rest()


## The rake rests on the far rail, head on the felt edge.
func rake_rest() -> void:
	rake.position = Vector3(0.45, 0.13, -0.53)
	rake.rotation_degrees = Vector3(8, -18, 0)


## Positions the rake's head at a world point on the felt.
func rake_at(world: Vector3) -> void:
	rake.position = world + Vector3(0, 0.005, 0)
	rake.rotation_degrees = Vector3(14, 0, 0)


func _process(delta: float) -> void:
	# Real-time clock: unaffected by hit-stop / the physics warp.
	var t := Time.get_ticks_msec() / 1000.0
	if not reduced_motion:
		head.position.y = 0.61 + sin(t * 1.3) * 0.004
		# Lean toward the table a touch, breathing.
		rotation.z = sin(t * 0.7) * 0.01
	_blink_in -= delta
	if _blink_in <= 0.0:
		_blink = 0.12
		_blink_in = _rng.randf_range(4.0, 7.0)
	_blink = maxf(_blink - delta, 0.0)
	_narrow = maxf(_narrow - delta * 0.6, 0.0)
	_flare = maxf(_flare - delta * 1.5, 0.0)
	_look_x = lerpf(_look_x, _look_target, minf(delta * 6.0, 1.0))
	var sy := 0.6 * (0.08 if _blink > 0.0 else (1.0 - 0.5 * clampf(_narrow * 2.0, 0.0, 1.0)))
	for e in eyes:
		e.scale.y = sy
		e.position.x = signf(e.position.x) * 0.028 + _look_x
	eye_mat.set_shader_parameter("emission_energy", 3.0 + 2.0 * clampf(_flare * 3.0, 0.0, 1.0))


## Glance toward the dice (world x).
func glance(world_x: float) -> void:
	_look_target = clampf(world_x * 0.01, -0.008, 0.008)


## Natural / Point hit: eyes narrow. Craps / Seven-out: flare + grin.
func react(pose: StringName) -> void:
	match pose:
		&"sulk":
			_narrow = 1.0
		&"gloat":
			_flare = 1.0
			grin.visible = true
			grin.scale = Vector3(0.001, 1, 1)
			var tw := create_tween()
			tw.tween_property(grin, "scale", Vector3.ONE, 0.15)
			tw.tween_interval(1.4)
			tw.tween_property(grin, "scale", Vector3(0.001, 1, 1), 0.2)
			tw.tween_callback(func() -> void: grin.visible = false)


func flare_eyes() -> void:
	_flare = 0.6
