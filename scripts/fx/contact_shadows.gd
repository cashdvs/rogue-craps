## Lighting layer 4 (lighting_layers_spec.md section 4): a soft black contact
## blob under every table die. One flat quad per die on the felt (y 0.002),
## following the die's XZ but never its rotation, so it can only land on the
## felt and never on another die (that is why it is a quad and not a Decal on
## Forward+ too: a Decal would need the dice on their own cull layer).
## It never touches the die: it only reads the die's global_position, and its
## own material is the only one it writes.
## As the die rises (h = centre above rest) the blob grows up to +60% and
## fades; it is hidden above 0.25 m, while the dice are held, and for potted
## dice. It replaces the die's old built-in "Blob" quad (hidden, not freed).
class_name ContactShadows
extends Node3D

## Diameter at rest, as a multiple of the die edge.
const SIZE_MUL: float = 1.6
## Peak alpha at rest per renderer.
const ALPHA_FPLUS: float = 0.55
const ALPHA_COMPAT: float = 0.65
## Above this height (m, die centre above rest) the blob is hidden.
const MAX_H: float = 0.25
## Extra scale at MAX_H.
const GROW: float = 0.6
const FELT_Y: float = 0.002
## Nudge toward -x/+z (the lamp is straight above, so nearly centred).
const OFFSET := Vector2(-0.01, 0.01)
const TEX_SIZE: int = 64

var table: Node
var forward_plus: bool = true
## die instance id -> MeshInstance3D
var _blobs: Dictionary = {}
static var _tex: ImageTexture


func _init() -> void:
	name = "ContactShadows"


## 0..1 rise factor for height h (m).
static func rise(h: float) -> float:
	return clampf(h / MAX_H, 0.0, 1.0)


static func rest_alpha(fplus: bool) -> float:
	return ALPHA_FPLUS if fplus else ALPHA_COMPAT


## Blob alpha at height h on this renderer (0 once hidden).
static func alpha_at(h: float, fplus: bool) -> float:
	if not visible_at(h):
		return 0.0
	return rest_alpha(fplus) * (1.0 - rise(h))


## Blob scale multiplier at height h (1 at rest, 1.6 at MAX_H).
static func scale_at(h: float) -> float:
	return 1.0 + GROW * rise(h)


static func visible_at(h: float) -> bool:
	return h <= MAX_H


## The 64 px blob: black, alpha 1 inside r 0.35, smoothstep falloff to 0 at r 1.
static func blob_texture() -> ImageTexture:
	if _tex != null:
		return _tex
	var img := Image.create(TEX_SIZE, TEX_SIZE, false, Image.FORMAT_RGBA8)
	var c := (TEX_SIZE - 1) * 0.5
	for y in TEX_SIZE:
		for x in TEX_SIZE:
			var r := Vector2(x - c, y - c).length() / c
			img.set_pixel(x, y, Color(0, 0, 0, 1.0 - smoothstep(0.35, 1.0, r)))
	_tex = ImageTexture.create_from_image(img)
	return _tex


func bind(t: Node, fplus: bool) -> void:
	table = t
	forward_plus = fplus


func blob_for(die: Node3D) -> MeshInstance3D:
	return _blobs.get(die.get_instance_id()) as MeshInstance3D


func _make_blob(die: Node3D) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.name = "ContactBlob"
	var q := QuadMesh.new()
	var edge := float(die.get("edge")) if "edge" in die else 0.08
	q.size = Vector2.ONE * edge * SIZE_MUL
	q.orientation = PlaneMesh.FACE_Y
	m.mesh = q
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = blob_texture()
	mat.albedo_color = Color(0, 0, 0, rest_alpha(forward_plus))
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.no_depth_test = false
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.top_level = true
	add_child(m)
	# The die's own old blob would double up: hide it (node only).
	var old := die.get_node_or_null("Blob") as Node3D
	if old != null:
		old.visible = false
	_blobs[die.get_instance_id()] = m
	return m


func _dice() -> Array:
	var out: Array = []
	if table == null or not is_instance_valid(table):
		return out
	var d: Variant = table.get("dice")
	if d is Array:
		out.append_array(d)
	for key in [&"throw_dice", &"all_dice"]:
		var t: Variant = table.get(key)
		if t is Array:
			for x in t:
				if not out.has(x):
					out.append(x)
	return out


func _hidden_set() -> Array:
	var p: Variant = table.get("pot_dice") if table != null else null
	return p if p is Array else []


func _held() -> bool:
	if table == null or not ("phase" in table):
		return false
	return int(table.get("phase")) == Table3D.Phase.HELD


func _process(_delta: float) -> void:
	update_now()


## One pass over the dice (tests call this directly).
func update_now() -> void:
	var potted := _hidden_set()
	var held := _held()
	var live := {}
	for d in _dice():
		if not (d is Node3D) or not is_instance_valid(d) or not d.is_inside_tree():
			continue
		var die := d as Node3D
		var b := blob_for(die)
		if b == null:
			b = _make_blob(die)
		live[die.get_instance_id()] = true
		var edge := float(die.get("edge")) if "edge" in die else 0.08
		var h := die.global_position.y - edge * 0.5
		var show := die.is_visible_in_tree() and not held and not potted.has(die) and visible_at(h)
		b.visible = show
		if not show:
			continue
		var p := die.global_position
		b.global_position = Vector3(p.x + OFFSET.x, FELT_Y, p.z + OFFSET.y)
		b.scale = Vector3.ONE * scale_at(h)
		(b.material_override as StandardMaterial3D).albedo_color.a = alpha_at(h, forward_plus)
	for id in _blobs.keys():
		if not live.has(id):
			(_blobs[id] as Node).queue_free()
			_blobs.erase(id)
