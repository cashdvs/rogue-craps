## One bone die you can SEE (poc_3d.md section 3): a 0.08 m rounded cube with
## dark pips and an ink outline. It has no physics of its own: during a throw
## it copies the transform of an invisible RigidBody3D (see DiceSim), and its
## inner `faces` node can be turned to any of the 24 cube orientations so the
## face the seeded DiceRoller picked is the one that ends up on top.
##
## Face layout (opposite faces sum to 7), in the die's local space:
##   +Y = 1, -Y = 6, +X = 2, -X = 5, +Z = 3, -Z = 4
class_name DieVisual
extends Node3D

## Audio hooks (the Sound Designer owns what plays; Table3D hooks the
## SfxManager to these for now). All are emitted during PLAYBACK, in sync
## with what you see.
##
## A contact began. speed_mps = relative speed at the contact point (pre-
## impact), impulse = the solver's contact impulse (N*s). surface is
## "felt", "rail", "backboard", "die", "chip" or "puck". Die-die hits are
## emitted ONCE per pair, by the lower die id, with other_id = the other
## die (else -1). material = this die's DieData.material ("bone"...).
## Contacts under tuning.impact_min_speed are silent; throttled per die by
## tuning.impact_min_interval.
signal impact(die_id: int, surface: String, speed_mps: float, impulse: float, other_id: int, material: String)
## The die is physically at rest (before the reveal).
signal rest(die_id: int)
## Once per throw: the die's spin dropped below tuning.tumble_end_rad_s.
signal tumble_ending(die_id: int, angular_speed: float)
## The reveal: the die shows `face` (the seeded value).
signal settled(die_id: int, face: int)

## What it is made of (from DieData.material), passed in impact.
var material: String = "bone"
## 0 or 1: which of the pair this is.
var die_id: int = 0

const FACE_AXES: Dictionary = {
	1: Vector3.UP, 6: Vector3.DOWN,
	2: Vector3.RIGHT, 5: Vector3.LEFT,
	3: Vector3.BACK, 4: Vector3.FORWARD,
}
## Pip spots on a face in "face units" (-0.5..0.5), per value. The spec's
## fractional positions 0.27 / 0.50 / 0.73 become -0.23 / 0 / +0.23.
const PIPS: Dictionary = {
	1: [Vector2(0, 0)],
	2: [Vector2(-1, -1), Vector2(1, 1)],
	3: [Vector2(-1, -1), Vector2(0, 0), Vector2(1, 1)],
	4: [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)],
	5: [Vector2(-1, -1), Vector2(1, -1), Vector2(0, 0), Vector2(-1, 1), Vector2(1, 1)],
	6: [Vector2(-1, -1), Vector2(-1, 0), Vector2(-1, 1), Vector2(1, -1), Vector2(1, 0), Vector2(1, 1)],
}
const PIP_STEP: float = 0.23

## Edge length in meters.
var edge: float = 0.08
## The rotated part (body mesh + pips). Its basis is the "face remap".
var faces: Node3D
var body_material: ShaderMaterial
## Extra brightness for reduced-motion readability (0..1).
var highlight: float = 0.0:
	set(v):
		highlight = v
		if body_material != null:
			body_material.set_shader_parameter("emission_energy", 0.12 * v)


func _init(edge_m: float = 0.08) -> void:
	edge = edge_m
	faces = Node3D.new()
	faces.name = "Faces"
	add_child(faces)
	body_material = Toon.inked(Palette.BONE, Toon.SHADOW_BONE, Toon.INK_DICE, {
		"wrap": 0.35, "spec_size": 0.97, "spec_color": Color("#FFF6E0"),
		"roughness": 0.45, "mid_tint": 0.8, "emission_color": Palette.BONE,
	})
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = rounded_cube(edge, 0.16 * edge)
	body.material_override = body_material
	faces.add_child(body)
	_add_pips()
	# Cheap blob shadow under the die (spec: 0.10 m, PIT_BLACK 40%).
	var blob := MeshInstance3D.new()
	blob.name = "Blob"
	var q := QuadMesh.new()
	q.size = Vector2(edge * 1.25, edge * 1.25)
	q.orientation = PlaneMesh.FACE_Y
	blob.mesh = q
	blob.material_override = Toon.fx(Color(Palette.PIT_BLACK, 0.4), 1.0, 0, false)
	blob.top_level = true
	add_child(blob)


