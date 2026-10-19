## Headless test: Twin Face glow mask (Powder Keg Ember glyph).
## - GDScript mirror of the up-facing / settled gate matches expectations.
## - Include source contains the up-face gate (smoothstep + settled multiply).
## - TwinFaceGlow sets `settled` on settle (fade) and clears on throw / impact.
## - Shader + include + stand-in mask exist; material accepts uniforms.
##
## Run:
##   godot --headless --path . --script res://tests/test_fx_twin_face_mask.gd
extends SceneTree

const SHADER := "res://shaders/3d/toon_noir_twin.gdshader"
const INCLUDE := "res://shaders/3d/twin_face_mask.gdshaderinc"
const STANDIN := "res://art/fx/twin_face/twin_face_mask_standin.png"
const TOON := "res://shaders/3d/toon_noir.gdshader"

var _passed: int = 0
var _failed: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _check(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		print("FAIL  ", what)


func _run() -> void:
	print("=== Dice of the Damned: Twin Face glow mask ===")
	_test_files()
	_test_include_gate()
	_test_up_weight()
	_test_mask_lit()
	_test_colours()
	await _test_driver()
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _test_files() -> void:
	_check(ResourceLoader.exists(SHADER), "toon_noir_twin.gdshader exists")
	_check(ResourceLoader.exists(INCLUDE), "twin_face_mask.gdshaderinc exists")
	_check(ResourceLoader.exists(STANDIN), "stand-in mask PNG exists")
	_check(ResourceLoader.exists(TOON), "toon_noir.gdshader still present (untouched path)")
	var sh := load(SHADER) as Shader
	_check(sh != null, "twin shader loads")
	if sh != null:
		var code := sh.code
		_check("twin_face_mask.gdshaderinc" in code or "twin_up_weight" in code, "twin shader includes / uses mask math")
	var inc := FileAccess.get_file_as_string(INCLUDE)
	var mask_line := ""
	for line in inc.split("\n"):
		if "uniform sampler2D twin_mask" in line:
			mask_line = line
			break
	_check("hint_default_black" in mask_line and "source_color" not in mask_line, "twin_mask sampler is non-colour: %s" % mask_line)
	_check("up_lo" in inc and "twin_halo_strength" in inc, "include exposes up_lo/up_hi and twin_halo_strength")


## Source-level: removing the up-face gate from the include must fail this test.
func _test_include_gate() -> void:
	var inc := FileAccess.get_file_as_string(INCLUDE)
	_check("smoothstep(up_lo, up_hi," in inc or "smoothstep(up_lo, up_hi, y)" in inc, "include has smoothstep(up_lo, up_hi, …) up ramp")
	_check("normalize(world_n).y" in inc or "world_n).y" in inc, "include reads world normal .y")
	_check("settled" in inc and "*" in inc, "include multiplies by settled")
	# Tighter: the gate line shape from twin_mask_sample.
	_check("clamp(settled" in inc and "twin_up_weight" in inc, "include gate = settled * twin_up_weight(...)")


func _test_up_weight() -> void:
	_check(is_equal_approx(TwinFaceGlow.up_weight(Vector3.UP), 1.0), "world up → weight 1")
	_check(TwinFaceGlow.up_weight(Vector3.DOWN) < 0.01, "world down → weight 0 (opposite stave dark)")
	_check(TwinFaceGlow.up_weight(Vector3.RIGHT) < 0.01, "side normal → weight 0")
	var lo: float = TwinFaceGlow.DEFAULT_UP_LO
	var hi: float = TwinFaceGlow.DEFAULT_UP_HI
	var y_lo: float = lo
	var y_mid: float = (lo + hi) * 0.5
	var y_hi: float = hi
	var n_lo := Vector3(sqrt(1.0 - y_lo * y_lo), y_lo, 0.0)
	var n_mid := Vector3(sqrt(1.0 - y_mid * y_mid), y_mid, 0.0)
	var n_hi := Vector3(sqrt(maxf(0.0, 1.0 - y_hi * y_hi)), y_hi, 0.0)
	var at_lo := TwinFaceGlow.up_weight(n_lo)
	var at_mid := TwinFaceGlow.up_weight(n_mid)
	var at_hi := TwinFaceGlow.up_weight(n_hi)
	_check(at_lo < 0.05, "at up_lo → ~0 (%.3f)" % at_lo)
	_check(at_mid > 0.45 and at_mid < 0.55, "mid ramp → ~0.5 (%.3f)" % at_mid)
	_check(at_hi > 0.95, "at up_hi → ~1 (%.3f)" % at_hi)
	_check(is_equal_approx(lo, 0.80) and is_equal_approx(hi, 0.92), "defaults up_lo=0.80 up_hi=0.92")


func _test_mask_lit() -> void:
	var up := Vector3.UP
	var lit := TwinFaceGlow.mask_lit(1.0, 0.5, 1.0, up)
	_check(is_equal_approx(lit.x, 1.0) and is_equal_approx(lit.y, 0.5), "settled + up → full inlay/halo %s" % lit)
	var rolling := TwinFaceGlow.mask_lit(1.0, 0.5, 0.0, up)
	_check(rolling.length() < 0.01, "settled=0 → dark even when up %s" % rolling)
	var other := TwinFaceGlow.mask_lit(1.0, 0.5, 1.0, Vector3.DOWN)
	_check(other.length() < 0.01, "opposite face up → dark %s" % other)


func _test_colours() -> void:
	_check(Palette.EMBER.is_equal_approx(Color("#E8622A")), "Palette.EMBER is #E8622A")
	var u := TwinFaceGlow.DEFAULT_UNLIT
	_check(u.is_equal_approx(Color("#403440")), "unlit default is #403440 (renders ~#692B16)")
	var g := Palette.EMBER
	_check(not (g.h > 0.45 and g.h < 0.55), "glow not cyan (%s)" % g)
	_check(not (g.h > 0.70 and g.h < 0.92), "glow not violet (%s)" % g)
	_check(is_equal_approx(TwinFaceGlow.DEFAULT_STRENGTH, 1.6), "core strength default 1.6")
	_check(is_equal_approx(TwinFaceGlow.DEFAULT_HALO_STRENGTH, 1.6), "halo strength default 1.6")


func _test_driver() -> void:
	var sh := load(SHADER) as Shader
	var mat := ShaderMaterial.new()
	mat.shader = sh
	var tex := load(STANDIN) as Texture2D
	_check(tex != null, "stand-in texture loads")
	mat.set_shader_parameter(&"twin_mask", tex)
	var glow := TwinFaceGlow.new()
	root.add_child(glow)
	glow.bind_material(mat)
	_check(Color(mat.get_shader_parameter(&"twin_glow")).is_equal_approx(Palette.EMBER), "bind sets Ember glow")
	_check(is_equal_approx(float(mat.get_shader_parameter(&"twin_strength")), 1.6), "bind sets core strength 1.6")
	_check(is_equal_approx(float(mat.get_shader_parameter(&"twin_halo_strength")), 1.6), "bind sets halo strength 1.6")
	_check(is_equal_approx(float(mat.get_shader_parameter(&"up_lo")), 0.80), "bind sets up_lo 0.80")
	_check(is_equal_approx(float(mat.get_shader_parameter(&"up_hi")), 0.92), "bind sets up_hi 0.92")
	_check(is_equal_approx(float(mat.get_shader_parameter(&"settled")), 0.0), "starts unsettled")
	# Fake table.events: real TableEvents.dice_settled() takes no args.
	var ev := Node.new()
	ev.add_user_signal("dice_settled")
	ev.add_user_signal("dice_thrown", [{"name": "flick_speed_px_s", "type": TYPE_FLOAT}])
	root.add_child(ev)
	glow.bind_events(ev)
	ev.emit_signal("dice_settled")
	_check(is_equal_approx(glow._target, 1.0), "dice_settled aims settled → 1")
	await create_timer(TwinFaceGlow.FADE_IN + 0.1, true, false, true).timeout
	_check(float(mat.get_shader_parameter(&"settled")) > 0.95, "settled fades in to ~1 (%.2f)" % float(mat.get_shader_parameter(&"settled")))
	ev.emit_signal("dice_thrown", 2000.0)
	_check(is_equal_approx(float(mat.get_shader_parameter(&"settled")), 0.0), "dice_thrown clears settled immediately")
	# bind_die: lights on settled, clears on impact (next throw).
	var die := Node.new()
	die.add_user_signal("settled", [{"name": "die_id", "type": TYPE_INT}, {"name": "face", "type": TYPE_INT}])
	die.add_user_signal("impact", [
		{"name": "die_id", "type": TYPE_INT}, {"name": "surface", "type": TYPE_STRING},
		{"name": "speed_mps", "type": TYPE_FLOAT}, {"name": "impulse", "type": TYPE_FLOAT},
		{"name": "other_id", "type": TYPE_INT}, {"name": "material", "type": TYPE_STRING},
	])
	root.add_child(die)
	glow.bind_events(null)
	glow.bind_die(die)
	die.emit_signal("settled", 1, 3)
	_check(is_equal_approx(glow._target, 1.0), "DieVisual.settled fallback aims settled → 1")
	await create_timer(TwinFaceGlow.FADE_IN + 0.1, true, false, true).timeout
	_check(float(mat.get_shader_parameter(&"settled")) > 0.95, "bind_die settled fades in")
	die.emit_signal("impact", 1, "felt", 3.5, 0.1, -1, "bone")
	_check(is_equal_approx(float(mat.get_shader_parameter(&"settled")), 0.0), "bind_die impact clears settled (mid-roll dark)")
	# Guard: events without signals don't crash and leave settled off.
	var empty := Node.new()
	root.add_child(empty)
	glow.bind_events(empty)
	_check(is_equal_approx(float(mat.get_shader_parameter(&"settled")), 0.0), "bind_events without signals leaves settled off")
	glow.queue_free()
	ev.queue_free()
	die.queue_free()
	empty.queue_free()
	await process_frame
