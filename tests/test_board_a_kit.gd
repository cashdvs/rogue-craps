## Headless test: the Board A (Infernal Pit) art kit follows board_kit.md section 7 (Godot Dev,
## Oct 18, 2026): anchor names and positions, NumberAnchors on both plates facing the camera,
## nothing decorative over the felt or inside the rail centreline (x +-1.11 / z +-0.61, rounded at
## the corners) or above 0.25 m,
## the rail mesh keeps the collider's radius on its inner face, toon materials, and the
## ~15k (PC) / ~8k (mobile) triangle budgets. Art only: the kit has no physics nodes.
##
## Run:
##   godot --headless --path . --script res://tests/test_board_a_kit.gd
extends SceneTree

const KIT: String = "res://art/models/boards/infernal_pit/scenes/"
const ANCHORS: Dictionary = {
	"TargetPlate": Vector3(0, 0.11, -0.61), "TotalPlate": Vector3(0, 0.11, 0.61),
	"ChipTray": Vector3(1.11, 0.11, 0.0), "BurnLine": Vector3(0, 0.002, -0.40),
	"Corner_FL": Vector3(-1.11, 0.11, -0.61), "Corner_FR": Vector3(1.11, 0.11, -0.61),
	"Corner_NL": Vector3(-1.11, 0.11, 0.61), "Corner_NR": Vector3(1.11, 0.11, 0.61),
	"RailProp_FL": Vector3(-0.6, 0.11, -0.61), "RailProp_FR": Vector3(0.6, 0.11, -0.61),
}
## Rail tube (fixed, from table_3d_builder.gd): radius 0.09, centre y 0.02, centrelines x +-1.11 / z +-0.61.
const RAIL_R: float = 0.09
const RAIL_Y: float = 0.02
const FELT_HALF := Vector2(1.02, 0.52)
## Meshes that draw fixed geometry (allowed at the felt edge); everything else is decoration.
const FIXED: Array[String] = ["Floor", "Rails", "Backboard", "Body"]
const EPS: float = 0.0015

var _passed: int = 0
var _failed: int = 0


