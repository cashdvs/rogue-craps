extends RefCounted
## Shared checks for the boss dealer tests (tests/test_<boss>.gd; template = tests/test_pit_boss.gd). Holds the
## pass/fail counters plus the Smiles framing (game cams, DEALER_POS, brazier hull + rail rule), CPU skinning,
## the AD palette rule (brass / bone / greys / pewter: no red, cyan or violet, no emission), the felt-cover proxy
## and the prop-in-hand clip counter. Usage:
##   const BD := preload("res://tests/support/boss_dealer_checks.gd")
##   var t := BD.new(self)   # self = the SceneTree test
##   t.ok(cond, "what") ... t.finish()

const TOON := "res://shaders/3d/toon_noir.gdshader"
const OUTLINE := "res://shaders/3d/outline.gdshader"
const INK := Color("#0E1414")
const RIM_BONE := Color("#E8DCC0")
const RIM_MAX := 0.5
const DEALER_POS := Vector3(-0.42, -0.47, -0.86)
const RAIL_TOP := 0.14
const GAME_CAMS: Dictionary = {"pc": [Vector2i(1920, 1080), 2.40, Vector3(0, 0, 0.26)], "phone": [Vector2i(844, 390), 2.04, Vector3(0, 0, 0.34)]}
const BRAZIER_CLEAR_PX := 20.0
const PROPS: Array[String] = ["Plaque", "Chip", "Cards", "Rod", "Cloche", "Lancet"]  # chip-bone hand props across the six bosses
## Felt read in the final renders (render_<boss>.gd "felt luma mean" samples fx -0.5..0.5, fz -0.4..0.2 at y 0).
const FELT_X := Vector2(-0.5, 0.5)
const FELT_Z := Vector2(-0.4, 0.2)
const FELT_CELL_PX := 12.0
const FELT_COVER_MAX := 0.02  # at most 2% of the felt sample grid may sit under the dealer silhouette
const PALETTE_SAT_GREY := 0.12  # below this saturation a colour is a grey / pewter (any hue)
const PALETTE_HUE := Vector2(25.0, 58.0)  # warm brass / bone band, degrees
const PALETTE_DARK_V := 0.15  # near-black ink / shadow: any hue

var tree: SceneTree
var passed := 0
var failed := 0
var closest := Vector3.ZERO


func _init(t: SceneTree) -> void:
	tree = t


func ok(cond: bool, what: String) -> void:
	if cond:
		passed += 1
		print("  ok   " + what)
	else:
		failed += 1
		print("  FAIL " + what)


func finish() -> void:
	print("=== %d passed, %d failed ===" % [passed, failed])
	tree.quit(1 if failed > 0 else 0)


## AD dealer palette: greys/pewter, the warm brass-bone hue band, or near-black. Returns "" or why it fails.
static func palette_fail(c: Color) -> String:
	if c.v < PALETTE_DARK_V or c.s < PALETTE_SAT_GREY:
		return ""
	var h := c.h * 360.0
	if h >= PALETTE_HUE.x and h <= PALETTE_HUE.y:
		return ""
	return "%s hue %.0f sat %.2f (red/cyan/violet are out)" % [c.to_html(false), h, c.s]


## Shader param, falling back to the shader's own default (so a red default that was never overridden is caught).
static func param(m: ShaderMaterial, key: String) -> Variant:
	var v: Variant = m.get_shader_parameter(key)
	if v == null and m.shader:
		v = RenderingServer.shader_get_parameter_default(m.shader.get_rid(), key)
	return v


