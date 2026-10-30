## PM #198: the Gallows d4 reads like the d6. The table lamp's shadow leaves
## its sloped faces near black, so (through the real Bonfire scene):
##   - the d4 has its own always-on body glow (DieVisual.base_emission), in a
##     lighter shade of its body colour, and a d6 has none;
##   - highlight adds to that glow instead of overwriting it;
##   - the glow comes back after a scoring glow is cleared (DieGlow.clear);
##   - a camera-facing value tag floats above the d4's top point, unlit,
##     showing the die's value, and stays upright when the die tumbles.
##   godot --headless --path . --script res://tests/test_d4_readable.gd
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


func _run() -> void:
	var st := TableSetup.new()
	st.dice.append(TableDie.new(DiceIds.DIE_GALLOWS, "Gallows", DiceIds.shape_of(DiceIds.DIE_GALLOWS)))
	st.dice.append(TableDie.new())
	st.run_mode = false
	st.table_seed = 5
	var s := (load("res://scenes/bonfire.tscn") as PackedScene).instantiate() as Bonfire3D
	s.setup = st
	root.add_child(s)
	await process_frame
	var d4: DieVisual = s.all_dice[0]
	var d6: DieVisual = s.all_dice[1]
	check(d4.shape == &"d4", "Gallows is dressed as a d4")
	await _check_glow(d4, d6)
	await _check_tag(d4, d6)
	s.queue_free()
	await process_frame
	print("test_d4_readable: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _energy(d: DieVisual) -> float:
	return float(d.body_material.get_shader_parameter("emission_energy"))


func _check_glow(d4: DieVisual, d6: DieVisual) -> void:
	await process_frame  # the table's own glow reset runs first; the tag restores it
	check(d4.base_emission >= 0.4, "d4 base glow %.2f >= 0.4 (lifts its shadowed faces)" % d4.base_emission)
	check(is_equal_approx(d6.base_emission, 0.0), "d6 keeps no base glow")
	check(_energy(d4) >= d4.base_emission - 0.001, "d4 emission %.2f carries its glow" % _energy(d4))
	var body: Color = d4.body_material.get_shader_parameter("albedo")
	var glow: Color = d4.body_material.get_shader_parameter("emission_color")
	check(glow.get_luminance() > body.get_luminance() + 0.1, "d4 glow colour is lighter than its body")
	d4.highlight = 1.0
	check(is_equal_approx(_energy(d4), d4.base_emission + 0.12), "highlight adds to the glow (%.2f)" % _energy(d4))
	d4.highlight = 0.0
	check(is_equal_approx(_energy(d4), d4.base_emission), "highlight off keeps the glow")
	DieGlow.apply(d4, 1)
	DieGlow.clear(d4)
	await process_frame
	await process_frame
	check(_energy(d4) >= d4.base_emission - 0.001, "glow back after a scoring glow clears (%.2f)" % _energy(d4))
	check(d4.body_material.get_shader_parameter("emission_color") == glow, "and in its own colour")


func _check_tag(d4: DieVisual, d6: DieVisual) -> void:
	var tag := d4.get_node_or_null("D4ValueTag") as Label3D
	check(tag != null, "d4 has a value tag")
	check(d6.get_node_or_null("D4ValueTag") == null, "d6 has no value tag")
	if tag == null:
		return
	check(tag.billboard == BaseMaterial3D.BILLBOARD_ENABLED, "tag turns to face the camera")
	check(not tag.shaded and tag.fixed_size, "tag is unlit and fixed-size (readable at 1x)")
	d4.faces.rotation = Vector3(0.7, 1.3, 2.1)
	d4.rotation = Vector3(0.4, 0.9, -0.6)  # the whole die tumbling, too
	await process_frame
	await process_frame
	check(tag.text == str(d4.shown_value()), "tag shows the die's value (%s vs %d)" % [tag.text, d4.shown_value()])
	var up := tag.global_position - d4.global_position
	check(up.y > PolyDie.cap_for(&"d4") and Vector2(up.x, up.z).length() < 0.001, "tag sits straight above the top point (%s)" % str(up))
	check(tag.global_basis.is_equal_approx(Basis()), "tag stays upright when the die tumbles")
