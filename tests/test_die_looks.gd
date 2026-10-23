## Headless test: the die look table (art/dice/die_looks.tres, DieLookTable) and the die body materials (PR #139).
## Every body_by_die path (and its pip_path()) loads as a ShaderMaterial. The 5 family materials and the locked lantern
## use art/materials/dice/toon_die.gdshader, which exposes albedo_tint, bevel_map, pip_map, glow_color, glow_energy
## (default 0, never baked in), plus albedo / die_lit / die_cold / state_rim_energy so DieVisual.set_glow_state keeps
## working. The locked batch-3 bodies (art/models/dice/materials/) stay on toon_noir until their baked edge-mask pass;
## they must still expose albedo / die_lit / die_cold. An unknown die id falls back to `default` (bone). mark_by_mod
## holds exactly the 11 face-mark ids of docs/props/world_props_v1.md section 3.2, each with decal, tint (+ optional
## glow_color).
##
## Run:
##   godot --headless --path . --script res://tests/test_die_looks.gd
extends SceneTree

const LOOKS: String = "res://art/dice/die_looks.tres"
const DIE_SHADER: String = "res://art/materials/dice/toon_die.gdshader"
const TOON_SHADER: String = "res://shaders/3d/toon_noir.gdshader"
const BONE: String = "res://art/materials/dice/bone.tres"
const FAMILIES: Array[String] = ["bone", "brass", "glass", "wood", "obsidian"]
## Batch-3 bodies keep their locked toon_noir materials for now (AD: surface treatment later, baked edge-mask follow-up).
const LOCKED_DIR: String = "res://art/models/dice/materials/"
const DIE_UNIFORMS: Array[String] = ["albedo_tint", "bevel_map", "pip_map", "glow_color", "glow_energy", "albedo", "die_lit", "die_cold", "state_rim_energy"]
const GLOW_STATE_UNIFORMS: Array[String] = ["albedo", "die_lit", "die_cold", "state_rim_energy"]
const MARK_IDS: Array[String] = ["wild", "ember_pip", "hellfire", "gilded", "twin", "step", "stair", "kindling", "blood", "heavy", "blank"]

var _passed: int = 0
var _failed: int = 0


func _initialize() -> void:
	print("=== Dice of the Damned: die look table + die materials tests ===")
	var table := load(LOOKS) as DieLookTable
	_check(table != null, "die_looks.tres loads as DieLookTable")
	if table == null:
		_finish()
		return
	_check_shader_uniforms()
	_check_bodies(table)
	_check_fallback(table)
	_check_family_files()
	_check_marks(table)
	_finish()


## Uniform name -> default literal ("" if none), parsed from the shader source.
func _uniforms(path: String) -> Dictionary:
	var out: Dictionary = {}
	var sh := load(path) as Shader
	if sh == null:
		return out
	var re := RegEx.create_from_string("(?m)^\\s*uniform\\s+\\w+\\s+(\\w+)\\s*(?::[^=;]*)?(?:=\\s*([^;]+))?;")
	for m in re.search_all(sh.code):
		out[m.get_string(1)] = m.get_string(2).strip_edges()
	return out


func _check_shader_uniforms() -> void:
	var u := _uniforms(DIE_SHADER)
	_check(not u.is_empty(), "toon_die.gdshader loads and declares uniforms")
	for name in DIE_UNIFORMS:
		_check(u.has(name), "toon_die.gdshader exposes `%s`" % name)
	_check(u.has("glow_energy") and float(u.get("glow_energy", "1")) == 0.0, "toon_die glow_energy defaults to 0")
	var t := _uniforms(TOON_SHADER)
	for name in GLOW_STATE_UNIFORMS:
		_check(t.has(name), "toon_noir.gdshader exposes `%s` (locked bodies, set_glow_state)" % name)


func _check_material(path: String, what: String) -> void:
	_check(ResourceLoader.exists(path), "%s exists: %s" % [what, path])
	var mat := load(path) as ShaderMaterial
	_check(mat != null and mat.shader != null, "%s is a ShaderMaterial with a shader: %s" % [what, path])
	if mat == null or mat.shader == null:
		return
	var sp := mat.shader.resource_path
	if path.begins_with(LOCKED_DIR):
		_check(sp == TOON_SHADER, "%s (locked batch-3) uses toon_noir: %s -> %s" % [what, path, sp])
	else:
		_check(sp == DIE_SHADER, "%s uses toon_die.gdshader: %s -> %s" % [what, path, sp])
		var ge = mat.get_shader_parameter("glow_energy")
		_check(ge == null or float(ge) == 0.0, "%s does not bake glow in (glow_energy 0): %s" % [what, path])


func _check_bodies(table: DieLookTable) -> void:
	_check(table.body_by_die.has(&"default"), "body_by_die has a `default` key")
	_check(table.body_by_die.size() > 1, "body_by_die maps die ids")
	for id in table.body_by_die.keys():
		_check(id is StringName, "body_by_die key is a StringName: %s" % id)
		var p := table.body_path(id)
		_check(p == String(table.body_by_die[id]), "body_path(%s) returns its entry" % id)
		_check_material(p, "body[%s]" % id)
		var pp := table.pip_path(id)
		if pp != "":
			_check_material(pp, "pip[%s]" % id)
		elif p.begins_with("res://art/materials/dice/") and not p.contains("/locked/"):
			_check(false, "family body %s has a _pip.tres" % p)


func _check_fallback(table: DieLookTable) -> void:
	_check(String(table.body_by_die[&"default"]) == BONE, "default body is bone")
	for id in [&"no_such_die", &"", &"BONE"]:
		_check(table.body_path(id) == BONE, "unknown id '%s' falls back to bone" % id)
	_check(table.pip_path(&"no_such_die") == "res://art/materials/dice/bone_pip.tres", "unknown id falls back to the bone pip")


func _check_family_files() -> void:
	for f in FAMILIES:
		_check_material("res://art/materials/dice/%s.tres" % f, "family %s" % f)
		_check_material("res://art/materials/dice/%s_pip.tres" % f, "family %s pip" % f)


func _check_marks(table: DieLookTable) -> void:
	var keys: Array[String] = []
	for k in table.mark_by_mod.keys():
		_check(k is StringName, "mark_by_mod key is a StringName: %s" % k)
		keys.append(String(k))
	keys.sort()
	var want := MARK_IDS.duplicate()
	want.sort()
	_check(keys == want, "mark_by_mod has exactly the 11 #133 mark ids (got %s)" % [keys])
	for id in table.mark_by_mod.keys():
		var m = table.mark_by_mod[id]
		_check(m is Dictionary, "mark[%s] is a Dictionary" % id)
		if not (m is Dictionary):
			continue
		_check(m.has("decal") and (m["decal"] == null or m["decal"] is Texture2D), "mark[%s] has decal (Texture2D or null)" % id)
		_check(m.has("tint") and m["tint"] is Color, "mark[%s] has a Color tint" % id)
		_check(not m.has("glow_color") or m["glow_color"] is Color, "mark[%s] glow_color is a Color if present" % id)
		for k in m.keys():
			_check(k in ["decal", "tint", "glow_color"], "mark[%s] has only known fields (%s)" % [id, k])


func _check(cond: bool, label: String) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		print("FAIL: ", label)


func _finish() -> void:
	print("die looks: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)
