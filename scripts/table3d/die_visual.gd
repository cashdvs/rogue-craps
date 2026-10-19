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
## &"d6" (the rounded cube) or &"coin" (Ferryman's Coin: a flat disc, heads
## on local +Y, tails on -Y; see CoinPhysics and make_coin()).
var shape: StringName = &"d6"
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
## A label list that isn't 6 long (a data mismatch) warns and is padded with
## the slot's own number / trimmed, so it can never index out of range.
func set_look(body: Color, pip: Color, slot_labels: Array[int]) -> void:
	labels = safe_labels(slot_labels)
	body_material.set_shader_parameter("albedo", body)
	body_material.set_shader_parameter("shadow_color", body.darkened(0.55))
	body_material.set_shader_parameter("emission_color", body)
	_pip_color = pip
	_add_pips()


## The number shown on top (the slot's label). A coin shows its slot:
## 1 = heads, 2 = tails.
func shown_value() -> int:
	if shape == &"coin":
		return up_slot()
	var i := up_value() - 1
	return labels[i] if i >= 0 and i < labels.size() else up_value()


## The face SLOT on top: a d6 face 1..6 (FACE_AXES), a coin 1 (heads, +Y
## up) or 2 (tails).
func up_slot() -> int:
	if shape == &"coin":
		return CoinPhysics.face_slot(faces.global_transform.basis)
	return up_value()


## The FACE_AXES id where face `slot` sits on this mesh (what remap_basis
## needs): itself on a d6 (clamped to 1..6), +Y (1) / -Y (6) on a coin.
func mesh_face(slot: int) -> int:
	if shape == &"coin":
		return CoinPhysics.axis_id(slot)
	return clampi(slot, 1, 6)


## Distance from the centre to the face along FACE_AXES[axis] (decals sit
## just above it): half the edge on a cube, half the thickness on a coin's
## round faces.
func face_half(axis: int) -> float:
	if shape == &"coin" and (axis == CoinPhysics.AXIS_ID_HEADS or axis == CoinPhysics.AXIS_ID_TAILS):
		return CoinPhysics.THICKNESS * 0.5
	return edge * 0.5


## Turns this die into Ferryman's Coin (procedural stand-in until the 3D
## Artist's ferryman_d2.glb lands on main): a 0.10 m x 0.024 m 18-sided
## disc, centred, with a brass HEADS face (+Y, a ring and a raised boss)
## and an oxblood TAILS face (-Y, a ring and a bar).
func make_coin() -> void:
	shape = &"coin"
	if _pips_root != null:
		_pips_root.free()
		_pips_root = null
	var body := faces.get_node("Body") as MeshInstance3D
	var cyl := CylinderMesh.new()
	cyl.top_radius = CoinPhysics.RADIUS
	cyl.bottom_radius = CoinPhysics.RADIUS
	cyl.height = CoinPhysics.THICKNESS
	cyl.radial_segments = 18
	cyl.rings = 1
	body.mesh = cyl
	body_material.set_shader_parameter("albedo", Palette.BRASS)
	body_material.set_shader_parameter("shadow_color", Palette.BRASS.darkened(0.55))
	body_material.set_shader_parameter("emission_color", Palette.BRASS)
	_pips_root = Node3D.new()
	_pips_root.name = "Pips"
	faces.add_child(_pips_root)
	var h := CoinPhysics.THICKNESS * 0.5
	var heads_mat := Toon.mat(Palette.BRASS_HI, Color.BLACK, {"roughness": 0.5, "ambient_energy": 0.2})
	var tails_mat := Toon.mat(Palette.BURGUNDY, Color.BLACK, {"roughness": 0.7, "ambient_energy": 0.1})
	for side in [1.0, -1.0]:
		var mat: Material = heads_mat if side > 0.0 else tails_mat
		# The ring near the rim.
		var ring := MeshInstance3D.new()
		ring.name = "HeadsRing" if side > 0.0 else "TailsRing"
		var tm := TorusMesh.new()
		tm.inner_radius = CoinPhysics.RADIUS * 0.70
		tm.outer_radius = CoinPhysics.RADIUS * 0.82
		tm.rings = 18
		tm.ring_segments = 6
		ring.mesh = tm
		ring.material_override = mat
		ring.scale = Vector3(1.0, 0.25, 1.0)
		ring.position = Vector3(0, side * h, 0)
		_pips_root.add_child(ring)
		var mark := MeshInstance3D.new()
		mark.material_override = mat
		if side > 0.0:
			# Heads: a raised round boss in the middle.
			var boss := CylinderMesh.new()
			boss.top_radius = CoinPhysics.RADIUS * 0.32
			boss.bottom_radius = CoinPhysics.RADIUS * 0.36
			boss.height = 0.003
			boss.radial_segments = 18
			mark.mesh = boss
			mark.name = "HeadsBoss"
		else:
			# Tails: a bar across the face.
			var bar := BoxMesh.new()
			bar.size = Vector3(CoinPhysics.RADIUS * 1.1, 0.003, CoinPhysics.RADIUS * 0.22)
			mark.mesh = bar
			mark.name = "TailsBar"
		mark.position = Vector3(0, side * (h + 0.0005), 0)
		_pips_root.add_child(mark)
	var blob := get_node("Blob") as MeshInstance3D
	(blob.mesh as QuadMesh).size = Vector2.ONE * CoinPhysics.RADIUS * 2.4


