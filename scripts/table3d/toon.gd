## Material factory for the 3D table: every opaque prop uses the one
## toon-noir shader (shaders/3d/toon_noir.gdshader) with per-material colors,
## plus an optional inverted-hull ink outline (shaders/3d/outline.gdshader).
## Colors and outline widths follow art/concept/poc_3d.md sections 8 and 2.
class_name Toon
extends RefCounted

const TOON_SHADER := preload("res://shaders/3d/toon_noir.gdshader")
const OUTLINE_SHADER := preload("res://shaders/3d/outline.gdshader")
const FX_SHADER := preload("res://shaders/3d/fx_unshaded.gdshader")

## Shadow colors from the palette -> material table.
const SHADOW_WARM := Color("#2A0A10")   # oxblood-black (default)
const SHADOW_TEAL := Color("#05100F")   # pit-teal-black (felt)
const SHADOW_BONE := Color("#8E7A5C")   # dice: warm, never grey
const SHADOW_BRASS := Color("#3A2A10")
const SHADOW_WOOD := Color("#140A06")

## Outline widths in meters (1 px ~ 0.0015 m at the felt at 1080p).
const INK_DICE: float = 0.0042
const INK_CHIP: float = 0.0030
const INK_TABLE: float = 0.0050
const INK_DEALER: float = 0.0065


## A toon material. `opts` may set any shader uniform by name, e.g.
## {"spec_size": 0.97, "wrap": 0.35, "rim_strength": 0.25}.
static func mat(albedo: Color, shadow: Color = SHADOW_WARM, opts: Dictionary = {}) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = TOON_SHADER
	m.set_shader_parameter("albedo", albedo)
	m.set_shader_parameter("shadow_color", shadow)
	for k: String in opts:
		m.set_shader_parameter(k, opts[k])
	return m


## Same as mat() but with an ink outline drawn as the material's next pass.
## mode 0 = push along smooth normals, 1 = push away from the mesh center.
static func inked(albedo: Color, shadow: Color, width: float, opts: Dictionary = {}, mode: int = 0) -> ShaderMaterial:
	var m := mat(albedo, shadow, opts)
	m.next_pass = outline(width, mode)
	return m


static func outline(width: float, mode: int = 0, color: Color = Palette.PIT_BLACK) -> ShaderMaterial:
	var o := ShaderMaterial.new()
	o.shader = OUTLINE_SHADER
	o.set_shader_parameter("width", width)
	o.set_shader_parameter("mode", mode)
	o.set_shader_parameter("color", color)
	return o


## Unshaded FX material (sparks, embers, smoke, glow cones, walls).
## shape: 0 soft dot, 1 flat, 2 vertical gradient, 3 smoke sheet.
static func fx(tint: Color, energy: float = 1.0, shape: int = 0, additive: bool = true) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = FX_SHADER
	m.set_shader_parameter("tint", tint)
	m.set_shader_parameter("energy", energy)
	m.set_shader_parameter("shape", shape)
	if additive:
		# A blend_add variant: Godot shaders fix blend mode at compile time,
		# so additive FX use a tiny duplicated shader with blend_add.
		m.shader = _additive_shader()
	return m


static var _add_shader: Shader


static func _additive_shader() -> Shader:
	if _add_shader == null:
		_add_shader = Shader.new()
		_add_shader.code = FX_SHADER.code.replace("render_mode unshaded,", "render_mode blend_add, unshaded,")
	return _add_shader


## A MeshInstance3D with a mesh and material, positioned, added to parent.
static func add_mesh(parent: Node, mesh: Mesh, material: Material, pos: Vector3 = Vector3.ZERO, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	mi.rotation_degrees = rot_deg
	parent.add_child(mi)
	return mi


static func box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


static func cylinder(radius: float, height: float, sides: int = 24, top_radius: float = -1.0) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.bottom_radius = radius
	c.top_radius = radius if top_radius < 0.0 else top_radius
	c.height = height
	c.radial_segments = sides
	c.rings = 1
	return c


static func sphere(radius: float, segments: int = 16) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = radius
	s.height = radius * 2.0
	s.radial_segments = segments
	s.rings = maxi(segments / 2, 4)
	return s
