## Headless test: the AD proof-pass looks for Extra, Beacon and Bellows.
##   - Beacon (a rare d8) uses its own authored body (brass-tan #B8925A,
##     dark numerals), NOT the generic rare tint that hid it on the table;
##     the dressed d8 Body draws that material, with no RareTrim shell;
##   - Extra: dark body #3A2E24 + brass rim, unlike Wanderer;
##   - Bellows: body #6B4A38, shadow #2A1C16;
##   - each gets a 1.5x outline: Extra brass, Beacon / Bellows cream.
##   godot --headless --path . --script res://tests/test_proof_dice_look.gd
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


## The outline pass: colour [param col], 1.5x the stock ink width.
func _ink(d: DieVisual, col: Color, what: String) -> void:
	var o := d.body_material.next_pass as ShaderMaterial
	var base := load("res://art/models/dice/materials/die_ink_outline.tres") as ShaderMaterial
	check(o != null and _near(o.get_shader_parameter("color"), col), what + ": outline colour")
	check(o != null and is_equal_approx(float(o.get_shader_parameter("width")), float(base.get_shader_parameter("width")) * 1.5), what + ": outline 1.5x")


func _run() -> void:
	var b: DieVisual = await _die(&"beacon")
	var body := b.faces.get_node("Body") as MeshInstance3D
	check(b.shape == &"d8", "Beacon dressed as a d8")
	check(body.material_override == b.body_material, "Beacon Body draws the die material")
	check(_near(b.body_material.get_shader_parameter("albedo"), Color("#B8925A")), "Beacon body #B8925A (not the rare tint)")
	check(_near(b.body_material.get_shader_parameter("shadow_color"), Color("#4A3424")), "Beacon shadow #4A3424")
	var tint: Variant = b.body_material.get_shader_parameter("overlay_tint")
	check(tint is Color and (tint as Color).get_luminance() < 0.2, "Beacon numerals dark")
	check(b.body_material.get_shader_parameter("overlay_tex") != null, "Beacon keeps its printed numbers")
	check(body.get_node_or_null("RareTrim") == null, "Beacon: no rare trim shell")
	_ink(b, Color("#E8DCC0"), "Beacon")
	var e: DieVisual = await _die(&"extra")
	check(_near(e.body_material.get_shader_parameter("albedo"), Color("#3A2E24")), "Extra body #3A2E24")
	check(_near(e.body_material.get_shader_parameter("shadow_color"), Color("#1E1712")), "Extra shadow #1E1712")
	check(_near(e.body_material.get_shader_parameter("rim_color"), Color("#C9A24A")), "Extra brass rim")
	var pip := load("res://art/models/dice/materials/extra_pip.tres") as ShaderMaterial
	check(pip != null and _near(pip.get_shader_parameter("albedo"), Color("#C9A24A")), "Extra brass pips")
	var w := load("res://art/models/dice/materials/wanderer_pip.tres") as ShaderMaterial
	check(not _near(w.get_shader_parameter("albedo"), Color("#C9A24A")), "Extra pips differ from Wanderer's")
	_ink(e, Color("#C9A24A"), "Extra")
	var bl: DieVisual = await _die(&"bellows")
	check(_near(bl.body_material.get_shader_parameter("albedo"), Color("#6B4A38")), "Bellows body #6B4A38")
	check(_near(bl.body_material.get_shader_parameter("shadow_color"), Color("#2A1C16")), "Bellows shadow #2A1C16")
	_ink(bl, Color("#E8DCC0"), "Bellows")
	print("test_proof_dice_look: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)
