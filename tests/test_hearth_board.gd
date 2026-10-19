## Headless test: the Hearth board (art/models/boards/hearth) follows the locked direction
## (art/concept/bonfire_table/README.md "LOCKED DIRECTION") and board_kit.md sections 7-8:
## Board A's node tree and anchors unchanged, slot contents (brazier pot = goal_plaque_scene, demon
## faces in Corner_FL / FR, ember cauldron in ChipTray), nothing decorative over the felt / inside the
## rail centrelines or above 0.25 m (fire cards excepted: they are effects, not geometry), allowed
## shaders only, no lights / physics, the 15k (PC) / 8k (mobile) budgets, 8 progress candles
## (<= 150 tris, one shared material), and the visual hooks + AnimationPlayer clips Godot Dev drives
## (including the bust snuff restoring the previous state).
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
## Smiles (the dealer) stands STAGE LEFT of the brazier behind the far rail: a centred dealer's face
## would sit behind the brazier bowl itself from the game camera. Face sphere (world) used to check
## that solid fire never covers his face at any pot step (Art Director, Oct 18).
const DEALER_FACE := Vector3(-0.42, 0.2, -0.86)
const DEALER_FACE_R := 0.11
const CARD_FOOT := 0.113
const HOOKS: Array[String] = ["pot_step", "eyes", "eyes_left", "eyes_right", "fill", "lit_count", "seam", "pulse", "snuff", "wisp", "flare"]

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
	if seam != null:
		_check_seam_band(label, board, rails, seam)
	# --- candles ---
	var candles: Array[Node3D] = []
	for i in range(1, 9):
		var c := board.find_child("Candle%d" % i, true, false) as Node3D
		_check(c != null, "%s: Candle%d present" % [label, i])
		if c != null:
			candles.append(c)
	var left := 0
	var right := 0
	var cmesh: Mesh = null
	var cmat: Material = null
	var shared := true
	var cand_ok := true
	for c in candles:
		var cxf := _xf(board, c)
		if cxf.origin.x <= -1.11:
			left += 1
		elif cxf.origin.x >= 1.11:
			right += 1
		var m := _mesh(c.get_node("Model"))
		var t := 0
		for s in m.mesh.get_surface_count():
			t += (m.mesh.surface_get_arrays(s)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
		if t > (90 if mobile else 150):
			cand_ok = false
		if cmesh == null:
			cmesh = m.mesh
			cmat = m.get_active_material(0)
		elif m.mesh != cmesh or m.get_active_material(0) != cmat:
			shared = false
	_check(left == 4 and right == 4, "%s: 4 candles per side rail at |x| >= 1.11" % label)
	_check(cand_ok, "%s: each candle <= %d tris" % [label, 90 if mobile else 150])
	_check(shared, label + ": all 8 candles share one mesh and one wax material")
	# --- Art Director revisions (Oct 18) ---
	_check_revisions(label, board, candles)
	# --- hooks and clips ---
	var fx := board.get_node_or_null("Hearth")
	_check(fx != null, label + ": Hearth FX hub node")
	if fx == null:
		board.free()
		return
	for h in HOOKS:
		_check(h in fx, "%s: hook Hearth.%s" % [label, h])
	_check(fx.has_method("bust") and fx.has_method("pulse_seam"), label + ": Hearth.bust() and Hearth.pulse_seam()")
	var ap := fx.get_node_or_null("AnimationPlayer") as AnimationPlayer
	var sp := fx.get_node_or_null("SeamPlayer") as AnimationPlayer
	_check(ap != null and ap.has_animation("snuff") and ap.has_animation("flare") and ap.has_animation("RESET"), label + ": AnimationPlayer clips snuff / flare / RESET")
	_check(sp != null and sp.has_animation("seam_pulse") and is_equal_approx(sp.get_animation("seam_pulse").length, 0.15), label + ": SeamPlayer seam_pulse is 0.15 s")
	if ap != null:
		var keyed := ""
		for clip in ["snuff", "flare"]:
			var an := ap.get_animation(clip)
			for t in an.get_track_count():
				keyed += str(an.track_get_path(t)) + " "
		_check(not ("lit_count" in keyed or "pot_step" in keyed or "eyes" in keyed or "fill" in keyed), label + ": snuff / flare never key state params (" + keyed.strip_edges() + ")")
	# --- behaviour (in the tree) ---
	root.add_child(board)
	await process_frame
	fx.pot_step = 3
	fx.eyes = 2
	fx.fill = 0.7
	fx.lit_count = 5
	var pot := board.get_node("Anchors/TargetPlate/Plate")
	_check(not pot.get_node("Fire/Step1").visible and pot.get_node("Fire/Step3").visible and not pot.get_node("Fire/Step4").visible, label + ": pot_step 3 shows only fire step 3")
	var eye_mesh := _mesh(board.get_node("Anchors/Corner_FL/Cap/Model"))
	_check(is_equal_approx(float(eye_mesh.get_instance_shader_parameter(&"level")), 2.0), label + ": eyes 2 reaches the demon eye shader")
	var lit_ok := true
	for i in candles.size():
		if (candles[i].get_node("Flame") as Node3D).visible != (i < 5):
			lit_ok = false
	_check(lit_ok, label + ": lit_count 5 lights candles 1-5 only")
	var fill := board.get_node("Anchors/ChipTray/Tray/Fill") as Node3D
	_check(fill.visible and fill.position.y > 0.06, label + ": fill 0.7 raises the ember mound")
	# bust: everything out mid-clip, everything back (same state) at the end
	ap.play("snuff")
	ap.seek(0.3, true)
	var out_ok: bool = not pot.get_node("Fire/Step3").visible and not (candles[0].get_node("Flame") as Node3D).visible \
		and is_zero_approx(float(eye_mesh.get_instance_shader_parameter(&"heat"))) and (candles[0].get_node("Wisp") as Node3D).visible
	_check(out_ok, label + ": snuff at 0.3 s: fire, candles and eyes out, smoke wisp up")
	ap.seek(0.75, true)
	var back_ok: bool = pot.get_node("Fire/Step3").visible and (candles[4].get_node("Flame") as Node3D).visible \
		and not (candles[5].get_node("Flame") as Node3D).visible and fx.lit_count == 5 and fx.pot_step == 3 \
		and is_equal_approx(float(eye_mesh.get_instance_shader_parameter(&"heat")), 1.0) and not (candles[0].get_node("Wisp") as Node3D).visible
	_check(back_ok, label + ": after snuff everything relights to the previous state (5 candles, step 3, eyes 2)")
	ap.stop()
	fx.lit_count = 8
	_check(ap.current_animation == "flare", label + ": reaching 8 candles plays the flare clip")
	fx.pulse_seam()
	sp.seek(0.0, true)
	_check(float(rails.get_instance_shader_parameter(&"pulse")) > 0.9, label + ": seam pulse reaches the rail seam pass")
	root.remove_child(board)
	board.free()


func _check_revisions(label: String, board: Node3D, candles: Array[Node3D]) -> void:
	var c0 := candles[0]
	var fl := c0.get_node("Flame") as MeshInstance3D
	_check(is_equal_approx((fl.mesh as QuadMesh).size.y * 0.8, 0.03), label + ": candle flame = tier-1 tongue at 0.75 scale (0.03 m visible)")
	var gl := c0.get_node_or_null("Glow") as MeshInstance3D
	_check(gl != null and (gl.material_override as ShaderMaterial).shader.resource_path.ends_with("hearth_glow.gdshader"), label + ": candle has an additive glow decal for the rail top")
	var wax := _mesh(c0.get_node("Model")).mesh.surface_get_material(0) as ShaderMaterial
	_check(wax != null and _param(wax, "emission_energy") > 0.0, label + ": unlit wax keeps a dim emissive silhouette")
	var lit := load("res://art/models/boards/hearth/materials/candle_wax_lit.tres") as ShaderMaterial
	_check(lit != null and _param(lit, "rim_strength") > 1.0, label + ": lit wax has an emissive rim")
	# Fire: the step-4 column caps at ~0.3 m above the coals, and no solid fire card at any step covers
	# the dealer's face from the game camera (sparks may: they are not checked).
	var pot := board.get_node("Anchors/TargetPlate/Plate")
	var cam := Transform3D(Basis.from_euler(Vector3(deg_to_rad(-55), 0, 0)), Vector3.ZERO)
	cam.origin = Vector3(0, 0, 0.05) + cam.basis * Vector3(0, 0, 2.5)
	var face := _screen_rect(cam, [DEALER_FACE + Vector3(-DEALER_FACE_R, -DEALER_FACE_R, 0), DEALER_FACE + Vector3(DEALER_FACE_R, DEALER_FACE_R, 0)])
	var top := 0.0
	var clear := true
	var bad := ""
	for i in range(1, 5):
		var step := pot.get_node("Fire/Step%d" % i)
		var meshes: Array[MeshInstance3D] = []
		_collect(step, meshes)
		for mi in meshes:
			if not (mi.mesh is QuadMesh) or not ((mi.material_override as ShaderMaterial).get_shader_parameter("mode") in [null, 0]):
				continue  # sparks and the smoke curl are not solid fire
			var size := (mi.mesh as QuadMesh).size.y
			var lp := mi.position  # inside Step (or Step/Twist, which only rotates about y)
			var r := Vector2(lp.x, lp.z).length() if mi.get_parent().name == "Twist" else absf(lp.x)
			var foot := lp.y + size * CARD_FOOT
			if i == 4:
				top = maxf(top, foot + size * 0.8)
			var w := _xf(board, step).origin
			var rect := _screen_rect(cam, [w + Vector3(-r - size * 0.5, foot, 0), w + Vector3(r + size * 0.5, foot + size * 0.8, 0)])
			if rect.intersects(face):
				clear = false
				bad = "Step%d/%s" % [i, mi.name]
	_check(top > 0.25 and top < 0.32, "%s: step-4 column capped at ~0.3 m above the coals (%.3f)" % [label, top])
	_check(clear, "%s: no solid fire at any step covers the dealer's face from the game camera %s" % [label, bad])
	var eye := _mesh(board.get_node("Anchors/Corner_FL/Cap/Model"))
	var em: ShaderMaterial = null
	for s in eye.mesh.get_surface_count():
		var m := eye.mesh.surface_get_material(s) as ShaderMaterial
		if m != null and m.shader.resource_path.ends_with("demon_eye.gdshader"):
			em = m
	var es: Variant = em.get_shader_parameter("eye_size") if em != null else null
	_check(es != null and (es as Vector2).x * (es as Vector2).y >= 2.0 * 0.0115 * 0.0068 * 0.99, label + ": demon eyes are 2x the first pass's area")
	_check(em != null and _param(em, "idle_energy") + _code_default(em.shader, "idle_energy") > 0.0, label + ": demon eyes smoulder faintly at eyes = 0")


## A material's parameter, falling back to the shader's default (0 when neither is set).
func _param(m: ShaderMaterial, n: String) -> float:
	var v: Variant = m.get_shader_parameter(n)
	if v == null:
		v = RenderingServer.shader_get_parameter_default(m.shader.get_rid(), n)
	return 0.0 if v == null else float(v)


## A float uniform's default parsed from shader code (the headless dummy renderer reports none).
func _code_default(sh: Shader, n: String) -> float:
	var re := RegEx.create_from_string("uniform float " + n + "[^=;]*=\\s*([0-9.]+)")
	var m := re.search(sh.code)
	return 0.0 if m == null else float(m.get_string(1))


## Screen-space (NDC) bounding box of world points seen from the game camera (FOV 36, 16:9).
func _screen_rect(cam: Transform3D, pts: Array) -> Rect2:
	var t := tan(deg_to_rad(36.0) * 0.5)
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p: Vector3 in pts:
		for corner in [Vector3(p.x, p.y, p.z)]:
			var v: Vector3 = cam.affine_inverse() * (corner as Vector3)
			var s := Vector2(v.x / (-v.z * t * 16.0 / 9.0), v.y / (-v.z * t))
			lo = lo.min(s)
			hi = hi.max(s)
	return Rect2(lo, hi - lo)


## The seam band (ember_seam band_v) must land on the INNER face of the rail tube, just above the felt.
func _check_seam_band(label: String, board: Node3D, rails: MeshInstance3D, seam: ShaderMaterial) -> void:
	var v: Variant = seam.get_shader_parameter("band_v")
	var bv: float = v if v != null else RenderingServer.shader_get_parameter_default(seam.shader.get_rid(), "band_v")
	var arr := rails.mesh.surface_get_arrays(0)
	var verts := arr[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var uvs := arr[Mesh.ARRAY_TEX_UV] as PackedVector2Array
	var xf := _xf(board, rails)
	var n := 0
	var inner := 0
	var ymin := 1.0
	var ymax := -1.0
	for i in verts.size():
		if absf(uvs[i].y - bv) < 0.03:
			var w := xf * verts[i]
			n += 1
			if _inside_rail_line(w):
				inner += 1
			ymin = minf(ymin, w.y)
			ymax = maxf(ymax, w.y)
	_check(n > 0 and inner == n and ymin > 0.06 and ymax < 0.11, "%s: seam band (UV.y %.3f) sits on the inner rail lip, above the backboard strip (0.06) and below the rail top (%d verts, y %.3f-%.3f)" % [label, bv, n, ymin, ymax])


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
