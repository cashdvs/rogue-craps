## Builds the Floor 1 back-room table in greybox (poc_3d.md section 2):
## felt bed, padded oxblood rails, brass trim and caps, the dealer-side
## backboard, wood apron, and cheap room dressing (walls, floor, a bar
## silhouette, ashtray, glass, scattered chips). Also adds the colliders the
## physics dice bounce off. Units: meters, felt surface at y = 0.
##
## The final Blender table (tufting dimples, vertex-color grime) is a later
## build-order step (poc_3d.md 12, step 8); this is the CSG-style blockout.
class_name Table3DBuilder
extends RefCounted

## Half size of the felt bed inside the rails (2.04 x 1.04 m).
const FELT_HALF := Vector2(1.02, 0.52)
const RAIL_RADIUS: float = 0.09
const RAIL_Y: float = 0.02  # rail tube center -> top at y = 0.11
const BACKBOARD_H: float = 0.06
const POINT_NUMBERS: Array[int] = [4, 5, 6, 8, 9, 10]
const BOX_SIZE := Vector2(0.24, 0.18)
const BOX_ROW_Z: float = -0.30
## Pass Line ellipse (x, z radii) around PASS_CENTER (x, z).
const PASS_CENTER := Vector2(0.0, -0.05)
const PASS_INNER := Vector2(0.86, 0.36)
const PASS_OUTER := Vector2(0.98, 0.50)
const BET_SPOT := Vector3(-0.35, 0.0, 0.40)
const PUCK_OFF := Vector3(-0.96, 0.0, -0.30)
const PAYOUT_ORIGIN := Vector3(0.0, 0.0, -0.48)
const RAKE_ENTRY := Vector3(0.3, 0.0, -0.55)
const BANKROLL := Vector3(-0.9, 0.11, 0.62)

var root: Node3D
var felt_material: ShaderMaterial
var felt_print: FeltPrint


static func point_box_center(n: int) -> Vector3:
	var i := POINT_NUMBERS.find(n)
	if i < 0:
		return PUCK_OFF
	var x := -0.795 + BOX_SIZE.x * 0.5 + i * (BOX_SIZE.x + 0.03)
	return Vector3(x, 0.0, BOX_ROW_Z)


## Is a felt point (x, z) on the Pass Line band or its bet spot?
static func pass_contains(x: float, z: float) -> bool:
	if Vector2(x, z).distance_to(Vector2(BET_SPOT.x, BET_SPOT.z)) < 0.08:
		return true
	var dx := x - PASS_CENTER.x
	var dz := -(z - PASS_CENTER.y)  # the art spec's top view has y = -z
	var outer := (dx * dx) / (PASS_OUTER.x * PASS_OUTER.x) + (dz * dz) / (PASS_OUTER.y * PASS_OUTER.y)
	var inner := (dx * dx) / (PASS_INNER.x * PASS_INNER.x) + (dz * dz) / (PASS_INNER.y * PASS_INNER.y)
	var a := fposmod(rad_to_deg(atan2(dz / PASS_OUTER.y, dx / PASS_OUTER.x)), 360.0)
	return outer <= 1.0 and inner >= 1.0 and a >= 200.0 and a <= 340.0


func build(parent: Node3D, tuning: TuningData) -> void:
	root = Node3D.new()
	root.name = "Table"
	parent.add_child(root)
	_build_felt(tuning)
	_build_rails(tuning)
	_build_apron()
	_build_walls_for_dice(tuning)
	_build_room()
	_build_props()


# --- Felt -----------------------------------------------------------------------

