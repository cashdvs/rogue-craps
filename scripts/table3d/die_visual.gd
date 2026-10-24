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
var material: String = "bone":
	set(v):
		material = v
		_update_hull_outline()
		if body_material != null:
			_apply_glow(glow_lit, glow_cold)

## Playtest fix (PM + AD): the lit cue. Every family gets the same
## inverted-hull ember outline, 0.015 m #E8622A, emission 0.6, shown only
## while lit (AD #162: also replaces glass's old dark #2A2018 ink outline).
## A dimmed die (lit but can't join the selection, SelectionDimFx) keeps it
## at DIM_OUTLINE_ALPHA with no emission; plain and cold dice show none.
const HULL_OUTLINE := {"width": 0.015, "color": Color("#E8622A"), "emission": 0.6}
const HULL_OUTLINE_FAMILIES := {
	"bone": HULL_OUTLINE,
	"brass": HULL_OUTLINE,
	"wood": HULL_OUTLINE,
	"obsidian": HULL_OUTLINE,
	"frosted_glass": HULL_OUTLINE,
}
const DIM_OUTLINE_ALPHA := 0.25
## True while SelectionDimFx shows this die dimmed (see set_dimmed).
var outline_dimmed: bool = false
## Lit rim energy per family (default STATE_RIM_ENERGY).
const FAMILY_RIM_ENERGY := {"wood": 1.0, "obsidian": 1.0}
## Families whose lit look adds no warm body tint (shader lit_albedo_mix_max 0).
const NO_LIT_TINT_FAMILIES: Array[String] = ["wood", "obsidian"]
const LIT_ALBEDO_MIX_MAX := 0.35
var hull_outline: MeshInstance3D

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
	_update_hull_outline()
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


# --- Lit / cold readability state (design section 4, art/ui/readability) -----------
## The ember colours from the Art Director's die_state_reference.gdshader.
const EMBER_MID := Color(0.910, 0.384, 0.165)   # #E8622A
const EMBER_CORE := Color(1.000, 0.902, 0.659)  # #FFE6A8
## Playtest fix: lit dice read by a thin ember rim only; pips stay dark ink.
const PIP_MID_ENERGY := 0.0
const PIP_CORE_ENERGY := 0.0
## Base lit rim energy (matches toon_noir state_rim_energy); Hot Hand adds +0.13.
const STATE_RIM_ENERGY := 0.6
const COLD_PIP_TO_BODY := 0.55
## Tween times: lighting up is snappy, going cold is a little slower.
const LIT_TIME := 0.08
const COLD_TIME := 0.15
## 0..1: how "lit" (scoring) and how "cold" (not scoring) this die looks.
var _glow_tween: Tween


## Shows the die as lit (scoring), cold (didn't score) or plain (both false).
## Material only: no lights, no particles. `instant` skips the tween.
func set_glow_state(lit: bool, cold: bool, instant: bool = false) -> void:
	outline_dimmed = false
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


## Dimmed (lit but can't join the selection): the plain body look plus the
## hull outline at DIM_OUTLINE_ALPHA, emission 0. Any set_glow_state ends it.
func set_dimmed(instant: bool = false) -> void:
	set_glow_state(false, false, instant)
	outline_dimmed = true
	_apply_outline_state()


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


## Called by DieFaceArt._add_pips once the pips (and their cores) exist.
func _apply_glow(lit: float, cold: float) -> void:
	glow_lit = lit
	glow_cold = cold
	body_material.set_shader_parameter("state_rim_energy", rim_energy_for(material) + 0.13 * glow_boost)
	body_material.set_shader_parameter("lit_albedo_mix_max", 0.0 if material in NO_LIT_TINT_FAMILIES else LIT_ALBEDO_MIX_MAX)
	body_material.set_shader_parameter("die_lit", lit)
	body_material.set_shader_parameter("die_cold", cold)
	if pip_material == null:
		return
	# Cold pips are pulled 55% toward the (cold) body colour; lit pips keep their ink.
	var body_col: Color = body_material.get_shader_parameter("albedo")
	var cold_body := Color(body_col.get_luminance(), body_col.get_luminance() * 0.96, body_col.get_luminance() * 0.90) * Color(0.80, 0.78, 0.76)
	var pip := _pip_color.lerp(cold_body, COLD_PIP_TO_BODY * cold * (1.0 - lit))
	pip_material.set_shader_parameter("albedo", pip)
	pip_material.set_shader_parameter("emission_color", EMBER_MID)
	pip_material.set_shader_parameter("emission_energy", PIP_MID_ENERGY * lit)
	pip_core_material.set_shader_parameter("energy", PIP_CORE_ENERGY * lit * (1.0 + 0.7 * glow_boost))
	for c in _pip_cores:
		c.visible = PIP_CORE_ENERGY > 0.0 and lit > 0.01
	_apply_outline_state()