func _process(_delta: float) -> void:
	# Keep the blob flat on the felt under the die.
	var blob := get_node("Blob") as Node3D
	blob.global_position = Vector3(global_position.x, 0.002, global_position.z)
	var h := clampf(global_position.y / 0.4, 0.0, 1.0)
	blob.scale = Vector3.ONE * (1.0 + h)
	blob.visible = visible


## The face value currently on top (reads the faces node's world basis).
func up_value() -> int:
	return value_up(faces.global_transform.basis)


## How flat the top face is: 1.0 = perfectly flat.
func up_dot() -> float:
	var b := faces.global_transform.basis.orthonormalized()
	return (b * (FACE_AXES[value_up(b)] as Vector3)).dot(Vector3.UP)


## Screen-space size: projects the die's 8 corners and returns the bounding
## box size in pixels (used by the phone readability check).
func screen_size(cam: Camera3D) -> Vector2:
	return projected_size(cam, faces.global_transform, edge)


## Pixel bounding box of a cube of size `edge` with transform `xf`.
static func projected_size(cam: Camera3D, xf: Transform3D, edge_m: float) -> Vector2:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	var h := edge_m * 0.5
	for x in [-h, h]:
		for y in [-h, h]:
			for z in [-h, h]:
				var p := cam.unproject_position(xf * Vector3(x, y, z))
				lo = lo.min(p)
				hi = hi.max(p)
	return hi - lo


# --- Face math (static: tests use it directly) --------------------------------------

## Which face value points most nearly straight up for a die with basis b.
static func value_up(b: Basis) -> int:
	var best := 1
	var best_dot := -2.0
	var ob := b.orthonormalized()
	for v: int in FACE_AXES:
		var d := (ob * (FACE_AXES[v] as Vector3)).dot(Vector3.UP)
		if d > best_dot:
			best_dot = d
			best = v
	return best


## The fixed rotation for the inner `faces` node so that, on a body whose
## physical top face is `physical_up`, the face showing `wanted` is on top.
## `yaw` spins it around the up axis (any of the 4 quarter turns keeps the
## same face on top; a random one hides that the faces were re-mapped).
static func remap_basis(physical_up: int, wanted: int, yaw: float = 0.0) -> Basis:
	var a_phys := FACE_AXES[physical_up] as Vector3
	var a_want := FACE_AXES[wanted] as Vector3
	var r := Basis.IDENTITY
	if a_want.is_equal_approx(-a_phys):
		# Opposite faces: a half turn around any axis at right angles.
		var perp := Vector3.RIGHT if absf(a_phys.x) < 0.5 else Vector3.UP
		r = Basis(perp, PI)
	elif not a_want.is_equal_approx(a_phys):
		r = Basis(a_want.cross(a_phys).normalized(), PI * 0.5)
	# Quarter-turn yaw around the physical up axis (keeps the cube aligned).
	var quarter := roundf(yaw / (PI * 0.5)) * PI * 0.5
	return Basis(a_phys, quarter) * r


# --- Mesh building ---------------------------------------------------------------

## A cube with rounded edges and smooth normals. Each face is a small grid
## whose outer rows sit on the bevel; pushing those vertices onto a sphere
## of radius r around the inner box gives the rounded look.
static func rounded_cube(size: float, radius: float) -> ArrayMesh:
	var h := size * 0.5
	var c := h - radius
	# Grid coordinates across a face: 2 bevel steps on each side.
	var coords: Array[float] = [-h, -c - radius * tan(PI / 8.0), -c, c, c + radius * tan(PI / 8.0), h]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var axes: Array[Vector3] = [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.BACK, Vector3.FORWARD]
	for n in axes:
		var u := Vector3.UP if absf(n.y) < 0.5 else Vector3.RIGHT
		u = (u - n * u.dot(n)).normalized()
		var v := n.cross(u)
		var n_steps := coords.size()
		var grid: Array[Vector3] = []
		for j in n_steps:
			for i in n_steps:
				grid.append(n * h + u * coords[i] + v * coords[j])
		for j in n_steps - 1:
			for i in n_steps - 1:
				var p00 := grid[j * n_steps + i]
				var p10 := grid[j * n_steps + i + 1]
				var p01 := grid[(j + 1) * n_steps + i]
				var p11 := grid[(j + 1) * n_steps + i + 1]
				_tri(st, p00, p10, p11, c, radius, n)
				_tri(st, p00, p11, p01, c, radius, n)
	st.index()
	return st.commit()