func _build_felt(tuning: TuningData) -> void:
	felt_print = FeltPrint.make()
	root.add_child(felt_print.viewport)
	felt_material = Toon.mat(Palette.UNDERFELT, Toon.SHADOW_TEAL, {
		"rim_color": Color("#2E6A62"), "rim_power": 3.0, "rim_strength": 0.25,
		"roughness": 0.95, "grime": 0.85, "use_overlay": true, "mid_tint": 0.7,
	})
	felt_material.set_shader_parameter("overlay_tex", felt_print.viewport.get_texture())
	var plane := PlaneMesh.new()
	plane.size = FELT_HALF * 2.0
	plane.subdivide_width = 16
	plane.subdivide_depth = 8
	Toon.add_mesh(root, plane, felt_material).name = "Felt"
	# Felt collider: a thick slab with its top at y = 0.
	var mat := PhysicsMaterial.new()
	mat.friction = tuning.felt_friction
	mat.bounce = tuning.felt_bounce
	_static_box("FeltCollider", Vector3(FELT_HALF.x * 2.0 + 0.4, 0.2, FELT_HALF.y * 2.0 + 0.4), Vector3(0, -0.1, 0), mat, &"felt")
	# Backboard (dealer side): a low felt-wrapped wall the dice bounce off.
	var rail_mat := PhysicsMaterial.new()
	rail_mat.friction = tuning.rail_friction
	rail_mat.bounce = tuning.rail_bounce
	var bb_size := Vector3(FELT_HALF.x * 2.0, BACKBOARD_H, 0.03)
	var bb_pos := Vector3(0, BACKBOARD_H * 0.5, -FELT_HALF.y + 0.015)
	_static_box("Backboard", bb_size, bb_pos, rail_mat, &"backboard")
	var bb_mat := Toon.inked(Palette.UNDERFELT.darkened(0.15), Toon.SHADOW_TEAL, Toon.INK_TABLE * 0.6, {"roughness": 0.95}, 1)
	Toon.add_mesh(root, Toon.box(bb_size), bb_mat, bb_pos).name = "BackboardMesh"


# --- Rails, trim, caps -------------------------------------------------------------

func _build_rails(tuning: TuningData) -> void:
	var leather := Toon.inked(Color("#5A1620"), Toon.SHADOW_WARM, Toon.INK_TABLE, {
		"rim_color": Color("#8A3A40"), "rim_strength": 0.15, "roughness": 0.55, "mid_tint": 0.68,
	})
	var brass := Toon.inked(Palette.BRASS, Toon.SHADOW_BRASS, Toon.INK_TABLE * 0.6, {
		"spec_size": 0.92, "spec_color": Palette.BRASS_HI, "roughness": 0.35,
	}, 1)
	var mat := PhysicsMaterial.new()
	mat.friction = tuning.rail_friction
	mat.bounce = tuning.rail_bounce
	var ox := FELT_HALF.x + RAIL_RADIUS
	var oz := FELT_HALF.y + RAIL_RADIUS
	# name, center, length, along X?
	var rails := [
		["RailFar", Vector3(0, RAIL_Y, -oz), FELT_HALF.x * 2.0, true],
		["RailNear", Vector3(0, RAIL_Y, oz), FELT_HALF.x * 2.0, true],
		["RailLeft", Vector3(-ox, RAIL_Y, 0), FELT_HALF.y * 2.0, false],
		["RailRight", Vector3(ox, RAIL_Y, 0), FELT_HALF.y * 2.0, false],
	]
	for r: Array in rails:
		var along_x: bool = r[3]
		var rot := Vector3(0, 0, 90) if along_x else Vector3(90, 0, 0)
		var mesh := Toon.cylinder(RAIL_RADIUS, r[2], 20)
		Toon.add_mesh(root, mesh, leather, r[1], rot).name = r[0]
		var body := StaticBody3D.new()
		body.name = String(r[0]) + "Collider"
		body.physics_material_override = mat
		body.set_meta("surface", &"rail")
		body.position = r[1]
		body.rotation_degrees = rot
		var cs := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = RAIL_RADIUS
		cyl.height = r[2]
		cs.shape = cyl
		body.add_child(cs)
		root.add_child(body)
		# Tufting buttons along the rail top (tiny brass studs every 0.20 m).
		var n := int(float(r[2]) / 0.2)
		for k in n:
			var off := -float(r[2]) * 0.5 + 0.1 + k * 0.2
			var p: Vector3 = r[1] + (Vector3(off, 0, 0) if along_x else Vector3(0, 0, off))
			p.y = RAIL_Y + RAIL_RADIUS - 0.004
			Toon.add_mesh(root, Toon.sphere(0.008, 8), brass, p)
	# Rounded corners + brass corner caps.
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var c := Vector3(sx * ox, RAIL_Y, sz * oz)
			Toon.add_mesh(root, Toon.sphere(RAIL_RADIUS, 20), leather, c)
			var cap := Toon.add_mesh(root, Toon.box(Vector3(0.16, 0.02, 0.16)), brass, c + Vector3(0, RAIL_RADIUS - 0.002, 0))
			cap.name = "BrassCap"
			for s in 3:
				var a := TAU * s / 3.0 + 0.4
				Toon.add_mesh(root, Toon.cylinder(0.008, 0.006, 8), brass, cap.position + Vector3(cos(a) * 0.05, 0.012, sin(a) * 0.05))
	# Brass trim band where the rail meets the felt.
	var t := 0.012
	Toon.add_mesh(root, Toon.box(Vector3(FELT_HALF.x * 2.0, 0.008, t)), brass, Vector3(0, 0.004, FELT_HALF.y + t * 0.5))
	Toon.add_mesh(root, Toon.box(Vector3(t, 0.008, FELT_HALF.y * 2.0)), brass, Vector3(-FELT_HALF.x - t * 0.5, 0.004, 0))
	Toon.add_mesh(root, Toon.box(Vector3(t, 0.008, FELT_HALF.y * 2.0)), brass, Vector3(FELT_HALF.x + t * 0.5, 0.004, 0))
	Toon.add_mesh(root, Toon.box(Vector3(FELT_HALF.x * 2.0, 0.008, t)), brass, Vector3(0, BACKBOARD_H + 0.004, -FELT_HALF.y + 0.015))