func _initialize() -> void:
	print("=== Dice of the Damned: Board A kit tests ===")
	_check_board(KIT + "board_a_infernal_pit.tscn", 15000)
	_check_board(KIT + "board_a_infernal_pit_mobile.tscn", 8000)
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _check_board(path: String, budget: int) -> void:
	var scene := load(path) as PackedScene
	_check(scene != null, "%s: loads" % path)
	if scene == null:
		return
	var board := scene.instantiate() as Node3D
	for n: String in ANCHORS:
		var a := board.get_node_or_null("Anchors/" + n) as Marker3D
		_check(a != null and _xf(board, a).origin.is_equal_approx(ANCHORS[n]), "%s: anchor %s at %s" % [path.get_file(), n, ANCHORS[n]])
	_check(board.get_node_or_null("Anchors/Zones") != null, "%s: Zones group present" % path.get_file())
	# Game camera (TuningData: pitch 55, distance 2.5, pivot (0, 0, 0.05)).
	var cam := Vector3(0, 0, 0.05) + Basis.from_euler(Vector3(deg_to_rad(-55), 0, 0)) * Vector3(0, 0, 2.5)
	for plate: String in ["TargetPlate", "TotalPlate"]:
		var na := board.get_node_or_null("Anchors/%s/Plate/NumberAnchor" % plate) as Node3D
		_check(na != null, "%s: %s has a NumberAnchor" % [path.get_file(), plate])
		if na != null:
			var nxf := _xf(board, na)
			var face := nxf.basis.z.normalized()
			var tilt := rad_to_deg(asin(clampf(face.y, -1, 1)))
			_check(face.dot((cam - nxf.origin).normalized()) > 0.6, "%s: %s face turned toward the camera" % [path.get_file(), plate])
			_check(absf(tilt - 30.0) < 1.0 or absf(tilt - 60.0) < 1.0, "%s: %s tilted 30 deg (face %.0f deg up)" % [path.get_file(), plate, tilt])
	var tris := 0
	var meshes: Array[MeshInstance3D] = []
	_collect(board, meshes)
	var keep_out_ok := true
	var height_ok := true
	var toon_ok := true
	var bad := ""
	for mi in meshes:
		var top := _top_name(board, mi)
		var xf := _xf(board, mi)
		for s in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(s) as ShaderMaterial
			if mat == null or mat.shader.resource_path != "res://shaders/3d/toon_noir.gdshader":
				toon_ok = false
			var arrays := mi.mesh.surface_get_arrays(s)
			tris += (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
			for v: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
				var w := xf * v
				if w.y > 0.25 + EPS:
					height_ok = false
					bad = "%s %s" % [top, w]
				if not FIXED.has(top) and w.y > EPS and _inside_rail_line(w):
					keep_out_ok = false
					bad = "%s %s" % [top, w]
	_check(keep_out_ok, "%s: no decoration over the felt / inside the rail centrelines %s" % [path.get_file(), bad])
	_check(height_ok, "%s: everything under 0.25 m" % path.get_file())
	_check(toon_ok, "%s: every surface uses toon_noir" % path.get_file())
	_check(tris <= budget, "%s: %d tris <= %d" % [path.get_file(), tris, budget])
	_check_rails(path.get_file(), board, board.get_node("Visual/Rails"))
	_check(_no_physics(board), "%s: no physics bodies, shapes or animations (colliders stay in code)" % path.get_file())
	board.free()


## Inner face of the rail mesh = the collider's surface: no vertex closer to the felt centre than the
## capsule allows, and the inner-facing vertices sit on radius 0.09.
func _check_rails(label: String, board: Node3D, rails: Node) -> void:
	var meshes: Array[MeshInstance3D] = []
	_collect(rails, meshes)
	var inside_ok := true
	var inner_on_radius := true
	for mi in meshes:
		for v: Vector3 in mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
			var w := _xf(board, mi) * v
			# Nearest centreline point of the rounded-rect rail path (corner arcs around the felt corners).
			var cx := clampf(w.x, -FELT_HALF.x, FELT_HALF.x)
			var cz := clampf(w.z, -FELT_HALF.y, FELT_HALF.y)
			var flat := Vector2(w.x - cx, w.z - cz)
			var c := Vector3(cx, RAIL_Y, cz) + Vector3(flat.normalized().x, 0, flat.normalized().y) * RAIL_R
			var r := (w - c).length()
			if r > RAIL_R + EPS:
				inside_ok = false
			var outward := Vector3(flat.normalized().x, 0, flat.normalized().y)
			if (w - c).normalized().dot(-outward) > 0.9 and absf(r - RAIL_R) > EPS:
				inner_on_radius = false
	_check(inside_ok, "%s: rail mesh stays inside the 0.09 m tube" % label)
	_check(inner_on_radius, "%s: rail inner face keeps the collider radius" % label)


## True if p is inside the rail centreline (a rounded rectangle: half size 1.11 x 0.61, corner
## arcs of radius 0.09 around the felt corners), i.e. over the felt or the rail's inner half.
func _inside_rail_line(p: Vector3) -> bool:
	var ax := absf(p.x)
	var az := absf(p.z)
	if ax >= FELT_HALF.x + RAIL_R - EPS or az >= FELT_HALF.y + RAIL_R - EPS:
		return false
	if ax > FELT_HALF.x and az > FELT_HALF.y:
		return Vector2(ax - FELT_HALF.x, az - FELT_HALF.y).length() < RAIL_R - EPS
	return true


## Transform of `n` relative to the board root (the test does not need the scene in the tree).
func _xf(board: Node3D, n: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var p: Node = n
	while p != null and p != board:
		t = (p as Node3D).transform * t
		p = p.get_parent()
	return t


func _collect(n: Node, out: Array[MeshInstance3D]) -> void:
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		out.append(n)
	for c in n.get_children():
		_collect(c, out)


## The Visual child (Floor, Rails...) or the anchor a mesh hangs under.
func _top_name(board: Node, n: Node) -> String:
	var p := n
	while p.get_parent() != null and p.get_parent() != board and p.get_parent().name != "Visual" and p.get_parent().name != "Anchors":
		p = p.get_parent()
	return String(p.name)


func _no_physics(n: Node) -> bool:
	if n is CollisionObject3D or n is CollisionShape3D or n is AnimationPlayer:
		return false
	for c in n.get_children():
		if not _no_physics(c):
			return false
	return true


func _check(cond: bool, name: String) -> void:
	if cond:
		_passed += 1
		print("  ok   ", name)
	else:
		_failed += 1
		print("  FAIL ", name)
