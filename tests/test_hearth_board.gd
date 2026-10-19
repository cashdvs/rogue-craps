## Headless test: the Hearth board (art/models/boards/hearth) follows the locked direction
## (art/concept/bonfire_table/README.md "LOCKED DIRECTION") and board_kit.md sections 7-8:
## Board A's node tree and anchors unchanged, slot contents (brazier pot = goal_plaque_scene, demon
## faces in Corner_FL / FR, ember cauldron in ChipTray), nothing decorative over the felt / inside the
## rail centrelines or above 0.25 m (fire cards excepted: they are effects, not geometry), allowed
## shaders only, no lights / physics, and the 15k (PC) / 8k (mobile) budgets.
## The candles, AD revisions, seam band and hooks / clips are in test_hearth_board_fx.gd (split, QA on #111).
## Detail pass (Oct 19): the set dressing (Hearth/Dressing) is covered in depth by test_hearth_dressing.gd;
## here the board-wide rules simply include it (tris = what is drawn: Board A's Visual/Trim is hidden
## while the dressing's worn studs show; the backdrop card far behind Smiles is the one exemption from
## the 0.25 m cap).
##
## Run:
##   godot --headless --path . --script res://tests/test_hearth_board.gd
extends SceneTree

const H := "res://art/models/boards/hearth/scenes/"
const A := "res://art/models/boards/infernal_pit/scenes/"
const ANCHORS: Dictionary = {
	"TargetPlate": Vector3(0, 0.11, -0.61), "TotalPlate": Vector3(0, 0.11, 0.61),
	"ChipTray": Vector3(1.11, 0.11, 0.0), "BurnLine": Vector3(0, 0.002, -0.40),
	"Corner_FL": Vector3(-1.11, 0.11, -0.61), "Corner_FR": Vector3(1.11, 0.11, -0.61),
	"Corner_NL": Vector3(-1.11, 0.11, 0.61), "Corner_NR": Vector3(1.11, 0.11, 0.61),
	"RailProp_FL": Vector3(-0.6, 0.11, -0.61), "RailProp_FR": Vector3(0.6, 0.11, -0.61),
}
const RAIL_R: float = 0.09
const FELT_HALF := Vector2(1.02, 0.52)
const FIXED: Array[String] = ["Floor", "Rails", "Backboard", "Body"]
const EPS: float = 0.0015
const TOON := "res://shaders/3d/toon_noir.gdshader"
const SH := "res://art/models/boards/hearth/shaders/"
## Effect shaders (billboard cards / sparks): exempt from the 0.25 m geometry cap.
## (hearth_glow = the additive candle glow decal lying on the rail top.)
## (hearth_dust = the lamp dust sheet: checked against the game camera in test_hearth_dressing.gd.)
const FX_SHADERS: Array[String] = [SH + "hearth_flame_card.gdshader", SH + "hearth_sparks.gdshader", SH + "hearth_glow.gdshader", SH + "hearth_dust.gdshader"]
## (hearth_pool = the corner light-pool decals: rail-hugging geometry, so it gets the full prop clearance rules.)
const PROP_SHADERS: Array[String] = [TOON, SH + "hearth_coals.gdshader", SH + "demon_eye.gdshader", SH + "hearth_toon_detail.gdshader",
	SH + "hearth_pool.gdshader"]
## The dark backdrop card behind Smiles (out-of-focus far tables): no height cap, must stay far behind him.
const BACKDROP_SHADER := SH + "hearth_backdrop.gdshader"
const BACKDROP_MAX_Z := -1.5

var _passed: int = 0
var _failed: int = 0


func _initialize() -> void:
	print("=== Dice of the Damned: Hearth board tests ===")
	_run.call_deferred()