func _build_apron() -> void:
	var wood := Toon.inked(Palette.RIM_WOOD, Toon.SHADOW_WOOD, Toon.INK_TABLE, {"roughness": 0.7, "grime": 0.3, "grime_color": Color("#2A1A12")}, 1)
	var h := 0.28
	var y := -0.02 - h * 0.5
	var w := 2.40
	var d := 1.40
	var th := 0.04
	Toon.add_mesh(root, Toon.box(Vector3(w, h, th)), wood, Vector3(0, y, d * 0.5 - th * 0.5)).name = "ApronNear"
	Toon.add_mesh(root, Toon.box(Vector3(w, h, th)), wood, Vector3(0, y, -d * 0.5 + th * 0.5)).name = "ApronFar"
	Toon.add_mesh(root, Toon.box(Vector3(th, h, d)), wood, Vector3(-w * 0.5 + th * 0.5, y, 0))
	Toon.add_mesh(root, Toon.box(Vector3(th, h, d)), wood, Vector3(w * 0.5 - th * 0.5, y, 0))
	# Under-rail wood deck filling between felt and apron.
	Toon.add_mesh(root, Toon.box(Vector3(w, 0.03, d)), wood, Vector3(0, -0.035, 0))
	# The base, lost in the dark.
	Toon.add_mesh(root, Toon.box(Vector3(1.8, 0.6, 0.9)), Toon.mat(Color("#0B0708"), Color.BLACK), Vector3(0, -0.6, 0))


## Invisible walls above the felt edges and a ceiling: dice can never leave
## the table, even off a wild bounce (the rails handle the visible bounce).
func _build_walls_for_dice(tuning: TuningData) -> void:
	var mat := PhysicsMaterial.new()
	mat.bounce = tuning.rail_bounce
	mat.friction = tuning.rail_friction
	var h := 1.0
	var y := 0.06 + h * 0.5
	_static_box("WallFar", Vector3(3, h, 0.1), Vector3(0, y, -FELT_HALF.y - 0.05), mat, &"backboard")
	_static_box("WallNear", Vector3(3, h, 0.1), Vector3(0, y, FELT_HALF.y + 0.05), mat, &"rail")
	_static_box("WallLeft", Vector3(0.1, h, 2), Vector3(-FELT_HALF.x - 0.05, y, 0), mat, &"rail")
	_static_box("WallRight", Vector3(0.1, h, 2), Vector3(FELT_HALF.x + 0.05, y, 0), mat, &"rail")
	_static_box("Ceiling", Vector3(3, 0.1, 2), Vector3(0, 0.06 + h, 0), mat, &"rail")


func _static_box(n: String, size: Vector3, pos: Vector3, mat: PhysicsMaterial, surface: StringName) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = n
	body.position = pos
	body.physics_material_override = mat
	body.set_meta("surface", surface)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	body.add_child(cs)
	root.add_child(body)
	return body


# --- Room and props (cheap set dressing, poc_3d.md 2) ------------------------------

