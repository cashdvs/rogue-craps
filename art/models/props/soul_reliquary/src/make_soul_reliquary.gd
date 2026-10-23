## Builds the Soul Reliquary (world_props_v1 §2.2, AD pick health_3d #1): meshes, materials and the PC + mobile
## scenes, all in Godot (procedural ArrayMeshes, no Blender step, no textures).
##   godot --headless --path . --script res://art/models/props/soul_reliquary/src/make_soul_reliquary.gd
## Godot axes (+Y up, front = +Z = toward the player), metres at Rig scale 1. Origin = base centre on the rail.
extends SceneTree

const P := "res://art/models/props/soul_reliquary/"
const H := "res://art/models/boards/hearth/"
const RIG_SCALE := {"": 1.25, "_mobile": 1.5}   # numeral >= 24 px on phone (measured in render_soul_reliquary_game.gd)
const N := 8                                  # octagon
const PH := PI / 8.0                          # flat face toward +Z
# keep in sync with scripts/soul_reliquary.gd
const BASE_R := 0.054
const BASE_LO_H := 0.008
const BASE_R2 := 0.044
const BASE_H := 0.051          # tall enough that the cage bottom clears the plate top from the game camera
const VES_R := 0.034
const RING_R := 0.038
const RING_IN := 0.033
const RING_H := 0.010
const BAR_R := 0.0375
const DOME_H := 0.012
const DOME_R := 0.024
# plate: slanted lectern face in front of the plinth (leans back 35 deg toward the camera)
const PL_X := 0.075
const PL_Z0 := 0.034
const PL_ZB := 0.079          # front-bottom edge
const PL_ZT := 0.048          # front-top edge
const PL_Y := 0.043
const FR_OUT := Vector2(0.073, 0.0020)        # frame outer: half-width u, v from bottom
const FR_IN := Vector2(0.066, 0.0085)         # frame inner (digit window) half-width u, v from bottom
const FR_UP := 0.0015
# portrait-only STACKED placard (AD Oct 23, v3): cur over a short bar over max, on a narrow lectern face that
# leans back ST_TILT from the horizontal in front of the plinth. Keep in sync with scripts/soul_reliquary.gd.
const ST_X := 0.042            # placard half-width (Rig-local; portrait rig = 1.5 x 0.65 marker = 0.975 world)
const ST_OX := 0.013           # placard shifted along local +x (portrait: screen-right, off the left edge)
const ST_TILT := 42.0          # face angle above the horizontal (deg)
const ST_ZT := 0.050           # face top edge z (just in front of the plinth's flat face)
const ST_S := 0.1325           # slant length of the face
const ST_OUT := Vector2(0.040, 0.0020)        # frame outer half-width u, v from bottom (and from top)
const ST_IN := Vector2(0.034, 0.0085)         # digit window
const ST_MAX_V := 0.0085 + 0.006 + 0.0215     # max (bottom) digits centre, v from bottom
const ST_BAR_V := 0.0085 + 0.006 + 0.043 + 0.0075   # bar centre
const ST_BAR := Vector2(0.016, 0.0016)        # bar half-length u, half-height v
const ST_CUR_V := ST_BAR_V + 0.0075 + 0.0235  # cur (top) digits centre
const LIQ := Color("#4FE6E0")
const PLATE_LAYER := 1 << 9                    # render layer 10: the numeral plate only (lit by the board, not BrassFill)
const FILL_COLOR := Color("#FFB070")
const FILL_ENERGY := 0.6
const FILL_RANGE := 0.20                       # Rig-local metres (scaled with the rig)
const FILL_AT := Vector3(0.0, 0.17, 0.07)      # above the cage, toward the plate side

