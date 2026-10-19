## One bone die you can SEE (poc_3d.md section 3): a 0.08 m rounded cube with
## dark pips and an ink outline. It has no physics of its own: during a throw
## it copies the transform of an invisible RigidBody3D (see DiceSim), and its
## inner `faces` node can be turned to any of the 24 cube orientations so the
## face the seeded DiceRoller picked is the one that ends up on top.
##
## Face layout (opposite faces sum to 7), in the die's local space:
##   +Y = 1, -Y = 6, +X = 2, -X = 5, +Z = 3, -Z = 4
## (Meshes, face table and pips: DieFaceArt.)
class_name DieVisual
extends DieFaceArt

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