func _build_room() -> void:
	var wall := Toon.fx(Color.WHITE, 1.0, 2, false)
	wall.set_shader_parameter("bottom", Color("#1A0A0E"))
	wall.set_shader_parameter("top", Palette.PIT_BLACK)
	var q := QuadMesh.new()
	q.size = Vector2(9, 3.2)
	Toon.add_mesh(root, q, wall, Vector3(0, 0.7, -3.4)).name = "WallBack"
	Toon.add_mesh(root, q, wall, Vector3(-3.0, 0.7, 0), Vector3(0, 90, 0))
	Toon.add_mesh(root, q, wall, Vector3(3.0, 0.7, 0), Vector3(0, -90, 0))
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(9, 8)
	Toon.add_mesh(root, floor_mesh, Toon.mat(Color("#0E0B0C"), Color.BLACK, {"grime": 0.5, "grime_color": Color("#060404")}), Vector3(0, -0.9, 0)).name = "Floor"
	# Bar silhouette behind the dealer: a counter, a shelf and bottles.
	var dark := Toon.mat(Color("#0B0507"), Color.BLACK, {"ambient_energy": 0.4})
	var glass := Toon.mat(Color("#1A0E0A"), Color.BLACK, {"spec_size": 0.9, "spec_color": Palette.EMBER, "spec_strength": 1.0})
	Toon.add_mesh(root, Toon.box(Vector3(3.6, 1.0, 0.5)), dark, Vector3(0, -0.4, -3.0))
	Toon.add_mesh(root, Toon.box(Vector3(3.2, 0.04, 0.25)), dark, Vector3(0, 0.75, -3.2))
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	for i in 10:
		var bh := rng.randf_range(0.22, 0.34)
		var x := -1.4 + i * 0.31 + rng.randf_range(-0.05, 0.05)
		Toon.add_mesh(root, Toon.cylinder(0.04, bh, 10, 0.03), glass, Vector3(x, 0.77 + bh * 0.5, -3.2))
	var bar_light := OmniLight3D.new()
	bar_light.light_color = Palette.EMBER
	bar_light.light_energy = 0.3
	bar_light.omni_range = 1.5
	bar_light.position = Vector3(0.4, 1.2, -2.8)
	root.add_child(bar_light)


func _build_props() -> void:
	# Ashtray on the right rail with two butts.
	var tin := Toon.inked(Color("#4A4A44"), Toon.SHADOW_WARM, 0.003, {"spec_size": 0.9, "spec_color": Color("#9A9A90")}, 1)
	var tray := Toon.add_mesh(root, Toon.cylinder(0.06, 0.02, 20, 0.07), tin, Vector3(1.11, 0.12, -0.35))
	tray.name = "Ashtray"
	var butt := Toon.mat(Color("#D8C9A8"), Toon.SHADOW_WARM)
	Toon.add_mesh(root, Toon.cylinder(0.006, 0.04, 8), butt, Vector3(1.10, 0.135, -0.34), Vector3(0, 30, 85))
	Toon.add_mesh(root, Toon.cylinder(0.006, 0.035, 8), butt, Vector3(1.13, 0.135, -0.37), Vector3(0, -50, 80))
	# Lowball glass of something amber, near the player on the right rail.
	var g := Toon.mat(Color("#8A4A12"), Toon.SHADOW_WARM, {"spec_size": 0.9, "spec_color": Palette.BRASS_HI, "rim_strength": 0.4, "rim_color": Palette.BRASS_HI})
	Toon.add_mesh(root, Toon.cylinder(0.035, 0.07, 16), g, Vector3(1.12, 0.145, 0.36)).name = "Glass"
	# A few scattered chips on the rails.
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var spots: Array[Vector3] = [Vector3(-1.10, 0.115, -0.15), Vector3(-1.12, 0.115, 0.1), Vector3(0.6, 0.115, -0.62), Vector3(-0.5, 0.115, -0.63), Vector3(1.1, 0.115, 0.05), Vector3(0.95, 0.115, 0.62)]
	for i in spots.size():
		var v: int = [5, 1, 25, 5, 1, 5][i]
		var chip := Chip3D.make(v)
		chip.position = spots[i]
		chip.rotation_degrees = Vector3(rng.randf_range(-12, 12), rng.randf_range(0, 360), rng.randf_range(-12, 12))
		root.add_child(chip)
