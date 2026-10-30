## Rare dice look (playtest e1cd912 bug 1, Art Director colours): every
## mark clears 3:1 against its plate, avoids the reserved red / cyan /
## violet, has its own glyph, and glows (<= 0.3) only while lit.
extends SceneTree

var _passed: int = 0
var _failed: int = 0


func _initialize() -> void:
	_test_colours()
	_test_marks()
	_test_rarity()
	_test_mark_size()
	_test_trim()
	print("=== rare die look: %d passed, %d failed ===" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _check(c: bool, what: String) -> void:
	_passed += int(c)
	_failed += int(not c)
	if not c: print("FAIL: ", what)


func _test_colours() -> void:
	var body := RareDieLook.body_color()
	_check(RareDieLook.BODY_TINT == Color("#C8A878") and is_equal_approx(RareDieLook.BODY_TINT_AMOUNT, 0.55), "body tint is #C8A878 at 55%")
	var want := Palette.BONE.lerp(Palette.BONE * Color("#C8A878"), 0.55)
	_check(body.is_equal_approx(want), "body is Bone x #C8A878 multiplied at 55%% (%s)" % body)
	var pk := RareDieLook.contrast(body, Palette.PIT_BLACK)
	_check(pk >= 3.0, "pips keep >= 3:1 on the rare body (%.2f)" % pk)
	var dist := Vector3(body.r - Palette.BONE.r, body.g - Palette.BONE.g, body.b - Palette.BONE.b).length()
	_check(dist > 0.05, "rare body is visibly off Bone (%.3f)" % dist)
	_check(RareDieLook.MARK_EMISSION_MAX <= 0.3, "mark emission at most 0.3")
	var avoid: Array[Color] = [Color("#FF2E3E"), Color("#4FE6E0")]
	var seen: Array[Color] = []
	for id: StringName in RareDieLook.MARKS:
		var c: Color = RareDieLook.MARKS[id]
		var k := RareDieLook.contrast(c, RareDieLook.PLATE)
		_check(k >= RareDieLook.MIN_CONTRAST, "%s mark contrast %.2f >= 3:1 on its plate" % [id, k])
		for a in avoid:
			_check(Vector3(c.r - a.r, c.g - a.g, c.b - a.b).length() > 0.25, "%s mark is clear of %s" % [id, a.to_html(false)])
		var violet := c.s > 0.15 and c.h > 0.70 and c.h < 0.90
		_check(not violet, "%s mark is not violet (h %.2f s %.2f)" % [id, c.h, c.s])
		_check(not seen.has(c), "%s mark has its own colour" % id)
		seen.append(c)


func _marks_on(id: StringName) -> Node3D:
	var d := DieVisual.new(0.08)
	root.add_child(d)
	var fm := Node3D.new()
	fm.name = "FaceMods"
	d.faces.add_child(fm)
	var n := Vector3.UP
	RareDieLook.add_mark(fm, d, n, Vector3.RIGHT, Vector3.BACK, d.edge * 0.52, id)
	return d


func _test_marks() -> void:
	var shapes := {}
	for id: StringName in RareDieLook.MARKS:
		var d := _marks_on(id) as DieVisual
		var fm := d.faces.get_node("FaceMods")
		var mark := fm.get_node_or_null("RareMark_%s" % id) as Node3D
		_check(mark != null, "%s: a mark node is added" % id)
		if mark == null:
			d.free()
			continue
		var sig := []
		for c in mark.get_children():
			var mi := c as MeshInstance3D
			sig.append([mi.mesh.get_class(), snappedf(mi.position.x, 0.0001), snappedf(mi.position.y, 0.0001), snappedf(mi.rotation.z, 0.01)])
		var key := str(sig)
		_check(not shapes.has(key), "%s: its glyph differs from %s" % [id, shapes.get(key, "the others")])
		shapes[key] = id
		var ink := mark.get_meta("ink") as StandardMaterial3D
		_check(ink.albedo_color == RareDieLook.MARKS[id], "%s: ink is its colour" % id)
		_check(ink.emission_energy_multiplier == 0.0, "%s: no glow while unlit" % id)
		RareDieLook.set_marks_lit(d, true)
		_check(ink.emission_energy_multiplier > 0.0 and ink.emission_energy_multiplier <= 0.3 + 1e-6, "%s: lit glow in (0, 0.3]" % id)
		RareDieLook.set_marks_lit(d, false)
		_check(ink.emission_energy_multiplier == 0.0, "%s: glow off again" % id)
		var flame := false
		for c in mark.get_children():
			flame = flame or c is GPUParticles3D or c is CPUParticles3D or c is Light3D
		_check(not flame, "%s: no flame / light / particles" % id)
		d.free()
	var r := Node3D.new()
	var dv := DieVisual.new()
	_check(not RareDieLook.add_mark(r, dv, Vector3.UP, Vector3.RIGHT, Vector3.BACK, 0.04, &"twin") and r.get_child_count() == 0, "non-rare mods get no mark")
	r.free()
	dv.free()


func _test_rarity() -> void:
	for id: StringName in [&"barrel", &"fortune", &"usurer", &"gallows", &"beacon"]:
		_check(RareDieLook.is_rare(id), "%s is rare" % id)
	for id: StringName in [&"bone", &"mirror", &"lantern", &""]:
		_check(not RareDieLook.is_rare(id), "%s is not rare" % id)


## Readable at table zoom: on every face value (1..6 pips) each mark's plate
## (rim included) is at least MIN_FACE_FRACTION of the face edge, at least
## ROOMY_FRACTION where the pips leave room (1..3), clear of every pip, and
## the glyph fills most of the plate.
const MIN_FACE_FRACTION := 0.25
const ROOMY_FRACTION := 0.34
func _test_mark_size() -> void:
	var up_slot: int = DieVisual.FACE_AXES.find_key(Vector3.UP)
	for pips in range(1, 7):
		for id: StringName in RareDieLook.MARKS:
			var d := DieVisual.new(0.08)
			root.add_child(d)
			var labels: Array[int] = [1, 2, 3, 4, 5, 6]
			labels[up_slot - 1] = pips
			d.set_look(Palette.BONE, Palette.PIT_BLACK, labels)
			var fm := Node3D.new()
			fm.name = "FaceMods"
			d.faces.add_child(fm)
			RareDieLook.add_mark(fm, d, Vector3.UP, Vector3.RIGHT, Vector3.BACK, d.edge * 0.52, id)
			var mark := fm.get_node("RareMark_%s" % id) as Node3D
			var outer := (mark.get_child(0) as MeshInstance3D).mesh as CylinderMesh
			var frac := outer.top_radius * 2.0 / d.edge
			var want := ROOMY_FRACTION if pips <= 3 else MIN_FACE_FRACTION
			_check(frac >= want - 1e-4, "%s on a %d: mark is %.2f of the face (>= %.2f)" % [id, pips, frac, want])
			var c := Vector2(mark.position.x, -mark.position.z)
			var clear := true
			for p in d.faces.get_node("Pips").get_children():
				var q := (p as Node3D).position
				if q.y > d.edge * 0.3:
					clear = clear and Vector2(q.x, -q.z).distance_to(c) >= outer.top_radius + 0.09 * d.edge - 1e-5
			_check(clear, "%s on a %d: mark clears every pip" % [id, pips])
			var reach := 0.0
			for k in range(2, mark.get_child_count()):
				var mi := mark.get_child(k) as MeshInstance3D
				var sz := mi.get_aabb().size
				reach = maxf(reach, Vector2(mi.position.x, mi.position.y).length() + maxf(sz.x, maxf(sz.y, sz.z)) * 0.5)
			_check(reach >= outer.top_radius * 0.55, "%s on a %d: glyph fills the plate (%.4f of %.4f)" % [id, pips, reach, outer.top_radius])
			d.free()


## Brass bevel trim: #E6C46A, no emission, bevel normals only, its own node
## (not the #162 hull outline), and gone again when the die stops being rare.
func _test_trim() -> void:
	_check(RareDieLook.TRIM == Color("#E6C46A"), "trim is brass #E6C46A")
	_check(not RareDieLook.TRIM_SHADER.contains("EMISSION") and not RareDieLook.TRIM_FLAT_SHADER.contains("EMISSION"), "trim has no emission")
	_check(is_equal_approx(RareDieLook.TRIM_FLAT, 0.80), "trim mask threshold 0.80")
	var up := Vector3.UP
	_check(RareDieLook.is_frame_point(Vector3(0.33, 0.5, 0.0), up, 1.0), "frame line at 0.33 edge")
	_check(not RareDieLook.is_frame_point(Vector3(0.30, 0.5, 0.1), up, 1.0) and not RareDieLook.is_frame_point(Vector3(0.36, 0.5, 0.0), up, 1.0), "no frame at 0.30 (pips) or 0.36 (bevel)")
	_check(RareDieLook.FRAME_HALF > 0.0 and RareDieLook.FRAME_HALF < 0.02, "frame about 1 px at 48 px")
	for sh in [RareDieLook.TRIM_SHADER, RareDieLook.TRIM_FLAT_SHADER]:
		_check(sh.contains("abs(m - frame_at) > frame_half"), "both trim passes draw the frame")
	_check(is_equal_approx(RareDieLook.TRIM_UNSHADED, 0.7) and RareDieLook.TRIM_UNSHADED <= RareDieLook.TRIM_UNSHADED_MAX, "trim mixes 70% toward flat albedo, within its cap")
	var d := DieVisual.new()
	root.add_child(d)
	RareDieLook.set_trim(d, true)
	var body := d.faces.get_node("Body") as MeshInstance3D
	var t := body.get_node_or_null("RareTrim") as MeshInstance3D
	_check(t != null and t != d.hull_outline and t.mesh == body.mesh, "trim is its own copy of the body mesh")
	var m := t.material_override as ShaderMaterial if t != null else null
	_check(m != null and (m.get_shader_parameter("trim") as Color).is_equal_approx(RareDieLook.TRIM), "trim shader draws brass at full strength")
	var f := m.next_pass as ShaderMaterial if m != null else null
	_check(f != null and f.shader.code.contains("unshaded") and f.shader.code.contains("discard") and is_equal_approx(f.get_shader_parameter("mix_amount"), 0.7) \
			and (f.get_shader_parameter("trim") as Color).is_equal_approx(RareDieLook.TRIM) and is_equal_approx(f.get_shader_parameter("flat_limit"), RareDieLook.TRIM_FLAT), "flat pass: unshaded brass at 70%, same bevel mask")
	_check(m != null and m.shader.code.contains("discard") and is_equal_approx(m.get_shader_parameter("flat_limit"), RareDieLook.TRIM_FLAT), "trim shader masks flat faces")
	# Every body vertex: flat-face ones get no trim, bevel ones do, and the
	# trim covers some but well under half the surface (never all-gold).
	var arr := body.mesh.surface_get_arrays(0)
	var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var flat := 0
	var trim := 0
	var wrong := 0
	for n in norms:
		var a := n.abs()
		var is_flat := maxf(a.x, maxf(a.y, a.z)) > 0.9999
		var tr := RareDieLook.is_trim_normal(n)
		flat += int(is_flat)
		trim += int(tr)
		wrong += int(is_flat and tr)
	_check(wrong == 0, "no trim on a flat-face normal (%d wrong of %d)" % [wrong, norms.size()])
	_check(trim > 0 and flat > 0, "trim on the bevel, flat faces bare (%d trim, %d flat of %d)" % [trim, flat, norms.size()])
	for n in [Vector3.UP, Vector3.LEFT, Vector3.BACK]:
		_check(not RareDieLook.is_trim_normal(n), "flat face %s has no trim" % n)
	_check(RareDieLook.is_trim_normal(Vector3(1, 1, 0)) and RareDieLook.is_trim_normal(Vector3(1, 1, 1)), "edge and corner normals take the trim")
	# A thin edge band, not the whole round: 15 deg off a face stays bare.
	_check(not RareDieLook.is_trim_normal(Vector3(0, 1, 0).rotated(Vector3.RIGHT, deg_to_rad(15))), "trim is a thin edge band (15 deg off face is bare)")
	_check(not RareDieLook.is_trim_normal(Vector3(0, 1, 0).rotated(Vector3.RIGHT, deg_to_rad(34))) and RareDieLook.is_trim_normal(Vector3(0, 1, 0).rotated(Vector3.RIGHT, deg_to_rad(40))), "trim starts ~37 deg off a face (0.80)")
	RareDieLook.set_trim(d, false)
	_check(body.get_node_or_null("RareTrim") == null, "set_trim off removes the trim")
	d.free()