static func _round(p: Vector3, c: float, radius: float) -> Array[Vector3]:
	var inner := p.clamp(Vector3(-c, -c, -c), Vector3(c, c, c))
	var dir := (p - inner).normalized()
	return [inner + dir * radius, dir]


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, d: Vector3, c: float, radius: float, face_n: Vector3) -> void:
	var pts: Array[Vector3] = [a, b, d]
	# Godot draws clockwise triangles as front faces (seen from outside).
	if (b - a).cross(d - a).dot(face_n) > 0.0:
		pts = [a, d, b]
	for p in pts:
		var r := _round(p, c, radius)
		st.set_normal(r[1])
		st.add_vertex(r[0])


## What each physical face slot (1..6, see FACE_AXES) shows. Default: its own
## number. A Knucklebone uses [1, 1, 2, 2, 3, 3]: slot 4 shows 2 pips.
var labels: Array[int] = [1, 2, 3, 4, 5, 6]
var _pips_root: Node3D


## Restyles the die: body colour, pip colour and the per-slot pip counts.
func set_look(body: Color, pip: Color, slot_labels: Array[int]) -> void:
	labels = slot_labels.duplicate() if slot_labels.size() == 6 else [1, 2, 3, 4, 5, 6]
	body_material.set_shader_parameter("albedo", body)
	body_material.set_shader_parameter("shadow_color", body.darkened(0.55))
	body_material.set_shader_parameter("emission_color", body)
	_pip_color = pip
	_add_pips()


## The number shown on top (the slot's label).
func shown_value() -> int:
	return labels[up_value() - 1]


var _pip_color: Color = Palette.PIT_BLACK
## The pip material (all pips of this die share it) and the small hot "core"
## disc inside each pip. Only the core is bright enough to bloom.
var pip_material: ShaderMaterial
var pip_core_material: ShaderMaterial
var _pip_cores: Array[MeshInstance3D] = []


# --- Lit / cold readability state (design section 4, art/ui/readability) -----------
## The ember colours from the Art Director's die_state_reference.gdshader.
const EMBER_MID := Color(0.910, 0.384, 0.165)   # #E8622A
const EMBER_CORE := Color(1.000, 0.902, 0.659)  # #FFE6A8
const PIP_MID_ENERGY := 0.9    # under the glow threshold: no bloom
const PIP_CORE_ENERGY := 3.0   # over it: the only part that blooms
const COLD_PIP_TO_BODY := 0.55
## Tween times: lighting up is snappy, going cold is a little slower.
const LIT_TIME := 0.08
const COLD_TIME := 0.15
## 0..1: how "lit" (scoring) and how "cold" (not scoring) this die looks.
var glow_lit: float = 0.0
var glow_cold: float = 0.0
var _glow_tween: Tween


## Shows the die as lit (scoring), cold (didn't score) or plain (both false).
## Material only: no lights, no particles. `instant` skips the tween.
func set_glow_state(lit: bool, cold: bool, instant: bool = false) -> void:
	var to_lit := 1.0 if lit else 0.0
	var to_cold := 1.0 if (cold and not lit) else 0.0
	if _glow_tween != null:
		_glow_tween.kill()
		_glow_tween = null
	var t := LIT_TIME if lit else COLD_TIME
	if instant or not is_inside_tree():
		_apply_glow(to_lit, to_cold)
		return
	var from_lit := glow_lit
	var from_cold := glow_cold
	_glow_tween = create_tween()
	_glow_tween.tween_method(func(k: float) -> void:
		_apply_glow(lerpf(from_lit, to_lit, k), lerpf(from_cold, to_cold, k)), 0.0, 1.0, t)