var _tris := {}


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(P + "materials"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(P + "meshes"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(P + "scenes"))
	var mats := _materials()
	_meshes(mats)
	for lod in ["", "_mobile"]:
		_scene(lod)
	print("TRIS ", _tris, " total ", _total())
	quit()


func _total() -> int:
	var t := 0
	for k in _tris:
		t += int(_tris[k])
	return t


# ---------------------------------------------------------------- materials
func _copy(src: String, extra: Dictionary) -> ShaderMaterial:
	var o := load(src) as ShaderMaterial
	var m := ShaderMaterial.new()
	m.shader = o.shader
	for p in o.shader.get_shader_uniform_list():
		var v: Variant = o.get_shader_parameter(p.name)
		if v != null:
			m.set_shader_parameter(p.name, v)
	for k in extra:
		m.set_shader_parameter(k, extra[k])
	return m


func _save(res: Resource, path: String) -> void:
	assert(ResourceSaver.save(res, path) == OK, "save " + path)
	res.take_over_path(path)


func _materials() -> Dictionary:
	var ink := load(H + "materials/ink_prop.tres")
	var specs := {
		# v2: no self-lift; the BrassFill omni lifts the brass out of the vignette instead
		"reliquary_brass": [H + "materials/dressing_brass.tres", {"rim_emit": 0.0, "emission_energy": 0.0}],
		"reliquary_brass_worn": [H + "materials/dressing_brass_worn.tres", {"rim_emit": 0.0, "emission_energy": 0.0}],
		# the numeral backing: near-black iron, matte, so the cream digits are light-on-dark
		"reliquary_plate": [H + "materials/dressing_iron.tres", {"albedo": Color("#1A1513"), "shadow_color": Color("#0C0908"),
			"emission_color": Color("#1A1513"), "emission_energy": 0.0, "rim_emit": 0.0, "spec_strength": 0.0, "spec_size": 0.0}],
	}
	var out := {}
	for k in specs:
		var m := _copy(specs[k][0], specs[k][1])
		m.next_pass = ink
		_save(m, P + "materials/%s.tres" % k)
		out[k] = m
	var v := ShaderMaterial.new()
	v.shader = load(P + "shaders/soul_vessel.gdshader")
	v.next_pass = ink
	_save(v, P + "materials/reliquary_vessel.tres")
	out["reliquary_vessel"] = v
	var c := StandardMaterial3D.new()          # the lethal crack: flat ink-black, unlit
	c.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	c.albedo_color = Color("#0B0706")
	_save(c, P + "materials/reliquary_crack.tres")
	out["reliquary_crack"] = c
	return out


# ---------------------------------------------------------------- mesh helpers
class Mb:
	var st := SurfaceTool.new()
	var n := 0
	func _init() -> void:
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
	func vert(p: Vector3, nrm: Vector3, uv := Vector2.ZERO) -> void:
		st.set_normal(nrm.normalized())
		st.set_uv(uv)
		st.add_vertex(p)
	func tri(a: Array, b: Array, c: Array) -> void:   # [pos, normal, uv]; winding fixed from the normals
		var nn: Vector3 = a[1] + b[1] + c[1]
		if ((b[0] - a[0]) as Vector3).cross(c[0] - a[0]).dot(nn) < 0.0:
			var t := b
			b = c
			c = t
		for v in [a, c, b]:                            # Godot front faces are clockwise
			vert(v[0], v[1], v[2])
		n += 1
	func quad(a: Array, b: Array, c: Array, d: Array) -> void:
		tri(a, b, c)
		tri(a, c, d)


func _ring(r: float, y: float, k: int) -> Vector3:
	var a := PH + TAU * k / N
	return Vector3(sin(a) * r, y, cos(a) * r)


func _rad(k: int) -> Vector3:
	var a := PH + TAU * k / N
	return Vector3(sin(a), 0, cos(a))


## Octagonal band: smooth radial normals on the side, optional flat top cap / annulus.
func _oct(m: Mb, r0: float, r1: float, y0: float, y1: float, cap := true, cap_in := 0.0, uv_y := Vector2(0, 1)) -> void:
	for k in N:
		var u0 := float(k) / N
		var u1 := float(k + 1) / N
		var slope := (r0 - r1) / maxf(y1 - y0, 1e-4)
		var n0 := (_rad(k) + Vector3(0, slope, 0))
		var n1 := (_rad(k + 1) + Vector3(0, slope, 0))
		m.quad([_ring(r0, y0, k), n0, Vector2(u0, uv_y.x)], [_ring(r0, y0, k + 1), n1, Vector2(u1, uv_y.x)],
			[_ring(r1, y1, k + 1), n1, Vector2(u1, uv_y.y)], [_ring(r1, y1, k), n0, Vector2(u0, uv_y.y)])
	if cap:
		if cap_in > 0.0:
			for k in N:
				m.quad([_ring(r1, y1, k), Vector3.UP, Vector2.ZERO], [_ring(r1, y1, k + 1), Vector3.UP, Vector2.ZERO],
					[_ring(cap_in, y1, k + 1), Vector3.UP, Vector2.ZERO], [_ring(cap_in, y1, k), Vector3.UP, Vector2.ZERO])
		else:
			for k in range(1, N - 1):
				m.tri([_ring(r1, y1, 0), Vector3.UP, Vector2.ZERO], [_ring(r1, y1, k), Vector3.UP, Vector2.ZERO], [_ring(r1, y1, k + 1), Vector3.UP, Vector2.ZERO])


func _box_sides(m: Mb, c: Vector3, hx: float, hz: float, y0: float, y1: float, yaw: float) -> void:
	var b := Basis(Vector3.UP, yaw)
	var pts := [Vector3(-hx, 0, hz), Vector3(hx, 0, hz), Vector3(hx, 0, -hz), Vector3(-hx, 0, -hz)]
	for i in 4:
		var p0: Vector3 = c + b * pts[i]
		var p1: Vector3 = c + b * pts[(i + 1) % 4]
		var nr := b * Vector3([0, 1, 0, -1][i], 0, [1, 0, -1, 0][i])
		m.quad([p0 + Vector3(0, y0, 0), nr, Vector2.ZERO], [p1 + Vector3(0, y0, 0), nr, Vector2.ZERO],
			[p1 + Vector3(0, y1, 0), nr, Vector2.ZERO], [p0 + Vector3(0, y1, 0), nr, Vector2.ZERO])


## Plate face frame: u across, v up the slanted face, raised along the face normal.
static func face_basis() -> Array:
	var bot := Vector3(0, 0, PL_ZB)
	var d := (Vector3(0, PL_Y, PL_ZT) - bot).normalized()
	var n := Vector3(1, 0, 0).cross(d).normalized()
	return [bot, d, n]


func _fp(u: float, v: float, up: float) -> Vector3:
	var f := face_basis()
	return f[0] + Vector3(u, 0, 0) + (f[1] as Vector3) * v + (f[2] as Vector3) * up


func _save_mesh(name: String, m: Mb, mat: Material) -> void:
	m.st.index()
	var mesh := m.st.commit()
	mesh.surface_set_material(0, mat)
	_tris[name] = m.n
	_save(mesh, P + "meshes/%s.res" % name)


func _meshes(mats: Dictionary) -> void:
	# plinth: two octagonal tiers
	var m := Mb.new()
	_oct(m, BASE_R, BASE_R, 0.0, BASE_LO_H)
	_oct(m, BASE_R2, BASE_R2, BASE_LO_H - 0.001, BASE_H)
	_save_mesh("reliquary_plinth", m, mats.reliquary_brass_worn)
	# plate block (profile in z,y extruded along x): front slant + top + back + two ends
	m = Mb.new()
	var prof := [Vector2(PL_Z0, 0), Vector2(PL_ZB, 0), Vector2(PL_ZT, PL_Y), Vector2(PL_Z0, PL_Y)]
	var fnrm: Vector3 = face_basis()[2]
	for e in [[1, 2, fnrm], [2, 3, Vector3.UP], [3, 0, Vector3.FORWARD]]:
		var a: Vector2 = prof[e[0]]
		var b: Vector2 = prof[e[1]]
		var nr: Vector3 = e[2]
		m.quad([Vector3(PL_X, a.y, a.x), nr, Vector2.ZERO], [Vector3(-PL_X, a.y, a.x), nr, Vector2.ZERO],
			[Vector3(-PL_X, b.y, b.x), nr, Vector2.ZERO], [Vector3(PL_X, b.y, b.x), nr, Vector2.ZERO])
	for sx in [-1.0, 1.0]:
		var nr := Vector3(sx, 0, 0)
		var q := []
		for pi in 4:
			q.append([Vector3(sx * PL_X, prof[pi].y, prof[pi].x), nr, Vector2.ZERO])
		m.quad(q[0], q[1], q[2], q[3])
	_save_mesh("reliquary_plate", m, mats.reliquary_plate)
	# frame: raised brass border round the digit window (the crack lives on this band only)
	m = Mb.new()
	var fn: Vector3 = face_basis()[2]
	var o := [Vector2(-FR_OUT.x, FR_OUT.y), Vector2(FR_OUT.x, FR_OUT.y), Vector2(FR_OUT.x, _vtop(FR_OUT.y)), Vector2(-FR_OUT.x, _vtop(FR_OUT.y))]
	var w := [Vector2(-FR_IN.x, FR_IN.y), Vector2(FR_IN.x, FR_IN.y), Vector2(FR_IN.x, _vtop(FR_IN.y)), Vector2(-FR_IN.x, _vtop(FR_IN.y))]
	for i in 4:
		var j := (i + 1) % 4
		m.quad([_fp(o[i].x, o[i].y, FR_UP), fn, Vector2.ZERO], [_fp(o[j].x, o[j].y, FR_UP), fn, Vector2.ZERO],
			[_fp(w[j].x, w[j].y, FR_UP), fn, Vector2.ZERO], [_fp(w[i].x, w[i].y, FR_UP), fn, Vector2.ZERO])
		var on := (_fp(o[i].x, o[i].y, 0) + _fp(o[j].x, o[j].y, 0)) * 0.5 - _fp(0, (FR_OUT.y + _vtop(FR_OUT.y)) * 0.5, 0)
		m.quad([_fp(o[j].x, o[j].y, 0), on, Vector2.ZERO], [_fp(o[i].x, o[i].y, 0), on, Vector2.ZERO],
			[_fp(o[i].x, o[i].y, FR_UP), on, Vector2.ZERO], [_fp(o[j].x, o[j].y, FR_UP), on, Vector2.ZERO])
		m.quad([_fp(w[i].x, w[i].y, 0), -on, Vector2.ZERO], [_fp(w[j].x, w[j].y, 0), -on, Vector2.ZERO],
			[_fp(w[j].x, w[j].y, FR_UP), -on, Vector2.ZERO], [_fp(w[i].x, w[i].y, FR_UP), -on, Vector2.ZERO])
	_save_mesh("reliquary_frame", m, mats.reliquary_brass)
	# lethal crack: jagged ink strips laid ON the frame band only (u, v kept inside the band)
	m = Mb.new()
	var top_in := _vtop(FR_IN.y)
	var top_out := _vtop(FR_OUT.y)
	const CR_IN := 0.0018   # stop each strip a strip-width short of the window edge: never over the digits
	var cracks := [
		[Vector2(-0.031, top_out), Vector2(-0.026, top_out - 0.0025), Vector2(-0.034, top_out - 0.0045), Vector2(-0.029, top_in + CR_IN)],
		[Vector2(FR_OUT.x, 0.030), Vector2(FR_OUT.x - 0.0025, 0.0285), Vector2(FR_IN.x + 0.0025, 0.0305), Vector2(FR_IN.x + CR_IN, 0.0290)],
		[Vector2(0.012, FR_OUT.y), Vector2(0.0145, 0.0045), Vector2(0.011, 0.0065), Vector2(0.0135, FR_IN.y - CR_IN)],
		[Vector2(-FR_OUT.x, 0.016), Vector2(-FR_OUT.x + 0.0030, 0.0185), Vector2(-FR_IN.x - 0.0025, 0.0150), Vector2(-FR_IN.x - CR_IN, 0.0175)],
		[Vector2(0.040, top_out), Vector2(0.0425, top_out - 0.0022), Vector2(0.0385, top_out - 0.0042), Vector2(0.0415, top_in + CR_IN)],
	]
	for cr in cracks:
		for i in 3:
			var a: Vector2 = cr[i]
			var b: Vector2 = cr[i + 1]
			var dir := (b - a).normalized()
			var side := Vector2(-dir.y, dir.x) * 0.0016
			var up := FR_UP + 0.0004
			m.quad([_fp(a.x - side.x, a.y - side.y, up), fn, Vector2.ZERO], [_fp(b.x - side.x, b.y - side.y, up), fn, Vector2.ZERO],
				[_fp(b.x + side.x, b.y + side.y, up), fn, Vector2.ZERO], [_fp(a.x + side.x, a.y + side.y, up), fn, Vector2.ZERO])
	_save_mesh("reliquary_crack", m, mats.reliquary_crack)
	_stacked_meshes(mats)
	# vessel body: unit height (the Cage scales it), UV.y 0..1
	m = Mb.new()
	_oct(m, VES_R, VES_R, 0.0, 1.0, false)
	_save_mesh("reliquary_vessel", m, mats.reliquary_vessel)
	# dome: glass shoulder above the brim (UV.y > 1 = glass only)
	m = Mb.new()
	_oct(m, VES_R, DOME_R, 0.0, DOME_H, false, 0.0, Vector2(1.2, 1.6))
	_save_mesh("reliquary_dome", m, mats.reliquary_vessel)
	# cage rings (bottom + top share the mesh), bars (unit height), cap + knob
	m = Mb.new()
	_oct(m, RING_R, RING_R, -RING_H * 0.5, RING_H * 0.5, true, RING_IN)
	_save_mesh("reliquary_ring", m, mats.reliquary_brass)
	m = Mb.new()
	for k in 4:
		var a := PI / 4.0 + PI / 2.0 * k
		_box_sides(m, Vector3(sin(a), 0, cos(a)) * BAR_R, 0.0032, 0.0026, 0.0, 1.0, a)
	_save_mesh("reliquary_bars", m, mats.reliquary_brass)
	m = Mb.new()
	_oct(m, DOME_R + 0.003, 0.014, DOME_H - 0.002, DOME_H + 0.008)
	_oct(m, 0.006, 0.006, DOME_H + 0.007, DOME_H + 0.016, false)
	_oct(m, 0.006, 0.0015, DOME_H + 0.016, DOME_H + 0.022, false)
	_save_mesh("reliquary_cap", m, mats.reliquary_brass)


## Stacked placard face: [bottom-front edge, up-the-face dir, normal].
static func st_basis() -> Array:
	var a := deg_to_rad(ST_TILT)
	var d := Vector3(0, sin(a), -cos(a))
	var bot := Vector3(ST_OX, 0, ST_ZT + ST_S * cos(a))
	return [bot, d, Vector3(1, 0, 0).cross(d).normalized()]


func _sp(u: float, v: float, up: float) -> Vector3:
	var f := st_basis()
	return f[0] + Vector3(u, 0, 0) + (f[1] as Vector3) * v + (f[2] as Vector3) * up


func _st_ring(m: Mb, o: Array, w: Array, fn: Vector3, h: float) -> void:
	for i in 4:
		var j := (i + 1) % 4
		m.quad([_sp(o[i].x, o[i].y, h), fn, Vector2.ZERO], [_sp(o[j].x, o[j].y, h), fn, Vector2.ZERO],
			[_sp(w[j].x, w[j].y, h), fn, Vector2.ZERO], [_sp(w[i].x, w[i].y, h), fn, Vector2.ZERO])
		var on := (_sp(o[i].x, o[i].y, 0) + _sp(o[j].x, o[j].y, 0)) * 0.5 - _sp(0, ST_S * 0.5, 0)
		m.quad([_sp(o[j].x, o[j].y, 0), on, Vector2.ZERO], [_sp(o[i].x, o[i].y, 0), on, Vector2.ZERO],
			[_sp(o[i].x, o[i].y, h), on, Vector2.ZERO], [_sp(o[j].x, o[j].y, h), on, Vector2.ZERO])
		m.quad([_sp(w[i].x, w[i].y, 0), -on, Vector2.ZERO], [_sp(w[j].x, w[j].y, 0), -on, Vector2.ZERO],
			[_sp(w[j].x, w[j].y, h), -on, Vector2.ZERO], [_sp(w[i].x, w[i].y, h), -on, Vector2.ZERO])


func _stacked_meshes(mats: Dictionary) -> void:
	var f := st_basis()
	var fn: Vector3 = f[2]
	var bot: Vector3 = f[0]
	var top: Vector3 = bot + (f[1] as Vector3) * ST_S
	# placard block: wedge profile (z, y) extruded along x
	var m := Mb.new()
	var z0 := ST_ZT - 0.006
	var prof := [Vector2(z0, 0), Vector2(bot.z, 0), Vector2(top.z, top.y), Vector2(z0, top.y)]
	for e in [[1, 2, fn], [2, 3, Vector3.UP], [3, 0, Vector3.FORWARD]]:
		var a: Vector2 = prof[e[0]]
		var b: Vector2 = prof[e[1]]
		var nr: Vector3 = e[2]
		m.quad([Vector3(ST_OX + ST_X, a.y, a.x), nr, Vector2.ZERO], [Vector3(ST_OX - ST_X, a.y, a.x), nr, Vector2.ZERO],
			[Vector3(ST_OX - ST_X, b.y, b.x), nr, Vector2.ZERO], [Vector3(ST_OX + ST_X, b.y, b.x), nr, Vector2.ZERO])
	for sx in [-1.0, 1.0]:
		var q := []
		for pi in 4:
			q.append([Vector3(ST_OX + sx * ST_X, prof[pi].y, prof[pi].x), Vector3(sx, 0, 0), Vector2.ZERO])
		m.quad(q[0], q[1], q[2], q[3])
	_save_mesh("reliquary_plate_stacked", m, mats.reliquary_plate)
	# frame band + the fraction bar (raised brass)
	m = Mb.new()
	var o := [Vector2(-ST_OUT.x, ST_OUT.y), Vector2(ST_OUT.x, ST_OUT.y), Vector2(ST_OUT.x, ST_S - ST_OUT.y), Vector2(-ST_OUT.x, ST_S - ST_OUT.y)]
	var w := [Vector2(-ST_IN.x, ST_IN.y), Vector2(ST_IN.x, ST_IN.y), Vector2(ST_IN.x, ST_S - ST_IN.y), Vector2(-ST_IN.x, ST_S - ST_IN.y)]
	_st_ring(m, o, w, fn, FR_UP)
	var b0 := Vector2(-ST_BAR.x, ST_BAR_V - ST_BAR.y)
	var b1 := Vector2(ST_BAR.x, ST_BAR_V + ST_BAR.y)
	m.quad([_sp(b0.x, b0.y, FR_UP), fn, Vector2.ZERO], [_sp(b1.x, b0.y, FR_UP), fn, Vector2.ZERO],
		[_sp(b1.x, b1.y, FR_UP), fn, Vector2.ZERO], [_sp(b0.x, b1.y, FR_UP), fn, Vector2.ZERO])
	_save_mesh("reliquary_frame_stacked", m, mats.reliquary_brass)
	# lethal crack on the band only (strips stop CR_IN short of the window)
	m = Mb.new()
	const CR_IN := 0.0018
	var ti := ST_S - ST_IN.y
	var to := ST_S - ST_OUT.y
	var cracks := [
		[Vector2(-0.018, to), Vector2(-0.014, to - 0.0025), Vector2(-0.021, to - 0.0045), Vector2(-0.016, ti + CR_IN)],
		[Vector2(ST_OUT.x, 0.090), Vector2(ST_OUT.x - 0.0020, 0.0885), Vector2(ST_IN.x + 0.0022, 0.0905), Vector2(ST_IN.x + CR_IN, 0.0890)],
		[Vector2(0.010, ST_OUT.y), Vector2(0.0125, 0.0045), Vector2(0.009, 0.0065), Vector2(0.0115, ST_IN.y - CR_IN)],
		[Vector2(-ST_OUT.x, 0.040), Vector2(-ST_OUT.x + 0.0020, 0.0425), Vector2(-ST_IN.x - 0.0022, 0.0390), Vector2(-ST_IN.x - CR_IN, 0.0415)],
		[Vector2(0.030, to), Vector2(0.0325, to - 0.0022), Vector2(0.0285, to - 0.0042), Vector2(0.0315, ti + CR_IN)],
	]
	for cr in cracks:
		for i in 3:
			var a: Vector2 = cr[i]
			var b: Vector2 = cr[i + 1]
			var dir := (b - a).normalized()
			var side := Vector2(-dir.y, dir.x) * 0.0016
			var up := FR_UP + 0.0004
			m.quad([_sp(a.x - side.x, a.y - side.y, up), fn, Vector2.ZERO], [_sp(b.x - side.x, b.y - side.y, up), fn, Vector2.ZERO],
				[_sp(b.x + side.x, b.y + side.y, up), fn, Vector2.ZERO], [_sp(a.x + side.x, a.y + side.y, up), fn, Vector2.ZERO])
	_save_mesh("reliquary_crack_stacked", m, mats.reliquary_crack)


func _vtop(v_from_bottom: float) -> float:
	var slant := Vector2(PL_ZB - PL_ZT, PL_Y).length()
	return slant - v_from_bottom


# ---------------------------------------------------------------- scenes
func _mi(name: String, mesh: String, parent: Node) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name
	mi.mesh = load(P + "meshes/%s.res" % mesh)
	parent.add_child(mi)
	return mi


func _marker(name: String, pos: Vector3, parent: Node) -> Marker3D:
	var mk := Marker3D.new()
	mk.name = name
	mk.position = pos
	parent.add_child(mk)
	return mk


func _own(n: Node, root: Node) -> void:
	for c in n.get_children():
		c.owner = root
		_own(c, root)


## Portrait-only stacked placard (hidden; SoulReliquary.plate_layout = "stacked" swaps it in for the row plate).
func _stacked_scene(rig: Node3D, row_lbl: Label3D) -> void:
	var st := Node3D.new()
	st.name = "Stacked"
	st.visible = false
	rig.add_child(st)
	var pl := _mi("Plate", "reliquary_plate_stacked", st)
	pl.layers = PLATE_LAYER
	_mi("Frame", "reliquary_frame_stacked", st)
	var cr := _mi("Crack", "reliquary_crack_stacked", st)
	cr.visible = false
	var f := st_basis()
	for e in [["DigitsCur", ST_CUR_V, "18"], ["DigitsMax", ST_MAX_V, "35"]]:
		var l := row_lbl.duplicate() as Label3D
		l.name = e[0]
		l.text = e[2]
		l.position = _sp(0, e[1], 0.0012)
		l.basis = Basis(Vector3(1, 0, 0), f[1], f[2])
		st.add_child(l)
	_marker("PlateCenter", _sp(0, ST_S * 0.5, 0.0012), st)


func _scene(lod: String) -> void:
	var root := Node3D.new()
	root.name = "SoulReliquary"
	root.set_script(load(P + "scripts/soul_reliquary.gd"))
	var rig := Node3D.new()
	rig.name = "Rig"
	rig.scale = Vector3.ONE * float(RIG_SCALE[lod])
	root.add_child(rig)
	_mi("Plinth", "reliquary_plinth", rig)
	var plate := _mi("Plate", "reliquary_plate", rig)
	plate.layers = PLATE_LAYER            # off the BrassFill cull mask: the fill never lifts the digit plate
	_mi("Frame", "reliquary_frame", rig)
	var crack := _mi("Crack", "reliquary_crack", rig)
	crack.visible = false
	var f := face_basis()
	var lbl := Label3D.new()
	lbl.name = "Digits"
	lbl.font = load("res://fonts/BarlowCondensed-Bold.ttf")
	lbl.font_size = 128
	lbl.outline_size = 0
	lbl.modulate = Color("#F1E4C4")        # cream / bone numeral, light on the dark plate
	lbl.shaded = false
	lbl.double_sided = false
	lbl.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	lbl.text = "35/35"
	var mid := (FR_IN.y + _vtop(FR_IN.y)) * 0.5
	lbl.position = _fp(0, mid, 0.0012)
	lbl.basis = Basis(Vector3(1, 0, 0), f[1], f[2])
	rig.add_child(lbl)
	if lod == "_mobile":
		_stacked_scene(rig, lbl)
	var cage := Node3D.new()
	cage.name = "Cage"
	cage.position.y = BASE_H
	rig.add_child(cage)
	var rb := _mi("RingBottom", "reliquary_ring", cage)
	rb.position.y = 0.002
	_mi("Bars", "reliquary_bars", cage)
	_mi("Vessel", "reliquary_vessel", cage)
	var top := Node3D.new()
	top.name = "Top"
	cage.add_child(top)
	_mi("RingTop", "reliquary_ring", top)
	_mi("Dome", "reliquary_dome", top)
	_mi("Cap", "reliquary_cap", top)
	_marker("DeltaAnchor", Vector3(0, DOME_H + 0.04, 0), top)          # '-N' / '+N' pop (VFX owner)
	_marker("LiquidTop", Vector3(0, 0.1, VES_R), cage)                 # moved by the script to the meniscus
	_marker("TooltipAnchor", Vector3(0, PL_Y + 0.006, PL_ZB), rig)     # soul_label / max Soul tooltip
	_marker("PlateCenter", lbl.position, rig)                          # tap / hit-test origin on the numeral
	# local brass fill (AD v2): small warm omni above the cage front so the brass reads out of the rail
	# vignette. Low energy, short range, no shadow; its cull mask skips the plate layer.
	var rs := float(RIG_SCALE[lod])
	var fl := OmniLight3D.new()
	fl.name = "BrassFill"
	fl.light_color = FILL_COLOR
	fl.light_energy = FILL_ENERGY
	fl.omni_range = FILL_RANGE * rs
	fl.omni_attenuation = 2.0
	fl.shadow_enabled = false
	fl.light_specular = 0.2
	fl.light_cull_mask = 0xFFFFF & ~PLATE_LAYER
	fl.position = FILL_AT * rs
	root.add_child(fl)
	_own(root, root)
	var ps := PackedScene.new()
	assert(ps.pack(root) == OK)
	_save(ps, P + "scenes/soul_reliquary%s.tscn" % lod)
	root.free()