## Every colour uniform of the toon material (+ its ink pass) checked against the palette; emission must be 0.
func check_material(m: Material, label: String, inked: bool) -> void:
	var sm := m as ShaderMaterial
	ok(sm != null and sm.shader and sm.shader.resource_path == TOON, "%s: toon_noir ShaderMaterial" % label)
	if sm == null:
		return
	var bad: Array[String] = []
	for u: Dictionary in sm.shader.get_shader_uniform_list():
		var v: Variant = param(sm, u["name"])
		if v is Color:
			var why := palette_fail(v)
			# a colour only counts if it can show: rim with 0 strength, spec with 0 strength are dead
			if why != "" and not (u["name"] == "rim_color" and float(param(sm, "rim_strength")) <= 0.0) \
					and not (u["name"] == "spec_color" and float(param(sm, "spec_strength")) <= 0.0) \
					and not (u["name"] == "emission_color" and float(param(sm, "emission_energy")) <= 0.0):
				bad.append("%s %s" % [u["name"], why])
	ok(bad.is_empty(), "%s: palette brass/bone/grey/pewter only %s" % [label, bad])
	var e: Variant = param(sm, "emission_energy")
	ok(e == null or float(e) == 0.0, "%s: no emission (emission_energy %s)" % [label, e])
	var rs := float(param(sm, "rim_strength"))
	if rs > 0.0:  # dealer rim (boss_toon.gd RIM_BONE): bone-tinted and low, so it lifts the silhouette without glowing
		ok((param(sm, "rim_color") as Color).is_equal_approx(RIM_BONE) and rs <= RIM_MAX,
			"%s: rim is bone #E8DCC0 at low strength (%.2f <= %.2f)" % [label, rs, RIM_MAX])
	var nx := sm.next_pass as ShaderMaterial
	if inked:
		ok(nx != null and nx.shader and nx.shader.resource_path == OUTLINE and (nx.get_shader_parameter("color") as Color).is_equal_approx(INK),
			"%s: ink hull (outline.gdshader, #0E1414)" % label)
	else:
		ok(nx == null, "%s: no ink hull (small detail)" % label)


func game_cam(kind: String) -> Camera3D:
	var c: Array = GAME_CAMS[kind]
	var vp := SubViewport.new()
	vp.size = c[0]
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	tree.root.add_child(vp)
	var rig := Node3D.new()
	vp.add_child(rig)
	rig.position = c[2]
	rig.rotation_degrees = Vector3(-55, 0, 0)
	var cam := Camera3D.new()
	rig.add_child(cam)
	cam.fov = 36.0
	cam.position = Vector3(0, 0, c[1])
	cam.rotation_degrees = Vector3(7.5, 0, 0)
	cam.current = true
	return cam


## Fraction of the felt sample grid (11 x 7 points) drawn under the dealer: a felt point counts as covered when a
## skinned dealer vertex in front of it (nearer the camera, not hidden by the far rail) projects into its
## FELT_CELL_PX screen cell (vertex splat, ~mesh density at game zoom).
func felt_cover(cam: Camera3D, pts: PackedVector3Array) -> float:
	var occ := {}
	var eye := cam.global_position
	for q in pts:
		var sp := cam.unproject_position(q)
		if q.z < -0.72 and sp.y > cam.unproject_position(Vector3(q.x, RAIL_TOP, -0.72)).y:
			continue  # behind the far rail
		var k := Vector2i(floori(sp.x / FELT_CELL_PX), floori(sp.y / FELT_CELL_PX))
		occ[k] = minf(occ.get(k, INF), eye.distance_to(q))
	var n := 0
	var hit := 0
	for i in 11:
		for j in 7:
			var f := Vector3(lerpf(FELT_X.x, FELT_X.y, i / 10.0), 0.0, lerpf(FELT_Z.x, FELT_Z.y, j / 6.0))
			var sp := cam.unproject_position(f)
			n += 1
			if occ.get(Vector2i(floori(sp.x / FELT_CELL_PX), floori(sp.y / FELT_CELL_PX)), INF) < eye.distance_to(f):
				hit += 1
	return float(hit) / n


