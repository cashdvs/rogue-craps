## Headless test: face-mod marks (Twin double square, Blank plain square) on
## the Gallows d4 sit on its real triangle faces, not on cube axes.
## Through the real Bonfire3D scene (apply_die_look, then PolyBody.dress):
##   - every mark quad faces out along one of the 4 d4 face normals;
##   - it sits flush on that face (its centre is on the face plane);
##   - all 4 corners stay inside the die (behind the other 3 faces), so
##     the mark fits on the triangle and does not hang off an edge.
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
	var g := TableDie.new(DiceIds.DIE_GALLOWS, "Gallows", DiceIds.shape_of(DiceIds.DIE_GALLOWS))
	g.mods = [mod(FaceModData.Effect.TWIN), mod(FaceModData.Effect.BLANK), mod(FaceModData.Effect.TWIN), mod(FaceModData.Effect.BLANK)]
	var st := TableSetup.new()
	st.dice.append(g)
	st.run_mode = false
	st.table_seed = 5
	var s := (load("res://scenes/bonfire.tscn") as PackedScene).instantiate() as Bonfire3D
	s.setup = st
	root.add_child(s)
	await process_frame
	_check_marks(s.all_dice[0])
	s.queue_free()
	await process_frame
	print("test_d4_face_marks: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _check_marks(d: DieVisual) -> void:
	check(d.shape == &"d4", "Gallows is dressed as a d4")
	var body := d.faces.get_node("Body") as MeshInstance3D
	# Each face's distance from the centre, measured here from the drawn mesh.
	var ns: Array[Vector3] = []
	var dist: Array[float] = []
	for n: Vector3 in [Vector3(0, 1, 0), Vector3(0, -0.3333, 0.9428), Vector3(-0.8165, -0.3333, -0.4714), Vector3(0.8165, -0.3333, -0.4714)]:
		ns.append(n.normalized())
		var far := -INF
		for p: Vector3 in body.mesh.get_faces():
			far = maxf(far, (body.scale * p).dot(n.normalized()))
		dist.append(far)
	var marks := d.faces.get_node("FaceMods").get_children()
	check(marks.size() >= 4, "marks were placed (%d quads)" % marks.size())
	var seen := {}
	var off_face := 0
	var not_flush := 0
	var hangs_off := 0
	for q: MeshInstance3D in marks:
		var z := q.transform.basis.z.normalized()
		var k := -1
		for i in 4:
			if z.dot(ns[i]) > 0.999:
				k = i
		if k < 0:
			off_face += 1
			continue
		seen[k] = true
		# Flush: on the face plane, at most a 1 mm lift.
		var h := q.transform.origin.dot(ns[k]) - dist[k]
		if h < 0.0 or h > 0.001:
			not_flush += 1
		var sz := (q.mesh as QuadMesh).size * 0.5
		for c in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			var p: Vector3 = q.transform * Vector3(sz.x * c.x, sz.y * c.y, 0)
			for j in 4:
				if j != k and p.dot(ns[j]) > dist[j]:
					hangs_off += 1
	check(off_face == 0, "every mark faces along a d4 face normal (%d on cube axes)" % off_face)
	check(seen.size() == 4, "all 4 d4 faces got their mark (%d)" % seen.size())
	check(not_flush == 0, "marks sit flush on their face (%d off)" % not_flush)
	check(hangs_off == 0, "mark corners stay inside the triangle (%d out)" % hangs_off)