var _pip_color: Color = Palette.PIT_BLACK


## Highest printed value a face label can carry (a d20's 20).
const MAX_LABEL: int = 20


## `slot_labels` as exactly 6 labels (pad with the slot number, trim extras),
## warning when the input didn't fit. Values are kept as printed, 0..20:
## 0 is a blank face (no pips), 1-6 are pips, 7+ a printed numeral. They are
## NOT clamped to 1-6 any more (a 0 used to show as one pip, an 8 as a 6).
static func safe_labels(slot_labels: Array) -> Array[int]:
	var out: Array[int] = [1, 2, 3, 4, 5, 6]
	if slot_labels.size() != 6:
		push_warning("DieVisual: %d face labels for a 6-faced mesh; padding / trimming to 6" % slot_labels.size())
	for i in mini(slot_labels.size(), 6):
		out[i] = clampi(int(slot_labels[i]), 0, MAX_LABEL)
	return out


## A printed number (7..20) on the face with normal `n` (`u` = face "up").
func _add_numeral(n: Vector3, u: Vector3, h: float, value: int) -> void:
	var lab := Label3D.new()
	lab.name = "Numeral%d" % value
	lab.text = str(value)
	lab.font_size = 96
	lab.pixel_size = edge * 0.005
	lab.modulate = _pip_color
	lab.outline_size = 0
	lab.double_sided = false
	# Label3D faces +Z: turn it so +Z points out of the face, `u` reads up.
	lab.transform = Transform3D(Basis(u.cross(n), u, n), n * (h + 0.002 * edge))
	_pips_root.add_child(lab)


## Pip discs drawn on face `axis` (cube axis id 1..6); 0 for a blank face.
func pip_count(axis: int) -> int:
	if _pips_root == null:
		return 0
	var n := FACE_AXES.get(axis, Vector3.ZERO) as Vector3
	var count := 0
	for c in _pips_root.get_children():
		if c is MeshInstance3D and (c as Node3D).position.normalized().dot(n) > 0.6:
			count += 1
	return count


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
	var h := edge * 0.5
	for value: int in PIPS:
		var n := FACE_AXES[value] as Vector3
		var shown: int = clampi(labels[value - 1], 0, MAX_LABEL) if value - 1 < labels.size() else value
		var u := Vector3.UP if absf(n.y) < 0.5 else Vector3.RIGHT
		u = (u - n * u.dot(n)).normalized()
		var v := n.cross(u)
		if shown == 0:
			# A 0 face (e.g. a coin's Tails value) is blank: plain bone, no pips.
			continue
		if shown > 6:
			# More than six pips won't fit: print the number on the face.
			_add_numeral(n, u, h, shown)
			continue
		for spot: Vector2 in PIPS[shown]:
			var mi := MeshInstance3D.new()
			mi.mesh = pip_mesh
			mi.material_override = pip_mat
			# Sunk into the face so only a dark "drilled" disc shows.
			var pos := n * (h - 0.02 * edge) + u * spot.x * PIP_STEP * edge + v * spot.y * PIP_STEP * edge
			mi.transform = Transform3D(Basis(u, n, u.cross(n)), pos)
			_pips_root.add_child(mi)