func skinned(s: Node3D, skel: Skeleton3D) -> PackedVector3Array:
	var out := PackedVector3Array()
	var hidden_chip := skel.get_bone_pose_scale(skel.find_bone("chip")).x < 0.05
	for mi: MeshInstance3D in s.find_children("*", "MeshInstance3D", true, false):
		var skin := mi.skin
		var mats: Array[Transform3D] = []
		var bn: Array[String] = []
		for i in skin.get_bind_count():
			var b := skin.get_bind_name(i)
			var bi := skel.find_bone(b) if b != "" else skin.get_bind_bone(i)
			bn.append(skel.get_bone_name(bi))
			mats.append(skel.global_transform * skel.get_bone_global_pose(bi) * skin.get_bind_pose(i))
		for si in mi.mesh.get_surface_count():
			var arr := mi.mesh.surface_get_arrays(si)
			var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var bs: PackedInt32Array = arr[Mesh.ARRAY_BONES]
			var ws: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
			var k := ws.size() / maxi(vs.size(), 1)
			for vi in vs.size():
				var j := 0
				for jj in k:
					if ws[vi * k + jj] > ws[vi * k + j]:
						j = jj
				var name := bn[bs[vi * k + j]]
				if name.begins_with("glow_") or (name == "chip" and hidden_chip):
					continue  # glow shells off outside the MC clips; chip/plaque palmed (scale 0) is not drawn
				out.append(mats[bs[vi * k + j]] * vs[vi])
	return out
const BRAZIER_HULL: Array[Vector3] = [
	Vector3(-0.134, 0.213, -0.77), Vector3(-0.134, 0.22, -0.77), Vector3(-0.129, 0.213, -0.805), Vector3(-0.129, 0.213, -0.735), Vector3(-0.129, 0.22, -0.805), Vector3(-0.129, 0.22, -0.735),
	Vector3(-0.128, 0.17, -0.773), Vector3(-0.128, 0.17, -0.767), Vector3(-0.116, 0.213, -0.837), Vector3(-0.116, 0.22, -0.837), Vector3(-0.116, 0.22, -0.703), Vector3(-0.115, 0.165, -0.801),
	Vector3(-0.107, 0.173, -0.832), Vector3(-0.103, 0.165, -0.83), Vector3(-0.095, 0.213, -0.865), Vector3(-0.095, 0.22, -0.865), Vector3(-0.095, 0.22, -0.675), Vector3(-0.087, 0.173, -0.857),
	Vector3(-0.084, 0.165, -0.854), Vector3(-0.078, 0.137, -0.617), Vector3(-0.078, 0.141, -0.611), Vector3(-0.078, 0.203, -0.647), Vector3(-0.077, 0.174, -0.627), Vector3(-0.074, 0.174, -0.625),
	Vector3(-0.067, 0.213, -0.886), Vector3(-0.067, 0.22, -0.886), Vector3(-0.067, 0.22, -0.654), Vector3(-0.066, 0.17, -0.879), Vector3(-0.061, 0.17, -0.882), Vector3(-0.045, 0.09, -0.77),
	Vector3(-0.043, 0.09, -0.782), Vector3(-0.043, 0.09, -0.758), Vector3(-0.039, 0.09, -0.793), Vector3(-0.039, 0.09, -0.748), Vector3(-0.035, 0.213, -0.899), Vector3(-0.035, 0.22, -0.899),
	Vector3(-0.035, 0.22, -0.641), Vector3(-0.032, 0.09, -0.802), Vector3(-0.032, 0.09, -0.738), Vector3(-0.031, 0.165, -0.885), Vector3(-0.023, 0.09, -0.809), Vector3(-0.012, 0.09, -0.813),
	Vector3(-0.012, 0.09, -0.727), Vector3(-0, 0.09, -0.815), Vector3(-0, 0.09, -0.725), Vector3(-0, 0.165, -0.889), Vector3(-0, 0.173, -0.893), Vector3(-0, 0.213, -0.904),
	Vector3(-0, 0.22, -0.904), Vector3(-0, 0.22, -0.636), Vector3(0.012, 0.09, -0.813), Vector3(0.012, 0.09, -0.727), Vector3(0.022, 0.09, -0.809), Vector3(0.031, 0.165, -0.885),
	Vector3(0.032, 0.09, -0.802), Vector3(0.032, 0.09, -0.738), Vector3(0.035, 0.213, -0.899), Vector3(0.035, 0.22, -0.899), Vector3(0.035, 0.22, -0.641), Vector3(0.039, 0.09, -0.793),
	Vector3(0.039, 0.09, -0.748), Vector3(0.043, 0.09, -0.782), Vector3(0.043, 0.09, -0.758), Vector3(0.045, 0.09, -0.77), Vector3(0.061, 0.17, -0.882), Vector3(0.066, 0.17, -0.879),
	Vector3(0.067, 0.213, -0.886), Vector3(0.067, 0.22, -0.886), Vector3(0.067, 0.22, -0.654), Vector3(0.074, 0.174, -0.625), Vector3(0.077, 0.174, -0.627), Vector3(0.078, 0.137, -0.617),
	Vector3(0.078, 0.141, -0.611), Vector3(0.078, 0.203, -0.647), Vector3(0.084, 0.165, -0.854), Vector3(0.095, 0.213, -0.865), Vector3(0.095, 0.22, -0.865), Vector3(0.095, 0.22, -0.675),
	Vector3(0.103, 0.165, -0.83), Vector3(0.107, 0.173, -0.832), Vector3(0.115, 0.165, -0.801), Vector3(0.116, 0.213, -0.837), Vector3(0.116, 0.22, -0.837), Vector3(0.116, 0.22, -0.703),
	Vector3(0.128, 0.17, -0.773), Vector3(0.128, 0.17, -0.767), Vector3(0.129, 0.213, -0.805), Vector3(0.129, 0.213, -0.735), Vector3(0.129, 0.22, -0.805), Vector3(0.129, 0.22, -0.735),
	Vector3(0.134, 0.213, -0.77), Vector3(0.134, 0.22, -0.77),
]

