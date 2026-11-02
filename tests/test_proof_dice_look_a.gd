## Headless test: AD proof pass A (Nov 1) for Twin Flame, Blood Pact, Coven.
##   - Twin Flame: charcoal #2A2420 / shadow #14100D, light ember #FFB866 pips,
##     1.3x brass #C9A24A outline;
##   - Blood Pact: wine #6E2A2A / shadow #2E1212, cream pips, 1.3x brass
##     #C9A24A keyline (pass B), still a Wild red body;
##   - Coven: #8C7CD6 / shadow #3A3266, dark #1A1622 pips, 1.3x cream outline;
##   - Twin Flame and Blood Pact pips read >= 3.5:1 against the body under
##     the table's warm-red lamp (#FFB070), WCAG on the lit albedos (AD fix);
##   - none of them glows (pip emission stays <= 0.3).
##   godot --headless --path . --script res://tests/test_proof_dice_look_a.gd
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


## Checks die [param id]: body, shadow, pip colour and a 1.3x outline [param ink].
func _look(id: StringName, body: String, shadow: String, pip: String, ink: String) -> void:
	var d: DieVisual = await _die(id)
	check(_near(d.body_material.get_shader_parameter("albedo"), Color(body)), "%s body %s" % [id, body])
	check(_near(d.body_material.get_shader_parameter("shadow_color"), Color(shadow)), "%s shadow %s" % [id, shadow])
	check(_near(d._pip_color, Color(pip)), "%s pips %s" % [id, pip])
	var o := d.body_material.next_pass as ShaderMaterial
	var base := load("res://art/models/dice/materials/die_ink_outline.tres") as ShaderMaterial
	check(o != null and _near(o.get_shader_parameter("color"), Color(ink)), "%s outline %s" % [id, ink])
	check(o != null and is_equal_approx(float(o.get_shader_parameter("width")), float(base.get_shader_parameter("width")) * 1.3), "%s outline 1.3x" % id)
	var pm := load("res://art/models/dice/materials/%s_pip.tres" % id) as ShaderMaterial
	var em: Variant = pm.get_shader_parameter("emission_energy")
	check(em == null or float(em) <= 0.3, "%s pips do not glow" % id)


## WCAG luminance of colour [param c] lit by the table lamp (#FFB070).
func _lit_lum(c: Color) -> float:
	var l := c.srgb_to_linear()
	var k := Color("#FFB070").srgb_to_linear()
	return 0.2126 * l.r * k.r + 0.7152 * l.g * k.g + 0.0722 * l.b * k.b


## Pip-to-body contrast of the spawned die [param id] under the lamp.
func _contrast(id: StringName) -> float:
	var d: DieVisual = await _die(id)
	var a := _lit_lum(d.body_material.get_shader_parameter("albedo"))
	var b := _lit_lum(d._pip_color)
	return (maxf(a, b) + 0.05) / (minf(a, b) + 0.05)


func _run() -> void:
	await _look(&"twin_flame", "#2A2420", "#14100D", "#FFB866", "#C9A24A")
	await _look(&"blood_pact", "#6E2A2A", "#2E1212", "#E8DCC0", "#C9A24A")
	await _look(&"coven", "#8C7CD6", "#3A3266", "#1A1622", "#E8DCC0")
	for id: StringName in [&"twin_flame", &"blood_pact"]:
		var cr: float = await _contrast(id)
		print("%s pip/body contrast under the lamp: %.2f" % [id, cr])
		check(cr >= 3.5, "%s pips >= 3.5:1 on the body (%.2f)" % [id, cr])
	check(&"blood_pact" in BonfireTableState.WILD_RED_BODIES, "Blood Pact keeps its Wild red-body keyline")
	print("test_proof_dice_look_a: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)
