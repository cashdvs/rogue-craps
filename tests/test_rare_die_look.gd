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
	print("=== rare die look: %d passed, %d failed ===" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _check(c: bool, what: String) -> void:
	_passed += int(c)
	_failed += int(not c)
	if not c: print("FAIL: ", what)


func _test_colours() -> void:
	var body := RareDieLook.body_color()
	_check(RareDieLook.BODY_TINT == Color("#D9C08A") and is_equal_approx(RareDieLook.BODY_TINT_AMOUNT, 0.35), "body tint is #D9C08A at 35%")
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
