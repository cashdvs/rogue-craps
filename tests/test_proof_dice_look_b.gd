## Headless test: AD proof pass B (Nov 1).
##   - (Nov 1 10:05 PM AD calls: see the Wanderer / Ossuary / Fortune checks.)
##   - Mirror / Powder Keg: 1.2x cream #E8DCC0 outline;
##   - Ossuary ash #9A948A, Fortune brass #C9A24A (dark pips), Barrel wood
##     #7A5534 with two brass HoopBands, Usurer obsidian #1E1A18 with cream
##     pips + 1.3x brass outline: authored bodies, no generic rare trim;
##   - Bellows wears the plain cube (no slatted art body);
##   - the printed-number sheet is not sampled anisotropically (that
##     speckled Beacon's d8 faces, QA PR 248).
##   godot --headless --path . --script res://tests/test_proof_dice_look_b.gd
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


func _near(a: Variant, b: Color) -> bool:
	return a is Color and absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) < 0.01


## Builds a table holding just die [param id] and returns its DieVisual
## (dressed by the scene's own _ready, as in a real game).
func _die(id: StringName) -> DieVisual:
	var st := TableSetup.new()
	st.dice.append(TableDie.new(id, String(id), DiceIds.shape_of(id)))
	st.run_mode = false
	st.table_seed = 3
	var s := (load("res://scenes/bonfire.tscn") as PackedScene).instantiate() as Bonfire3D
	s.setup = st
	root.add_child(s)
	await process_frame
	await process_frame
	return s.dice[0]


func _width(d: DieVisual) -> float:
	var base := load("res://art/models/dice/materials/die_ink_outline.tres") as ShaderMaterial
	var o := d.body_material.next_pass as ShaderMaterial
	return float(o.get_shader_parameter("width")) / float(base.get_shader_parameter("width")) if o != null else 0.0


## Die [param id]: outline colour [param ink] at [param mul] x width.
func _ink(id: StringName, ink: String, mul: float) -> void:
	var d: DieVisual = await _die(id)
	var o := d.body_material.next_pass as ShaderMaterial
	check(o != null and _near(o.get_shader_parameter("color"), Color(ink)), "%s outline %s" % [id, ink])
	check(is_equal_approx(_width(d), mul), "%s outline %sx (got %s)" % [id, mul, _width(d)])


## Rare [param id]: authored body [param body] and pips [param pip].
func _rare(id: StringName, body: String, pip: String) -> DieVisual:
	var d: DieVisual = await _die(id)
	check(_near(d.body_material.get_shader_parameter("albedo"), Color(body)), "%s body %s" % [id, body])
	check(_near(d._pip_color, Color(pip)), "%s pips %s" % [id, pip])
	check(not d.has_meta("rare_look"), "%s: no generic rare tint" % id)
	return d


## WCAG contrast of [param a] on [param b], both lit by the table lamp (#FFB070).
func _lamp_contrast(a: Color, b: Color) -> float:
	var k := Color("#FFB070").srgb_to_linear()
	var la := a.srgb_to_linear()
	var lb := b.srgb_to_linear()
	var ya := 0.2126 * la.r * k.r + 0.7152 * la.g * k.g + 0.0722 * la.b * k.b
	var yb := 0.2126 * lb.r * k.r + 0.7152 * lb.g * k.g + 0.0722 * lb.b * k.b
	return (maxf(ya, yb) + 0.05) / (minf(ya, yb) + 0.05)


func src_has_ink_mode() -> bool:
	var c := (load("res://shaders/3d/toon_noir.gdshader") as Shader).code
	return c.find("if (ink_from_tint) { ink.rgb = overlay_tint.rgb; }") != -1