func _run() -> void:
	for mobile in [false, true]:
		await _check_board(mobile)
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _check_board(mobile: bool) -> void:
	var lod := "_mobile" if mobile else ""
	var path := H + "hearth_board%s.tscn" % lod
	var label := path.get_file()
	var budget := 8000 if mobile else 15000
	var scene := load(path) as PackedScene
	_check(scene != null, label + ": loads")
	if scene == null:
		return
	var board := scene.instantiate() as Node3D
	# --- Board A tree and anchors unchanged ---
	var a := (load(A + "board_a_infernal_pit%s.tscn" % lod) as PackedScene).instantiate() as Node3D
	var missing := ""
	for p in _tree_paths(a, a):
		var n := board.get_node_or_null(p)
		var o := a.get_node(p)
		if n == null or n.get_class() != o.get_class():
			missing += " " + str(p)
	_check(missing == "", "%s: keeps Board A's node tree (names + types)%s" % [label, missing])
	a.free()
	for n: String in ANCHORS:
		var an := board.get_node_or_null("Anchors/" + n) as Marker3D
		_check(an != null and _xf(board, an).origin.is_equal_approx(ANCHORS[n]), "%s: anchor %s at %s" % [label, n, ANCHORS[n]])
	# --- slots ---
	_check(_scene_of(board, "Anchors/TargetPlate/Plate").ends_with("brazier%s.tscn" % lod), label + ": goal_plaque_scene = brazier pot at TargetPlate")
	for c in ["FL", "FR"]:
		_check(_scene_of(board, "Anchors/Corner_%s/Cap" % c).ends_with("demon_face%s.tscn" % lod), "%s: demon face at Corner_%s" % [label, c])
	for c in ["NL", "NR"]:
		_check(_scene_of(board, "Anchors/Corner_%s/Cap" % c).ends_with("corner_cap.tscn"), "%s: Board A corner cap kept at Corner_%s" % [label, c])
	_check(_scene_of(board, "Anchors/ChipTray/Tray").ends_with("cauldron%s.tscn" % lod), label + ": ember cauldron in the ChipTray slot")
	for slot: String in ["BurnLine", "Zones"]:
		_check(board.get_node("Anchors/" + slot).get_child_count() == 0, "%s: %s slot empty" % [label, slot])
	_check(_count_lights(board) == 0, label + ": no light nodes (emissive only; Lamp3D lights the table)")
	_check(_no_physics(board), label + ": no physics bodies or shapes")
	# --- NumberAnchor on the brazier plaque ---
	var cam := Vector3(0, 0, 0.05) + Basis.from_euler(Vector3(deg_to_rad(-55), 0, 0)) * Vector3(0, 0, 2.5)
	for plate: String in ["TargetPlate", "TotalPlate"]:
		var na := board.get_node_or_null("Anchors/%s/Plate/NumberAnchor" % plate) as Node3D
		_check(na != null, "%s: %s has a NumberAnchor" % [label, plate])
		if na != null:
			var nxf := _xf(board, na)
			var face := nxf.basis.z.normalized()
			var tilt := rad_to_deg(asin(clampf(face.y, -1, 1)))
			_check(face.dot((cam - nxf.origin).normalized()) > 0.6 and (absf(tilt - 30.0) < 1.0 or absf(tilt - 60.0) < 1.0), "%s: %s NumberAnchor faces the camera, tilted 30 / 60 deg (%.0f)" % [label, plate, tilt])
	# --- geometry rules + budget ---
	var meshes: Array[MeshInstance3D] = []
	_collect(board, meshes)
	var tris := 0
	var keep_ok := true
	var height_ok := true
	var shader_ok := true
	var fx_ok := true
	var bad := ""
	var bad_sh := ""
	var backdrop_ok := true
	for mi in meshes:
		var xf := _xf(board, mi)
		var top := _top_name(board, mi)
		var drawn := _drawn(board, mi)
		for s in mi.mesh.get_surface_count():
			var mat := mi.material_override if mi.material_override != null else mi.get_active_material(s)
			var sh := ((mat as ShaderMaterial).shader.resource_path) if mat is ShaderMaterial else "?"
			var is_fx := FX_SHADERS.has(sh)
			if not is_fx and not PROP_SHADERS.has(sh) and sh != BACKDROP_SHADER:
				shader_ok = false
				bad_sh = "%s %s" % [mi.name, sh]
			var arrays := mi.mesh.surface_get_arrays(s)
			var idx: Variant = arrays[Mesh.ARRAY_INDEX]
			if drawn:
				tris += ((idx as PackedInt32Array).size() if idx != null else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
			if sh == BACKDROP_SHADER:
				for v: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
					if (xf * v).z > BACKDROP_MAX_Z:
						backdrop_ok = false
				continue
			if sh == SH + "hearth_dust.gdshader":
				continue  # the lamp dust hangs in the cone; test_hearth_dressing.gd checks it never projects over the felt
			if is_fx:
				# effects: the card / spark origin must stand outside the rail line (over the props)
				if _inside_rail_line(xf.origin) and xf.origin.y > EPS:
					fx_ok = false
					bad = "%s %s" % [mi.name, xf.origin]
				continue
			for v: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
				var w := xf * v
				if w.y > 0.25 + EPS:
					height_ok = false
					bad = "%s %s" % [mi.name, w]
				if not FIXED.has(top) and w.y > EPS and _inside_rail_line(w):
					keep_ok = false
					bad = "%s %s" % [mi.name, w]
	_check(keep_ok, "%s: no prop geometry over the felt / inside the rail centrelines %s" % [label, bad])
	_check(height_ok, "%s: all prop geometry under 0.25 m (fire cards excepted)" % label)
	_check(fx_ok, "%s: fire cards stand over the props, never over the felt" % label)
	_check(shader_ok, "%s: surfaces use toon_noir or the Hearth toon shaders only %s" % [label, bad_sh])
	_check(backdrop_ok, "%s: the backdrop card stands behind z %.1f (far behind Smiles)" % [label, BACKDROP_MAX_Z])
	_check(tris <= budget, "%s: %d tris <= %d (all drawn meshes incl. fire cards and the set dressing)" % [label, tris, budget])
	print("  info %s total tris %d" % [label, tris])
	var felt := _mesh(board.get_node("Visual/Floor"))
	var fm := felt.get_active_material(0) as ShaderMaterial
	_check(fm != null and (fm.resource_path.ends_with("hearth_felt.tres") or fm.resource_path.ends_with("hearth_felt_worn.tres")) and fm.get_shader_parameter("use_overlay") == true,
		label + ": felt = hearth_felt (Board A felt + ember corner overlay; _worn with the dressing on)")
	var rails := _mesh(board.get_node("Visual/Rails"))
	var rm := rails.get_active_material(0) as ShaderMaterial
	var seam := rm.next_pass as ShaderMaterial if rm != null else null
	_check(seam != null and seam.shader.resource_path.ends_with("ember_seam.gdshader") and seam.next_pass != null, label + ": rail leather -> ember seam pass -> ink hull (no new geometry)")
	board.free()


func _tree_paths(n: Node, r: Node, out: Array[NodePath] = []) -> Array[NodePath]:
	for c in n.get_children():
		if c.owner != r:
			continue
		out.append(r.get_path_to(c))
		# slot contents are replaced by design; their own subtrees are not part of the Board A tree
		if c.scene_file_path == "":
			_tree_paths(c, r, out)
	return out


## Drawn = the node and all its parents up to the board are visible (the hidden Board A trim and the
## folded-away tail are not drawn).
func _drawn(board: Node, n: Node) -> bool:
	var p := n
	while p != null and p != board:
		if p is Node3D and not (p as Node3D).visible:
			return false
		p = p.get_parent()
	return true


func _scene_of(b: Node, p: String) -> String:
	var n := b.get_node_or_null(p)
	return n.scene_file_path if n != null else ""


func _count_lights(n: Node) -> int:
	var c := 1 if n is Light3D or n is WorldEnvironment else 0
	for k in n.get_children():
		c += _count_lights(k)
	return c


func _no_physics(n: Node) -> bool:
	if n is CollisionObject3D or n is CollisionShape3D:
		return false
	for c in n.get_children():
		if not _no_physics(c):
			return false
	return true


func _inside_rail_line(p: Vector3) -> bool:
	var ax := absf(p.x)
	var az := absf(p.z)
	if ax >= FELT_HALF.x + RAIL_R - EPS or az >= FELT_HALF.y + RAIL_R - EPS:
		return false
	if ax > FELT_HALF.x and az > FELT_HALF.y:
		return Vector2(ax - FELT_HALF.x, az - FELT_HALF.y).length() < RAIL_R - EPS
	return true


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


func _mesh(n: Node) -> MeshInstance3D:
	if n is MeshInstance3D:
		return n
	for c in n.get_children():
		var m := _mesh(c)
		if m != null:
			return m
	return null


func _top_name(board: Node, n: Node) -> String:
	var p := n
	while p.get_parent() != null and p.get_parent() != board and p.get_parent().name != "Visual" and p.get_parent().name != "Anchors":
		p = p.get_parent()
	return String(p.name)


func _check(cond: bool, name: String) -> void:
	if cond:
		_passed += 1
		print("  ok   ", name)
	else:
		_failed += 1
		print("  FAIL ", name)