## Outline: full while lit, faint and non-emissive while dimmed, else hidden.
func _apply_outline_state() -> void:
	if hull_outline == null:
		return
	var m := hull_outline.material_override as StandardMaterial3D
	var spec: Dictionary = HULL_OUTLINE_FAMILIES.get(material, HULL_OUTLINE)
	var dim := outline_dimmed and glow_lit <= 0.01
	hull_outline.visible = glow_lit > 0.01 or dim
	m.albedo_color.a = DIM_OUTLINE_ALPHA if dim else 1.0
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if dim else BaseMaterial3D.TRANSPARENCY_DISABLED
	m.emission_energy_multiplier = 0.0 if dim else float(spec["emission"])


## Whether this die's material family takes the lit hull outline.
static func has_hull_outline(family: String) -> bool:
	return HULL_OUTLINE_FAMILIES.has(family)


## The lit rim energy for a material family.
static func rim_energy_for(family: String) -> float:
	return float(FAMILY_RIM_ENERGY.get(family, STATE_RIM_ENERGY))


## Adds or removes the inverted-hull outline for the current family.
func _update_hull_outline() -> void:
	if faces == null:
		return
	if hull_outline != null and hull_outline.get_meta("family", "") != material:
		hull_outline.queue_free()
		hull_outline = null
	if not has_hull_outline(material):
		if hull_outline != null:
			hull_outline.queue_free()
			hull_outline = null
		return
	if hull_outline == null:
		var spec: Dictionary = HULL_OUTLINE_FAMILIES[material]
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.cull_mode = BaseMaterial3D.CULL_FRONT
		m.albedo_color = spec["color"]
		m.emission_enabled = float(spec["emission"]) > 0.0
		m.emission = spec["color"]
		m.emission_energy_multiplier = float(spec["emission"])
		m.grow = true
		m.grow_amount = float(spec["width"])
		hull_outline = MeshInstance3D.new()
		hull_outline.name = "HullOutline"
		hull_outline.set_meta("family", material)
		hull_outline.mesh = (faces.get_node("Body") as MeshInstance3D).mesh
		hull_outline.material_override = m
		hull_outline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		faces.add_child(hull_outline)
	_apply_outline_state()


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
	if PolyDie.has_shape(shape):
		# A hull die (d4 .. d20, talus, keg): the face direction pointing up.
		return PolyDie.up_slot(shape, faces.global_transform.basis)
	return up_value()


## Shows face [param slot] (1-based, as on TableDie) on top of this settled
## die, by turning its inner `faces` node; the die itself (and its frozen
## physics body) stays where it landed. Used by Nerve (nerve_v1.md) and
## any rule that changes a face after the dice settle.
##   animate = true: a short hop-and-turn tween (FACE_TURN_TIME seconds);
##   false: snaps at once. The table passes false under reduced motion and
##   at Instant speed. Returns the faces node's final rotation.
## Cube and coin: their FACE_AXES ids (mesh_face). A hull die: its face
## direction table (PolyDie.dirs), so it works for d4 .. d20 too.
func set_face(slot: int, animate: bool = true) -> Quaternion:
	var to := face_rotation(slot)
	if face_tween != null and face_tween.is_valid():
		face_tween.kill()
	if not animate or not is_inside_tree():
		faces.quaternion = to
		return to
	var from := faces.quaternion
	var base := faces.position
	face_tween = create_tween()
	face_tween.tween_method(func(k: float) -> void:
		faces.quaternion = from.slerp(to, k)
		faces.position = base + Vector3(0, sin(k * PI) * edge * 0.5, 0), 0.0, 1.0, FACE_TURN_TIME)
	face_tween.tween_callback(func() -> void:
		faces.position = base
		faces.quaternion = to)
	return to


## Seconds set_face's turn takes when animated.
const FACE_TURN_TIME: float = 0.25
## The running set_face tween (killed by the next set_face), or null.
var face_tween: Tween


## The `faces` node rotation (local to the die) that puts face [param slot]
## on top for the die's current pose.
func face_rotation(slot: int) -> Quaternion:
	var outer := global_transform.basis.orthonormalized() if is_inside_tree() else transform.basis.orthonormalized()
	if PolyDie.has_shape(shape):
		var shown := PolyDie.remap_basis(shape, outer, slot)
		return (outer.inverse() * shown).orthonormalized().get_rotation_quaternion()
	return DieVisual.remap_basis(DieVisual.value_up(outer), mesh_face(slot)).get_rotation_quaternion()


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
