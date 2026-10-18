## A clay chip (poc_3d.md section 4): a 0.055 m x 0.006 m cylinder with 8
## edge notches and an inset ring, drawn by the toon shader's chip mode.
## Denomination colors: 1 bone, 5 crimson, 25 felt green, 100 brass.
class_name Chip3D
extends MeshInstance3D

const RADIUS: float = 0.0275
const THICK: float = 0.006
## Stack step (spec: chip i sits at y = i * 0.0062).
const STEP: float = 0.0062
const COLORS: Dictionary = {
	1: [Color("#E8DCC0"), Color("#0E1414"), Color("#BFAF8E")],
	5: [Color("#A3242E"), Color("#E8DCC0"), Color("#6E1A24")],
	25: [Color("#2E7D5B"), Color("#E8DCC0"), Color("#123A36")],
	100: [Color("#B08D3C"), Color("#0E1414"), Color("#E2C06A")],
}

static var _mesh: CylinderMesh
static var _materials: Dictionary = {}

var value: int = 5


static func make(v: int) -> Chip3D:
	var c := Chip3D.new()
	c.value = v
	if _mesh == null:
		_mesh = Toon.cylinder(RADIUS, THICK, 24)
	c.mesh = _mesh
	c.material_override = material_for(v)
	return c


static func material_for(v: int) -> ShaderMaterial:
	var key := v if COLORS.has(v) else 5
	if not _materials.has(key):
		var cols: Array = COLORS[key]
		var m := Toon.inked(cols[0], (cols[0] as Color) * 0.35, Toon.INK_CHIP, {
			"chip_mode": true, "notch_color": cols[1], "ring_color": cols[2],
			"chip_radius": RADIUS, "roughness": 0.85, "mid_tint": 0.7,
		}, 1)
		_materials[key] = m
	return _materials[key]
