## Headless test: the Bellows d6 per-face shade (#215). Guards the face_shade values on
## bellows_body.tres / bellows_pip.tres, the raised body albedo, and a material-level contrast
## check (top vs side value, pip vs body WCAG contrast) using the shader's own face_shade formula.
## Fails if face_shade is set back to 0.
##
## Run:
##   godot --headless --path . --script res://tests/test_bellows_face_shade.gd
extends SceneTree

const BODY := "res://art/models/dice/materials/bellows_body.tres"
const PIP := "res://art/models/dice/materials/bellows_pip.tres"
const BODY_ALBEDO := Color(0.850980, 0.823529, 0.741176, 1)

var _pass := 0
var _fail := 0


func _check(ok: bool, msg: String) -> void:
	if ok:
		_pass += 1
		print("  ok ", msg)
	else:
		_fail += 1
		print("  FAIL ", msg)


func _lum(c: Color) -> float:
	var l := c.srgb_to_linear()
	return 0.2126 * l.r + 0.7152 * l.g + 0.0722 * l.b


func _contrast(a: Color, b: Color) -> float:
	var la := _lum(a)
	var lb := _lum(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


func _init() -> void:
	print("=== Dice of the Damned: Bellows face_shade ===")
	var body := load(BODY) as ShaderMaterial
	var pip := load(PIP) as ShaderMaterial
	_check(body != null and pip != null, "materials load")
	if body == null or pip == null:
		print("=== %d passed, %d failed ===" % [_pass, _fail])
		quit(1)
		return
	var bfs := float(body.get_shader_parameter("face_shade"))
	var pfs := float(pip.get_shader_parameter("face_shade"))
	_check(is_equal_approx(bfs, 0.22), "body face_shade 0.22 (got %s)" % bfs)
	_check(is_equal_approx(pfs, 0.6), "pip face_shade 0.6 (got %s)" % pfs)
	var ba: Color = body.get_shader_parameter("albedo")
	_check(ba.is_equal_approx(BODY_ALBEDO), "body albedo %s" % ba)
	var pa: Color = pip.get_shader_parameter("albedo")
	# Shader: side faces get col *= 1 - face_shade; the up face is unshaded.
	var body_side := Color(ba.r * (1 - bfs), ba.g * (1 - bfs), ba.b * (1 - bfs))
	var pip_side := Color(pa.r * (1 - pfs), pa.g * (1 - pfs), pa.b * (1 - pfs))
	var drop := 1.0 - body_side.get_luminance() / ba.get_luminance()
	_check(drop >= 0.2, "body side value >= 20%% darker than top (%.1f%%)" % (drop * 100))
	var ct := _contrast(ba, pa)
	var cs := _contrast(body_side, pip_side)
	_check(ct >= 3.0, "pip/body contrast top >= 3:1 (%.2f)" % ct)
	_check(cs >= 3.0, "pip/body contrast side >= 3:1 (%.2f)" % cs)
	print("=== %d passed, %d failed ===" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