## Screen-space convex hull of the brazier + plaque (monotone chain), counter-clockwise.
func brazier_poly(cam: Camera3D) -> PackedVector2Array:
	var p: Array[Vector2] = []
	for v in BRAZIER_HULL:
		p.append(cam.unproject_position(v))
	p.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x or (a.x == b.x and a.y < b.y))
	var h: Array[Vector2] = []
	for pass_i in 2:
		var start := h.size()
		var seq := p if pass_i == 0 else p.duplicate()
		if pass_i == 1:
			seq.reverse()
		for q in seq:
			while h.size() >= start + 2 and (h[-1] - h[-2]).cross(q - h[-2]) <= 0.0:
				h.pop_back()
			h.append(q)
		h.pop_back()
	return PackedVector2Array(h)


## Smallest on-screen distance (px) from any of `pts` to the brazier polygon (0 = touching / overlapping).
func brazier_px(cam: Camera3D, poly: PackedVector2Array, pts: PackedVector3Array) -> float:
	var lo := INF
	for v in poly:
		lo = minf(lo, v.x)
	var best := INF
	for q in pts:
		var sp := cam.unproject_position(q)
		if sp.x < lo - best:
			continue
		if q.z < -0.72 and sp.y > cam.unproject_position(Vector3(q.x, RAIL_TOP, -0.72)).y:
			continue  # below the far rail's sight line: the rail hides it
		if Geometry2D.is_point_in_polygon(sp, poly):
			closest = q
			return 0.0
		for i in poly.size():
			var c := Geometry2D.get_closest_point_to_segment(sp, poly[i], poly[(i + 1) % poly.size()])
			if sp.distance_to(c) < best:
				best = sp.distance_to(c)
				closest = q
	return best



