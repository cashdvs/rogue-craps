## Headless test: the Bellows d6 per-face shade (#215). Guards the face_shade values on
## bellows_body.tres / bellows_pip.tres, the raised body albedo, and a material-level contrast
## check (top vs side value, pip vs body WCAG contrast) using the shader's own face_shade formula.
## Fails if face_shade is set back to 0. Also renders it for real: launches
## tests/support/face_shade_render.gd in a child Godot on the opengl3 (Compatibility) renderer
## (the runner's --headless has no GPU), which draws a cube with bellows_body.tres as shipped and
## with face_shade = 0, and checks the side face is darker only with face_shade on. Deleting the
## face_shade branch in toon_noir.gdshader fails this. Needs a display: with no DISPLAY /
## WAYLAND_DISPLAY (Linux) the render checks print 'SKIPPED: no display ...' and count as neither
## pass nor fail. If either is set, a helper that fails to start, returns no/partial result, or
## reports a non-opengl3 renderer is a hard FAIL. The material-value checks always run.
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
	_render_check()
	print("=== %d passed, %d failed ===" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)


func _lum3(v: Array) -> float:
	return 0.2126 * float(v[0]) + 0.7152 * float(v[1]) + 0.0722 * float(v[2])


func _skip(why: String) -> void:
	print("  SKIPPED: no display (%s); render checks not run, counted as neither pass nor fail" % why)


func _has_display() -> bool:
	if OS.get_name() != "Linux" and not OS.get_name().ends_with("BSD"):
		return true
	return OS.get_environment("DISPLAY") != "" or OS.get_environment("WAYLAND_DISPLAY") != ""


func _render_check() -> void:
	if not _has_display():
		_skip("DISPLAY and WAYLAND_DISPLAY are both unset")
		return
	# A display is present: from here on every problem is a hard FAIL, never a skip, so a shader
	# compile crash or a renderer fallback can't pass silently.
	var out: Array = []
	var args := ["--rendering-driver", "opengl3", "--path", ProjectSettings.globalize_path("res://"),
		"--script", "res://tests/support/face_shade_render.gd"]
	var code := OS.execute(OS.get_executable_path(), args, out, true)
	var r = null
	for line in "\n".join(out).split("\n"):
		if line.begins_with("FS_RESULT "):
			r = JSON.parse_string(line.trim_prefix("FS_RESULT "))
	if not r is Dictionary:
		_check(false, "render helper failed to start or gave no FS_RESULT (exit %d) with a display set (DISPLAY='%s' WAYLAND_DISPLAY='%s')" % [code, OS.get_environment("DISPLAY"), OS.get_environment("WAYLAND_DISPLAY")])
		return
	var keys_ok: bool = r.has("top_on") and r.has("side_on") and r.has("top_off") and r.has("side_off")
	_check(keys_ok, "render helper returned all four samples (got keys %s)" % str(r.keys()))
	var drv := str(r.get("driver", ""))
	_check(drv == "opengl3", "rendered with opengl3 (got '%s')" % drv)
	if not keys_ok or drv != "opengl3":
		return
	var top_on := _lum3(r["top_on"])
	var top_off := _lum3(r["top_off"])
	var side_on := _lum3(r["side_on"])
	var side_off := _lum3(r["side_off"])
	_check(top_off > 0.1, "render is lit (top %.3f)" % top_off)
	var side_drop := 1.0 - side_on / maxf(side_off, 0.0001)
	_check(side_drop >= 0.15, "rendered side face >= 15%% darker with face_shade than without (%.1f%%)" % (side_drop * 100))
	_check(absf(top_on - top_off) < 0.02, "rendered top face unchanged by face_shade (%.3f vs %.3f)" % [top_on, top_off])
	_check(1.0 - side_on / maxf(top_on, 0.0001) >= 0.15, "rendered side darker than top (%.3f vs %.3f)" % [side_on, top_on])
