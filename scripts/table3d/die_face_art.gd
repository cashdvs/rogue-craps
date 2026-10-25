## DieVisual's look: the cube / coin meshes, the face table (FACE_AXES,
## PIPS) and the pips, blank faces and printed numerals. DieVisual extends
## this; split out only to keep each file short (no behaviour of its own).
class_name DieFaceArt
extends Node3D

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

## Turns this die into Ferryman's Coin (procedural stand-in until the 3D
## Artist's ferryman_d2.glb lands on main): a 0.10 m x 0.024 m 18-sided
## disc, centred, with a brass HEADS face (+Y, a ring and a raised boss)
## and an oxblood TAILS face (-Y, a ring and a bar).
func make_coin() -> void:
	shape = &"coin"
	if _pips_root != null:
		_pips_root.free()
		_pips_root = null
		_pip_cores.clear()  # their pip cores went with them
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
## The pip material (all pips of this die share it) and the small hot "core"
## disc inside each pip. Only the core is bright enough to bloom.
var pip_material: ShaderMaterial
var pip_core_material: ShaderMaterial
var _pip_cores: Array[MeshInstance3D] = []

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
	# Light (bone-ink) pips on dark dice shade toward their own colour, not
	# black: a black shadow under the warm lamp read as a reddish cast (AD #162).
	var pip_shadow := _pip_color.darkened(0.25) if _pip_color.get_luminance() > 0.5 else Color.BLACK
	var pip_mat := Toon.mat(_pip_color, pip_shadow, {"roughness": 0.8, "ambient_energy": 0.1} if pip_shadow == Color.BLACK else {"roughness": 0.8, "ambient_energy": 0.6, "ambient_color": _pip_color, "mid_tint": 1.0})
	pip_material = pip_mat
	# The pip core: an unshaded disc (~55% of the pip radius) just above the
	# pip floor. It is what the Art Director's pip mask "G" channel meant;
	# our pips are real meshes, so no mask texture is needed.
	pip_core_material = Toon.fx(Color(1.000, 0.902, 0.659), 0.0, 1, false)
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
			var core := MeshInstance3D.new()
			core.name = "PipCore"
			core.mesh = core_mesh
			core.material_override = pip_core_material
			core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			core.position = Vector3(0, 0.031 * edge, 0)
			core.visible = false
			mi.add_child(core)
			_pip_cores.append(core)
	# New pips start in the die's current lit / cold look (DieVisual).
	_apply_glow(glow_lit, glow_cold)


## Lit / cold look hook: DieVisual overrides it (the art alone has none).
var glow_lit: float = 0.0
var glow_cold: float = 0.0


func _apply_glow(_lit: float, _cold: float) -> void:
	pass