## Frames (every 0.05 s, all clips) where a prop vertex sits inside the hand/body (check_pit_boss.gd PROPCLIP).
func prop_clip_frames(s: Node3D, skel: Skeleton3D, ap: AnimationPlayer, clips: Array) -> int:
	var total_bad := 0
	for c in clips:
		var a := ap.get_animation(c)
		var t := 0.0
		var bad: Array[String] = []
		var deepest := 0.0
		while t <= a.length + 0.001:
			ap.play(c)
			ap.seek(t, true)
			var sc := skel.get_bone_pose_scale(skel.find_bone("chip")).x
			if sc > 0.05:
				var g := _geo(s, skel)
				var prop: PackedVector3Array = g[0]
				var tris: PackedVector3Array = g[1]
				var box := AABB(prop[0], Vector3.ZERO)
				for q in prop:
					box = box.expand(q)
				box = box.grow(0.03)
				var near := PackedVector3Array()
				for i in range(0, tris.size(), 3):
					if box.has_point(tris[i]) or box.has_point(tris[i + 1]) or box.has_point(tris[i + 2]):
						near.append_array([tris[i], tris[i + 1], tris[i + 2]])
				var n_in := 0
				for q in prop:
					var best := INF
					var sd := 0.0
					for i in range(0, near.size(), 3):
						var cp := _closest_on_tri(q, near[i], near[i + 1], near[i + 2])
						var d := q.distance_to(cp)
						if d < best - 1e-6:
							best = d
							var nrm := (near[i + 1] - near[i]).cross(near[i + 2] - near[i]).normalized()
							sd = (q - cp).dot(nrm)
					if best < INF and sd < -1e-4 and best < 0.03:
						n_in += 1
						deepest = maxf(deepest, best)
				if n_in > 0:
					bad.append("@%.2f sc %.2f: %d verts" % [t, sc, n_in])
			t += 0.05
		total_bad += bad.size()

	return total_bad


func _closest_on_tri(p: Vector3, a: Vector3, b: Vector3, c: Vector3) -> Vector3:
	var pl := Plane(a, b, c)
	var pp := pl.project(p)
	var n := (b - a).cross(c - a)
	if n.length_squared() < 1e-14:
		return Geometry3D.get_closest_point_to_segment(p, a, b)
	if n.dot((b - a).cross(pp - a)) >= 0 and n.dot((c - b).cross(pp - b)) >= 0 and n.dot((a - c).cross(pp - c)) >= 0:
		return pp
	var best := Geometry3D.get_closest_point_to_segment(p, a, b)
	for e in [[b, c], [c, a]]:
		var q := Geometry3D.get_closest_point_to_segment(p, e[0], e[1])
		if p.distance_to(q) < p.distance_to(best):
			best = q
	return best


## [prop vertices, other triangles (flat, 3 per tri)] skinned to world space.
func _geo(s: Node3D, skel: Skeleton3D) -> Array:
	var prop := PackedVector3Array()
	var tris := PackedVector3Array()
	for mi: MeshInstance3D in s.find_children("*", "MeshInstance3D", true, false):
		var is_prop := PROPS.any(func(p: String) -> bool: return mi.name.contains(p))
		var skin := mi.skin
		var mats: Array[Transform3D] = []
		var gl := false
		for i in skin.get_bind_count():
			var b := skin.get_bind_name(i)
			var bi := skel.find_bone(b) if b != "" else skin.get_bind_bone(i)
			mats.append(skel.global_transform * skel.get_bone_global_pose(bi) * skin.get_bind_pose(i))
		for si in mi.mesh.get_surface_count():
			var arr := mi.mesh.surface_get_arrays(si)
			var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var bs: PackedInt32Array = arr[Mesh.ARRAY_BONES]
			var ws: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
			var k := ws.size() / maxi(vs.size(), 1)
			var w := PackedVector3Array()
			w.resize(vs.size())
			for vi in vs.size():
				var j := 0
				for jj in k:
					if ws[vi * k + jj] > ws[vi * k + j]:
						j = jj
				w[vi] = mats[bs[vi * k + j]] * vs[vi]
			if is_prop:
				prop.append_array(w)
			else:
				var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
				var mname := (mi.get_active_material(si).resource_name if mi.get_active_material(si) else "")
				if mname.contains("glow"):
					continue
				for ti in idx:
					tris.append(w[ti])
	return [prop, tris]
