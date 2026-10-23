## Portrait-only STACKED fraction placard for the Soul Reliquary (AD Oct 23, v3): meshes + the hidden Rig/Stacked
## node. Used by make_soul_reliquary.gd (gen = that SceneTree: _save_mesh, _mi, _marker, FR_UP, PLATE_LAYER).
extends RefCounted

const Mb := preload("res://art/models/props/soul_reliquary/src/reliquary_mb.gd")

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

var gen: Object


func _init(g: Object) -> void:
	gen = g

## Stacked placard face: [bottom-front edge, up-the-face dir, normal].
static func st_basis() -> Array:
	var a := deg_to_rad(ST_TILT)
	var d := Vector3(0, sin(a), -cos(a))
	var bot := Vector3(ST_OX, 0, ST_ZT + ST_S * cos(a))
	return [bot, d, Vector3(1, 0, 0).cross(d).normalized()]


func sp(u: float, v: float, up: float) -> Vector3:
	var f := st_basis()
	return f[0] + Vector3(u, 0, 0) + (f[1] as Vector3) * v + (f[2] as Vector3) * up


func _ring(m: Mb, o: Array, w: Array, fn: Vector3, h: float) -> void:
	for i in 4:
		var j := (i + 1) % 4
		m.quad([sp(o[i].x, o[i].y, h), fn, Vector2.ZERO], [sp(o[j].x, o[j].y, h), fn, Vector2.ZERO],
			[sp(w[j].x, w[j].y, h), fn, Vector2.ZERO], [sp(w[i].x, w[i].y, h), fn, Vector2.ZERO])
		var on := (sp(o[i].x, o[i].y, 0) + sp(o[j].x, o[j].y, 0)) * 0.5 - sp(0, ST_S * 0.5, 0)
		m.quad([sp(o[j].x, o[j].y, 0), on, Vector2.ZERO], [sp(o[i].x, o[i].y, 0), on, Vector2.ZERO],
			[sp(o[i].x, o[i].y, h), on, Vector2.ZERO], [sp(o[j].x, o[j].y, h), on, Vector2.ZERO])
		m.quad([sp(w[i].x, w[i].y, 0), -on, Vector2.ZERO], [sp(w[j].x, w[j].y, 0), -on, Vector2.ZERO],
			[sp(w[j].x, w[j].y, h), -on, Vector2.ZERO], [sp(w[i].x, w[i].y, h), -on, Vector2.ZERO])


func meshes(mats: Dictionary) -> void:
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
	gen._save_mesh("reliquary_plate_stacked", m, mats.reliquary_plate)
	# frame band + the fraction bar (raised brass)
	m = Mb.new()
	var o := [Vector2(-ST_OUT.x, ST_OUT.y), Vector2(ST_OUT.x, ST_OUT.y), Vector2(ST_OUT.x, ST_S - ST_OUT.y), Vector2(-ST_OUT.x, ST_S - ST_OUT.y)]
	var w := [Vector2(-ST_IN.x, ST_IN.y), Vector2(ST_IN.x, ST_IN.y), Vector2(ST_IN.x, ST_S - ST_IN.y), Vector2(-ST_IN.x, ST_S - ST_IN.y)]
	_ring(m, o, w, fn, gen.FR_UP)
	var b0 := Vector2(-ST_BAR.x, ST_BAR_V - ST_BAR.y)
	var b1 := Vector2(ST_BAR.x, ST_BAR_V + ST_BAR.y)
	m.quad([sp(b0.x, b0.y, gen.FR_UP), fn, Vector2.ZERO], [sp(b1.x, b0.y, gen.FR_UP), fn, Vector2.ZERO],
		[sp(b1.x, b1.y, gen.FR_UP), fn, Vector2.ZERO], [sp(b0.x, b1.y, gen.FR_UP), fn, Vector2.ZERO])
	gen._save_mesh("reliquary_frame_stacked", m, mats.reliquary_brass)
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
			var up: float = gen.FR_UP + 0.0004
			m.quad([sp(a.x - side.x, a.y - side.y, up), fn, Vector2.ZERO], [sp(b.x - side.x, b.y - side.y, up), fn, Vector2.ZERO],
				[sp(b.x + side.x, b.y + side.y, up), fn, Vector2.ZERO], [sp(a.x + side.x, a.y + side.y, up), fn, Vector2.ZERO])
	gen._save_mesh("reliquary_crack_stacked", m, mats.reliquary_crack)


## Portrait-only stacked placard (hidden; SoulReliquary.plate_layout = "stacked" swaps it in for the row plate).
func scene(rig: Node3D, row_lbl: Label3D) -> void:
	var st := Node3D.new()
	st.name = "Stacked"
	st.visible = false
	rig.add_child(st)
	var pl: MeshInstance3D = gen._mi("Plate", "reliquary_plate_stacked", st)
	pl.layers = gen.PLATE_LAYER
	gen._mi("Frame", "reliquary_frame_stacked", st)
	var cr: MeshInstance3D = gen._mi("Crack", "reliquary_crack_stacked", st)
	cr.visible = false
	var f := st_basis()
	for e in [["DigitsCur", ST_CUR_V, "18"], ["DigitsMax", ST_MAX_V, "35"]]:
		var l := row_lbl.duplicate() as Label3D
		l.name = e[0]
		l.text = e[2]
		l.position = sp(0, e[1], 0.0012)
		l.basis = Basis(Vector3(1, 0, 0), f[1], f[2])
		st.add_child(l)
	gen._marker("PlateCenter", sp(0, ST_S * 0.5, 0.0012), st)