func _run() -> void:
	## AD add-on: Blood Pact wears a 1.3x brass keyline (Wild strips kept).
	await _ink(&"blood_pact", "#C9A24A", 1.3)
	## Gilded's .tres pair gets dark #1E1712 pips (the Gilt die wears the rare
	## tint with dark pips in play). Wanderer keeps cream: its blue body renders
	## near-black under the red lamp in-table, so dark pips vanish (sheet B).
	var gb: Color = (load("res://art/models/dice/materials/gilded_body.tres") as ShaderMaterial).get_shader_parameter("albedo")
	var gp: Color = (load("res://art/models/dice/materials/gilded_pip.tres") as ShaderMaterial).get_shader_parameter("albedo")
	check(_near(gp, Color("#1E1712")), "gilded dark #1E1712 pips")
	var cd := _lamp_contrast(gb, Color("#1E1712"))
	var cc := _lamp_contrast(gb, Color("#E8DCC0"))
	print("gilded pips under the lamp: dark %.2f, cream %.2f" % [cd, cc])
	check(cd >= 3.5 and cd > cc, "gilded: dark pips >= 3.5:1 (%.2f vs cream %.2f)" % [cd, cc])
	var wd: DieVisual = await _die(&"wanderer")
	check(_near(wd._pip_color, Color("#F2E6C8")), "wanderer keeps cream pips")
	## AD Nov 1 10:05 PM: Wanderer slate-blue #5E7C9A, cream pips >= 3.5:1,
	## a thin (1.0x) dark ink outline; Bellows keeps its 1.3x cream keyline.
	var wb: Color = (load("res://art/models/dice/materials/wanderer_body.tres") as ShaderMaterial).get_shader_parameter("albedo")
	check(_near(wb, Color("#5E7C9A")), "wanderer body #5E7C9A")
	var wc := _lamp_contrast(wb, wd._pip_color)
	print("wanderer cream pips under the lamp: %.2f" % wc)
	check(wc >= 3.5, "wanderer pips >= 3.5:1 (%.2f)" % wc)
	await _ink(&"wanderer", "#16130F", 1.0)
	await _ink(&"bellows", "#E8DCC0", 1.3)
	## Ossuary: 1.5x dark ink outline; Fortune: 1.3x brass keyline + the brass trim.
	await _ink(&"ossuary", "#E8DCC0", 1.2)
	await _ink(&"fortune", "#C9A24A", 1.3)
	## AD Nov 1 10:45 PM: Barrel takes whichever pip (cream / dark) reaches 3.5:1;
	## Ossuary #8A857C with dark pips (printed: the AD's pair lands just under 3.5).
	var bc := _lamp_contrast(Color("#7A5534"), Color("#E8DCC0"))
	var bd := _lamp_contrast(Color("#7A5534"), Color("#16130F"))
	print("barrel pips under the lamp: cream %.2f, dark %.2f" % [bc, bd])
	check(bc >= 3.5 and bc > bd, "barrel: cream pips >= 3.5:1 (%.2f)" % bc)
	## Ossuary (AD final): cream pips, 3.48:1 accepted as an art exception (>= 3.4 guard).
	var oc := _lamp_contrast(Color("#6E6A62"), Color("#E8DCC0"))
	print("ossuary cream pips under the lamp: %.2f" % oc)
	check(oc >= 3.4, "ossuary pips >= 3.4:1 art exception (%.2f)" % oc)
	## Beacon: numerals printed in dark #1E1712 itself (not the sheet's cream), >= 4.5:1.
	var bn: DieVisual = await _die(&"beacon")
	var tint: Variant = bn.body_material.get_shader_parameter("overlay_tint")
	check(_near(tint, Color("#1E1712")), "beacon numerals #1E1712")
	check(bn.body_material.get_shader_parameter("ink_from_tint") == true, "beacon numerals use the tint colour")
	var nc := _lamp_contrast(bn.body_material.get_shader_parameter("albedo"), tint)
	print("beacon numerals under the lamp: %.2f" % nc)
	check(nc >= 4.5, "beacon numerals >= 4.5:1 (%.2f)" % nc)
	check(src_has_ink_mode(), "toon_noir can print numbers in the tint colour")
	for id in [&"mirror", &"powder_keg"]:
		await _ink(id, "#E8DCC0", 1.2)
	await _ink(&"usurer", "#C9A24A", 1.3)
	var os: DieVisual = await _rare(&"ossuary", "#6E6A62", "#E8DCC0")
	check(os.faces.get_node("Body").get_node_or_null("HoopBands") == null, "Ossuary: no hoops")
	var fo: DieVisual = await _rare(&"fortune", "#C9A24A", "#1A1210")
	check(fo.faces.get_node("Body").has_node("RareTrim"), "Fortune: brass rare trim")
	check(not os.faces.get_node("Body").has_node("RareTrim"), "Ossuary: no rare trim")
	var caps := os.faces.get_node("Body").get_node_or_null("CornerCaps") as MeshInstance3D
	check(caps != null, "Ossuary: corner caps")
	if caps != null:
		var cm := caps.material_override as ShaderMaterial
		check(_near(cm.get_shader_parameter("color"), Color("#E8DCC0")), "Ossuary caps bone-cream")
		check(cm.shader.code.find("unshaded") != -1 and cm.shader.code.find("EMISSION") == -1, "Ossuary caps unlit, no glow")
		check(is_equal_approx(float(cm.get_shader_parameter("cap")), 0.30), "Ossuary caps 15% of the edge")
	check(fo.faces.get_node("Body").get_node_or_null("CornerCaps") == null, "Fortune: no caps")
	await _rare(&"usurer", "#1E1A18", "#E8DCC0")
	var br: DieVisual = await _rare(&"barrel", "#7A5534", "#E8DCC0")
	var hoops := br.faces.get_node("Body").get_node_or_null("HoopBands")
	check(hoops != null and hoops.get_child_count() == 2, "Barrel: two hoop bands")
	if hoops != null and hoops.get_child_count() == 2:
		var hb := hoops.get_child(0) as MeshInstance3D
		var m := hb.material_override as ShaderMaterial
		check(m != null and _near(m.get_shader_parameter("color"), Color("#C9A24A")), "Barrel hoops brass")
		check(m != null and m.shader.code.find("EMISSION") == -1, "Barrel hoops do not glow")
		## QA PR 250: the hoops follow the body (its own mesh, just proud), not box bars.
		check(hb.mesh == (br.faces.get_node("Body") as MeshInstance3D).mesh and hb.scale.x < 1.03, "Barrel hoops sit flush on the body")
	var bl: DieVisual = await _die(&"bellows")
	var bm := (bl.faces.get_node("Body") as MeshInstance3D).mesh
	check(bm == bl.get_meta(&"cube_mesh"), "Bellows: plain cube, no slats")
	var src := (load("res://shaders/3d/toon_noir.gdshader") as Shader).code
	check(src.find("overlay_tex : source_color, filter_linear_mipmap_anisotropic") == -1, "number sheet not anisotropic")
	print("test_proof_dice_look_b: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)
