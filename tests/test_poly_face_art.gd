## Headless test: the d4 Twin and d8 rare marks keep the printed face art
## readable (the art director's rules for #237). Through the real Bonfire3D
## scene, reading the printed ink from the face texture PNG itself:
##   Gallows d4 Twin, on every Twin face:
##     - a diamond (square turned 45 deg to the face's corner line) whose
##       diagonal is 22% of the face height, a dark #1E1712 rim under a
##       solid brass #C9A24A fill;
##     - no printed ink inside it (it never covers a printed circle);
##     - set in toward the face middle, not out in a corner.
##   Beacon d8 Step (slot 7):
##     - if a 30% badge fits in a corner clear of the numeral's box: a disc
##       of 30% face height, clear of the box, in the corner farthest from
##       the numeral;
##     - otherwise: no disc at all, the numeral itself tinted brass.
## The 22% / 30% sizes are written here on purpose, not read from the code.
##   godot --headless --path . --script res://tests/test_poly_face_art.gd
extends SceneTree

const BRASS := Color("#C9A24A")
const OUTLINE := Color("#1E1712")

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


func mod(effect: FaceModData.Effect) -> FaceModData:
	var m := FaceModData.new()
	m.id = &"test_mod"
	m.effect = effect
	return m


func _run() -> void:
	var T := FaceModData.Effect.TWIN
	var g := TableDie.new(DiceIds.DIE_GALLOWS, "Gallows", DiceIds.shape_of(DiceIds.DIE_GALLOWS))
	g.mods = [mod(T), mod(T), mod(T), mod(T)]
	var b := TableDie.new(DiceIds.DIE_BEACON, "Beacon", DiceIds.shape_of(DiceIds.DIE_BEACON))
	b.mods = [null, null, null, null, null, null, load("res://resources/mods/step.tres"), null]
	var st := TableSetup.new()
	st.dice.append(g)
	st.dice.append(b)
	st.run_mode = false
	st.table_seed = 5
	var s := (load("res://scenes/bonfire.tscn") as PackedScene).instantiate() as Bonfire3D
	s.setup = st
	root.add_child(s)
	await process_frame
	_check_d4(s.all_dice[0])
	_check_d8(s.all_dice[1], 7)
	s.queue_free()
	await process_frame
	print("test_poly_face_art: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


## The 4 Twin diamonds: [rim, fill] per face, in FaceMods order.
func _check_d4(d: DieVisual) -> void:
	var kids := d.faces.get_node("FaceMods").get_children()
	check(kids.size() == 8, "d4: 4 Twin faces x (rim + fill) (%d)" % kids.size())
	var img := FacePrint.image_of(d)
	check(img != null, "d4: face art texture readable")
	for k in mini(4, kids.size() / 2):
		var rim := kids[2 * k] as MeshInstance3D
		var fill := kids[2 * k + 1] as MeshInstance3D
		var f := PolyBody.face_tri(d, k + 1)  # slots count from 1
		var h: float = f.h
		var side: float = (rim.mesh as QuadMesh).size.x
		var diag := side * sqrt(2.0)
		check(absf(diag / h - 0.22) < 0.22 * 0.05, "d4 face %d: diamond is 22%% of face height (%.3f)" % [k + 1, diag / h])
		var x := rim.transform.basis.x.normalized()
		var a: Vector3 = (f.tri[0] - f.g).normalized()
		check(absf(absf(x.dot(a)) - sqrt(0.5)) < 0.02, "d4 face %d: square turned 45 deg (a diamond)" % (k + 1))
		check(_col(rim).is_equal_approx(OUTLINE), "d4 face %d: dark #1E1712 rim" % (k + 1))
		check(_col(fill).is_equal_approx(BRASS), "d4 face %d: solid brass #C9A24A fill" % (k + 1))
		var fs: float = (fill.mesh as QuadMesh).size.x
		check(fs < side and fs > side - 0.1 * h, "d4 face %d: fill leaves a thin rim (%.3f h)" % [k + 1, (side - fs) / h])
		check(fill.transform.origin.dot(f.normal) > rim.transform.origin.dot(f.normal), "d4 face %d: fill on top of rim" % (k + 1))
		# No printed ink inside the diamond (|u| + |v| <= half diagonal).
		var c := rim.transform.origin
		var hits := 0
		if img != null:
			var b := a.cross(f.normal)
			for p in FacePrint.ink_points(d, f, img):
				if absf((p - c).dot(a)) + absf((p - c).dot(b)) <= diag * 0.5:
					hits += 1
		check(hits == 0, "d4 face %d: diamond covers no printed circle (%d ink)" % [k + 1, hits])
		var mid: Vector3 = c - f.normal * (c - f.g).dot(f.normal)
		check(mid.distance_to(f.g) < 0.25 * h, "d4 face %d: set in toward the face middle (%.2f h)" % [k + 1, mid.distance_to(f.g) / h])


## The d8 rare glyph on [param slot]: corner badge, or the brass numeral.
func _check_d8(d: DieVisual, slot: int) -> void:
	var mark := d.faces.get_node("FaceMods").get_child(0) as Node3D
	check(mark != null and String(mark.name).begins_with("RareMark_"), "d8: rare mark drawn")
	var f := PolyBody.face_tri(d, slot)
	var h: float = f.h
	var img := FacePrint.image_of(d)
	var ink := FacePrint.ink_points(d, f, img)
	var box := FacePrint.numeral_box(ink, f.normal, (f.tri[0] as Vector3).distance_to(f.tri[1]) / 72.0)
	var r := 0.15 * h
	var fits := FacePrint.best_badge(f, box, r, 0.05 * h) != Vector3.ZERO
	var discs := _meshes(mark, "CylinderMesh")
	if not fits:
		check(discs.is_empty(), "d8: no room for a 30%% badge, so no disc (%d)" % discs.size())
		var tint := mark.get_node_or_null("NumeralTint") as MeshInstance3D
		check(tint != null, "d8: numeral tinted instead")
		if tint != null:
			var m := tint.material_override as StandardMaterial3D
			check(m.albedo_color.is_equal_approx(BRASS), "d8: tint is brass #C9A24A")
			check(m.albedo_texture != null, "d8: tint follows the printed art (numeral stays readable)")
		return
	check(discs.size() == 1, "d8: one badge disc (%d)" % discs.size())
	if discs.is_empty():
		return
	var dia: float = (discs[0].mesh.get_aabb().size.x) * (mark.transform * discs[0].transform).basis.x.length()
	check(absf(dia / h - 0.30) < 0.30 * 0.05, "d8: badge is 30%% of face height (%.3f)" % (dia / h))
	var c := mark.transform.origin
	check(not FacePrint.circle_hits_box(c, dia * 0.5, box), "d8: badge clear of the numeral box")
	var far := 0
	var near := 0
	for i in 3:
		if (f.tri[i] as Vector3).distance_to(box.centre) > (f.tri[far] as Vector3).distance_to(box.centre):
			far = i
		if (f.tri[i] as Vector3).distance_to(c) < (f.tri[near] as Vector3).distance_to(c):
			near = i
	check(near == far, "d8: badge in the corner farthest from the numeral")


func _col(mi: MeshInstance3D) -> Color:
	return (mi.material_override as StandardMaterial3D).albedo_color


func _meshes(n: Node, cls: String) -> Array:
	var out := []
	for c in n.get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).mesh != null and (c as MeshInstance3D).mesh.get_class() == cls:
			out.append(c)
		out.append_array(_meshes(c, cls))
	return out
