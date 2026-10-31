## Headless test: face-mod marks on the Gallows d4 and the Beacon d8 sit on
## their real triangle faces, not on cube axes or floating off a corner.
## Through the real Bonfire3D scene (apply_die_look, then PolyBody.dress).
## The flat faces are measured here from the drawn body mesh itself (its
## big triangles grouped by normal), not from the code under test. Then for
## every drawn mark piece (each quad / disc of FaceMods):
##   - it faces out along one of the die's flat face normals;
##   - all of its bounds lie on that face plane (at most a 1 mm lift);
##   - all of its bounds stay behind every other face plane, i.e. inside
##     the face triangle, so no mark hangs off an edge;
##   - every modded slot got a mark (d4: 4, d8: all 8) and they don't stack.
##   godot --headless --path . --script res://tests/test_d4_face_marks.gd
extends SceneTree

var _passed: int = 0
var _failed: int = 0


func check(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		print("FAIL  ", what)


func _initialize() -> void:
	_run.call_deferred()


## A plain face mod with [param effect] (no rare glyph id).
func mod(effect: FaceModData.Effect) -> FaceModData:
	var m := FaceModData.new()
	m.id = &"test_mod"
	m.effect = effect
	return m


func _run() -> void:
	var T := FaceModData.Effect.TWIN
	var B := FaceModData.Effect.BLANK
	var W := FaceModData.Effect.WILD
	var g := TableDie.new(DiceIds.DIE_GALLOWS, "Gallows", DiceIds.shape_of(DiceIds.DIE_GALLOWS))
	g.mods = [mod(T), mod(B), mod(T), mod(T)]
	var b := TableDie.new(DiceIds.DIE_BEACON, "Beacon", DiceIds.shape_of(DiceIds.DIE_BEACON))
	b.mods = [mod(T), mod(B), mod(W), mod(T), mod(B), mod(T), load("res://resources/mods/step.tres"), mod(W)]
	var st := TableSetup.new()
	st.dice.append(g)
	st.dice.append(b)
	st.run_mode = false
	st.table_seed = 5
	var s := (load("res://scenes/bonfire.tscn") as PackedScene).instantiate() as Bonfire3D
	s.setup = st
	root.add_child(s)
	await process_frame
	_check_marks(s.all_dice[0], &"d4", 4)
	_check_marks(s.all_dice[1], &"d8", 8)
	_check_slots(s.all_dice[0], g.mods)
	_check_slots(s.all_dice[1], b.mods)
	s.queue_free()
	await process_frame
	print("test_d4_face_marks: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


## The body mesh's flat faces: [{n, dist}], outward normals, from the mesh.
func _faces(body: MeshInstance3D) -> Array:
	var f := body.mesh.get_faces()
	var groups := {}
	for i in range(0, f.size(), 3):
		var a := body.scale * f[i]
		var cr := (body.scale * f[i + 1] - a).cross(body.scale * f[i + 2] - a)
		if cr.length() < 1e-12:
			continue
		var n := cr.normalized()
		if n.dot(a + body.scale * f[i + 1] + body.scale * f[i + 2]) < 0.0:
			n = -n  # outward, whatever the winding
		var key := Vector3i(roundi(n.x * 50), roundi(n.y * 50), roundi(n.z * 50))
		if not groups.has(key):
			groups[key] = {"n": n, "area": 0.0}
		groups[key].area += cr.length() * 0.5
	var big := 0.0
	for k in groups:
		big = maxf(big, groups[k].area)
	var out := []
	for k in groups:
		if groups[k].area > big * 0.5:  # the flat faces, not bevel strips
			var n: Vector3 = groups[k].n
			var far := -INF
			for p: Vector3 in f:
				far = maxf(far, (body.scale * p).dot(n))
			out.append({"n": n, "dist": far})
	return out


func _check_marks(d: DieVisual, shape: StringName, slots: int) -> void:
	check(d.shape == shape, "%s is dressed as a %s" % [d.die_id if "die_id" in d else "die", shape])
	var faces := _faces(d.faces.get_node("Body") as MeshInstance3D)
	check(faces.size() == slots, "%s: mesh has %d flat faces (%d)" % [shape, slots, faces.size()])
	var fm := d.faces.get_node("FaceMods")
	var pieces: Array = []
	_collect(fm, Transform3D.IDENTITY, pieces)
	check(pieces.size() >= slots, "%s: marks were placed (%d pieces)" % [shape, pieces.size()])
	var off_face := 0
	var not_flush := 0
	var hangs_off := 0
	var centres := {}
	for pc: Array in pieces:
		var pts: PackedVector3Array = pc[0]
		var pn: Vector3 = pc[1]
		var mid := Vector3.ZERO
		for p in pts:
			mid += p / float(pts.size())
		# (On a d8 the opposite face is parallel: take the one it sits on.)
		var k := -1
		for i in faces.size():
			if absf(pn.dot(faces[i].n)) > 0.999:
				if k < 0 or mid.dot(faces[i].n) > mid.dot(faces[k].n):
					k = i
		if k < 0:
			off_face += 1
			continue
		for p in pts:
			var h: float = p.dot(faces[k].n) - faces[k].dist
			if h < 0.0 or h > 0.001:
				not_flush += 1
			for j in faces.size():
				if j != k and p.dot(faces[j].n) > faces[j].dist:
					hangs_off += 1
		if not centres.has(k):
			centres[k] = []
		centres[k].append(mid)
	check(off_face == 0, "%s: every mark faces along a flat face normal (%d off)" % [shape, off_face])
	check(not_flush == 0, "%s: mark bounds lie on the face plane (%d off)" % [shape, not_flush])
	check(hangs_off == 0, "%s: mark bounds stay inside the face triangle (%d out)" % [shape, hangs_off])
	check(centres.size() == slots, "%s: every face got its mark (%d of %d)" % [shape, centres.size(), slots])


## How many FaceMods children one mod draws (Twin: 8 strips, Wild: 4,
## Blank: 1 quad, a rare glyph: 1 mark node).
func _pieces_of(m: FaceModData, shape: StringName) -> int:
	if RareDieLook.MARKS.has(m.id):
		return 1
	if shape == &"d4" and m.effect == FaceModData.Effect.TWIN:
		return 2  # the brass diamond and its dark outline
	return {FaceModData.Effect.TWIN: 8, FaceModData.Effect.WILD: 4}.get(m.effect, 1)


## Slot by slot (FaceMods children come in slot order): slot k's mark is on
## the right face. d8: the face whose normal is dirs[k] (that face reads k).
## d4 (read by its top corner k): a face touching corner k, the one opposite
## corner k+1 (where the mark goes is checked against the art in
## test_poly_face_art).
func _check_slots(d: DieVisual, mods: Array) -> void:
	var dirs: Array = DieHullData.SHAPES[d.shape]["dirs"]
	var kids := d.faces.get_node("FaceMods").get_children()
	var at := 0
	var wrong := 0
	for k in mods.size():
		var mid := Vector3.ZERO
		var n := Vector3.ZERO
		var cnt: int = _pieces_of(mods[k], d.shape)
		for i in cnt:
			var c := kids[at + i] as Node3D
			var pcs: Array = []
			_collect(c, c.transform, pcs)
			if c is MeshInstance3D:
				pcs.append(_piece(c.transform, (c as MeshInstance3D).mesh))
			for pc: Array in pcs:
				n = pc[1]
				for p: Vector3 in pc[0]:
					mid += p / float(cnt * pc[0].size() * pcs.size())
		at += cnt
		var dk: Vector3 = (dirs[k] as Vector3).normalized()
		var ok := false
		if d.shape == &"d8":
			ok = absf(n.dot(dk)) > 0.999 and mid.dot(dk) > 0.0
		else:
			var dn: Vector3 = (dirs[(k + 1) % 4] as Vector3).normalized()
			ok = n.dot(dk) > 0.3 and n.dot(dn) < -0.99
		if not ok:
			wrong += 1
	check(at == kids.size(), "%s: FaceMods children match the mods (%d of %d)" % [d.shape, at, kids.size()])
	check(wrong == 0, "%s: each slot's mark is on its own face (%d wrong)" % [d.shape, wrong])


## A drawn piece as [its points, its normal], in die-faces space. A quad or
## disc: its bounds' 8 corners, normal = its thin axis (a quad's z, a disc's
## y). A baked mesh (the tinted numeral): its triangle corners.
func _piece(t: Transform3D, mesh: Mesh) -> Array:
	var pts := PackedVector3Array()
	var n := Vector3.ZERO
	if mesh is ArrayMesh:
		for p in mesh.get_faces():
			pts.append(t * p)
		n = (pts[1] - pts[0]).cross(pts[2] - pts[0]).normalized()
	else:
		var box := mesh.get_aabb()
		for c in 8:
			pts.append(t * box.get_endpoint(c))
		for ax in 3:
			if box.size[ax] < 0.001:
				n = t.basis[ax].normalized()
	return [pts, n]


## Every drawn mesh under [param n], as _piece()s in die-faces space.
func _collect(n: Node, xf: Transform3D, out: Array) -> void:
	for c in n.get_children():
		if c is Node3D:
			var t: Transform3D = xf * (c as Node3D).transform
			if c is MeshInstance3D and (c as MeshInstance3D).mesh != null:
				out.append(_piece(t, (c as MeshInstance3D).mesh))
			_collect(c, t, out)