## A brighter flare of the lit glow (Hot Hand): the pip cores burn hotter
## for a moment and the rim brightens (still under the bloom threshold).
func pulse_glow(seconds: float = 0.6) -> void:
	if not is_inside_tree():
		return
	var tw := create_tween().set_ignore_time_scale(true)
	tw.tween_method(func(k: float) -> void:
		glow_boost = sin(k * PI)
		_apply_glow(glow_lit, glow_cold), 0.0, 1.0, seconds)


## 0..1 extra brightness from pulse_glow.
var glow_boost: float = 0.0


func _apply_glow(lit: float, cold: float) -> void:
	glow_lit = lit
	glow_cold = cold
	body_material.set_shader_parameter("state_rim_energy", 0.85 + 0.13 * glow_boost)
	body_material.set_shader_parameter("die_lit", lit)
	body_material.set_shader_parameter("die_cold", cold)
	if pip_material == null:
		return
	# Cold pips are pulled 55% toward the (cold) body colour; lit pips go ember.
	var body_col: Color = body_material.get_shader_parameter("albedo")
	var cold_body := Color(body_col.get_luminance(), body_col.get_luminance() * 0.96, body_col.get_luminance() * 0.90) * Color(0.80, 0.78, 0.76)
	var pip := _pip_color.lerp(cold_body, COLD_PIP_TO_BODY * cold * (1.0 - lit))
	pip = pip.lerp(EMBER_MID, lit)
	pip_material.set_shader_parameter("albedo", pip)
	pip_material.set_shader_parameter("emission_color", EMBER_MID)
	pip_material.set_shader_parameter("emission_energy", PIP_MID_ENERGY * lit)
	pip_core_material.set_shader_parameter("energy", PIP_CORE_ENERGY * lit * (1.0 + 0.7 * glow_boost))
	for c in _pip_cores:
		c.visible = lit > 0.01


func _add_pips() -> void:
	if _pips_root != null:
		_pips_root.free()
	_pips_root = Node3D.new()
	_pips_root.name = "Pips"
	faces.add_child(_pips_root)
	var pip_mesh := CylinderMesh.new()
	var pr := 0.09 * edge
	pip_mesh.top_radius = pr
	pip_mesh.bottom_radius = pr * 0.8
	pip_mesh.height = 0.06 * edge
	pip_mesh.radial_segments = 12
	pip_mesh.rings = 1
	var pip_mat := Toon.mat(_pip_color, Color.BLACK, {"roughness": 0.8, "ambient_energy": 0.1})
	pip_material = pip_mat
	# The pip core: an unshaded disc (~55% of the pip radius) just above the
	# pip floor. It is what the Art Director's pip mask "G" channel meant;
	# our pips are real meshes, so no mask texture is needed.
	pip_core_material = Toon.fx(EMBER_CORE, 0.0, 1, false)
	var core_mesh := CylinderMesh.new()
	core_mesh.top_radius = pr * 0.55
	core_mesh.bottom_radius = pr * 0.55
	core_mesh.height = 0.005 * edge
	core_mesh.radial_segments = 12
	core_mesh.rings = 1
	_pip_cores.clear()
	var h := edge * 0.5
	for value: int in PIPS:
		var n := FACE_AXES[value] as Vector3
		var shown: int = labels[value - 1]
		var u := Vector3.UP if absf(n.y) < 0.5 else Vector3.RIGHT
		u = (u - n * u.dot(n)).normalized()
		var v := n.cross(u)
		for spot: Vector2 in PIPS[shown]:
			var mi := MeshInstance3D.new()
			mi.mesh = pip_mesh
			mi.material_override = pip_mat
			# Sunk into the face so only a dark "drilled" disc shows.
			var pos := n * (h - 0.02 * edge) + u * spot.x * PIP_STEP * edge + v * spot.y * PIP_STEP * edge
			mi.transform = Transform3D(Basis(u, n, u.cross(n)), pos)
			_pips_root.add_child(mi)
			var core := MeshInstance3D.new()
			core.name = "PipCore"
			core.mesh = core_mesh
			core.material_override = pip_core_material
			core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			core.position = Vector3(0, 0.031 * edge, 0)
			core.visible = false
			mi.add_child(core)
			_pip_cores.append(core)
	_apply_glow(glow_lit, glow_cold)
