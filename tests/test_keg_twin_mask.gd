## Headless test: Powder Keg Twin Face mask hookup.
## - The keg body material uses toon_noir_twin and the shipped keg mask.
## - The mask is 1024x1024, non-colour import, marks only in cell 2 (the 3s).
## - A keg whose faces are carved Twin wears that look (same glow defaults).
## - A keg with no Twin carve stays on toon_noir, same body colours, no mask.
## Reverting the body shader (or skipping the carve) fails this test.
##
## Run:
##   godot --headless --path . --script res://tests/test_keg_twin_mask.gd
extends SceneTree

const BODY := "res://art/models/dice/materials/powder_keg_body.tres"
const TWIN := "res://shaders/3d/toon_noir_twin.gdshader"
const TOON := "res://shaders/3d/toon_noir.gdshader"
const MASK := "res://art/fx/twin_face/powder_keg_twin_mask.png"
const FACES := "res://art/models/dice/textures/powder_keg_d6_faces.png"
const IMPORT := "res://art/fx/twin_face/powder_keg_twin_mask.png.import"

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
	print("=== Dice of the Damned: Powder Keg Twin Face mask ===")
	_test_material()
	_test_import()
	_test_pixels()
	var plain := _keg(false)
	var carved := _keg(true)
	_test_plain(plain)
	_test_carved(carved)
	_test_same_body(plain, carved)
	_test_glyph_only()
	_test_stave_dim(carved)
	_test_keg_mark(carved)
	_test_other_twin()
	plain.queue_free()
	carved.queue_free()
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


## The authored body the GLB and a Twin keg both read.
func _test_material() -> void:
	var art := load(BODY) as ShaderMaterial
	_check(art != null and art.shader != null and art.shader.resource_path == TWIN, "keg body shader is toon_noir_twin")
	var mask := art.get_shader_parameter("twin_mask") as Texture2D
	_check(mask != null and mask.resource_path == MASK, "keg body twin_mask is the keg mask")
	_check(art.get_shader_parameter("use_overlay") == true, "keg body keeps use_overlay")
	var overlay := art.get_shader_parameter("overlay_tex") as Texture2D
	_check(overlay != null and overlay.resource_path == FACES, "keg body keeps the face atlas")
	_check(art.next_pass != null, "keg body keeps the ink outline")
	# Glow uniforms are not overridden: the shader / TwinFaceGlow defaults stay.
	_check(is_equal_approx(_flt(art.get_shader_parameter("twin_strength")), 0.0), "keg body twin_strength is 0")
	_check(is_equal_approx(_flt(art.get_shader_parameter("twin_halo_strength")), 0.0), "keg body twin_halo_strength is 0")
	_check(art.get_shader_parameter("twin_glow") == null, "keg body does not override twin_glow")
	var tres_unlit: Variant = art.get_shader_parameter("twin_unlit")
	_check(tres_unlit is Color and (tres_unlit as Color).is_equal_approx(Color("#E8DCC0")), "keg body twin_unlit is cream #E8DCC0")
	var energy: Variant = art.get_shader_parameter("emission_energy")
	_check(energy == null or float(energy) <= 0.3, "body emission_energy <= 0.3")


## Same import contract as the stand-in: linear, lossless, mipmaps.
func _test_import() -> void:
	var text := FileAccess.get_file_as_string(IMPORT)
	_check("compress/mode=0" in text, "mask import is lossless (compress/mode=0)")
	_check("mipmaps/generate=true" in text, "mask import generates mipmaps")
	_check("detect_3d/compress_to=0" in text, "mask import detect_3d/compress_to=0")
	_check("process/hdr_as_srgb=false" in text, "mask import is not hdr-as-srgb")
	_check("source_color" not in text, "mask import has no source_color")
	_check("\"vram_texture\": false" in text, "mask import vram_texture false")


## Cell 2 is U 0.4-0.6, V 0.0-0.2 (image top = V 0, same as the keg atlas).
func _test_pixels() -> void:
	var img := Image.load_from_file(ProjectSettings.globalize_path(MASK))
	_check(img != null and img.get_width() == 1024 and img.get_height() == 1024, "mask is 1024x1024")
	if img == null:
		return
	var marks_in := 0
	var marks_out := 0
	var g_in_r := 0
	var b_on := 0
	var a_off := 0
	var w := img.get_width()
	var h := img.get_height()
	for y in h:
		var v := float(y) / float(h)
		for x in w:
			var u := float(x) / float(w)
			var c := img.get_pixel(x, y)
			var on := c.r > 0.0 or c.g > 0.0
			var cell2 := u >= 0.4 and u < 0.6 and v >= 0.0 and v < 0.2
			if on and cell2:
				marks_in += 1
			elif on:
				marks_out += 1
			if c.r > 0.5 and c.g > 0.02:
				g_in_r += 1
			if c.b > 0.0:
				b_on += 1
			if c.a < 0.999:
				a_off += 1
	_check(marks_in > 0 and marks_out == 0, "mask marks only in cell 2 (in %d, out %d)" % [marks_in, marks_out])
	_check(g_in_r == 0, "mask G is 0 inside R (%d)" % g_in_r)
	_check(b_on == 0, "mask B is 0")
	_check(a_off == 0, "mask A is 255")


func _keg(carved: bool) -> DieVisual:
	var td := TableDie.new(&"powder_keg", "Powder Keg", &"d6")
	var printed: Array[int] = [1, 1, 2, 2, 3, 3]
	td.faces = printed
	if carved:
		var mod := load("res://resources/mods/twin.tres") as FaceModData
		# Both 3s, the same preset the shop-bought keg gets.
		td.mods[4] = mod
		td.mods[5] = mod
	var d := DieVisual.new()
	root.add_child(d)
	DieArtMaterial.apply(d, td)
	PolyBody.dress(d, td)
	return d


func _test_plain(d: DieVisual) -> void:
	var m := d.body_material
	var art := load(BODY) as ShaderMaterial
	_check(m.shader.resource_path == TOON, "non-Twin keg stays on toon_noir")
	_check((m.get_shader_parameter("albedo") as Color).is_equal_approx(art.get_shader_parameter("albedo")), "non-Twin keg albedo unchanged")
	_check((m.get_shader_parameter("shadow_color") as Color).is_equal_approx(art.get_shader_parameter("shadow_color")), "non-Twin keg shadow unchanged")
	_check(is_equal_approx(float(m.get_shader_parameter("light_gain")), float(art.get_shader_parameter("light_gain"))), "non-Twin keg light_gain unchanged")
	_check(is_equal_approx(float(m.get_shader_parameter("roughness")), float(art.get_shader_parameter("roughness"))), "non-Twin keg roughness unchanged")
	_check(m.get_shader_parameter("twin_mask") == null, "non-Twin keg has no twin_mask")
	_check(d.get_node_or_null("TwinFaceGlow") == null, "non-Twin keg has no TwinFaceGlow")
	var overlay := m.get_shader_parameter("overlay_tex") as Texture2D
	_check(overlay != null and overlay.resource_path == FACES, "non-Twin keg still prints the face atlas")
	_check(_energy(m) <= 0.3, "non-Twin keg emission <= 0.3")


func _test_carved(d: DieVisual) -> void:
	var m := d.body_material
	var art := load(BODY) as ShaderMaterial
	_check(m.shader != null and m.shader.resource_path == TWIN, "Twin keg uses toon_noir_twin")
	var mask := m.get_shader_parameter("twin_mask") as Texture2D
	_check(mask != null and mask.resource_path == MASK, "Twin keg twin_mask is the keg mask")
	_check((m.get_shader_parameter("albedo") as Color).is_equal_approx(art.get_shader_parameter("albedo")), "Twin keg keeps the body albedo")
	_check(m.get_shader_parameter("use_overlay") == true, "Twin keg keeps use_overlay")
	var overlay := m.get_shader_parameter("overlay_tex") as Texture2D
	_check(overlay != null and overlay.resource_path == FACES, "Twin keg keeps the face atlas")
	var ink := m.next_pass as ShaderMaterial
	_check(ink != null and ink.shader.resource_path.ends_with("outline.gdshader"), "Twin keg keeps the ink outline")
	var glow := d.get_node_or_null("TwinFaceGlow") as TwinFaceGlow
	_check(glow != null and glow.material == m, "TwinFaceGlow drives the keg body")
	# Missing uniforms (hookup reverted) fail the check; they must not throw.
	var glow_col: Variant = m.get_shader_parameter("twin_glow")
	var unlit_col: Variant = m.get_shader_parameter("twin_unlit")
	_check(glow_col is Color and (glow_col as Color).is_equal_approx(Palette.EMBER), "Twin glow colour stays Ember")
	_check(is_equal_approx(_flt(m.get_shader_parameter("twin_strength")), 0.0), "keg twin_strength is 0")
	_check(is_equal_approx(_flt(m.get_shader_parameter("twin_halo_strength")), 0.0), "keg twin_halo_strength is 0")
	_check(unlit_col is Color and (unlit_col as Color).is_equal_approx(Color("#E8DCC0")), "keg twin_unlit is cream #E8DCC0")
	_check(_energy(m) <= 0.3, "Twin keg emission_energy <= 0.3 (%.3f)" % _energy(m))
	_check(d.shape == &"keg", "Twin keg still wears the barrel")


## The carved keg keeps the plain keg's body colours and the face atlas.
## Only the twin mask and its dark-brass glyph are extra.
func _test_same_body(plain: DieVisual, carved: DieVisual) -> void:
	var a := plain.body_material
	var b := carved.body_material
	for key in ["albedo", "shadow_color", "spec_color", "overlay_tint", "emission_color"]:
		var va: Variant = a.get_shader_parameter(key)
		var vb: Variant = b.get_shader_parameter(key)
		_check(va is Color and vb is Color and (va as Color).is_equal_approx(vb as Color), "Twin body matches non-Twin %s" % key)
	for key in ["light_gain", "mid_tint", "wrap", "roughness", "spec_size", "spec_strength"]:
		_check(is_equal_approx(_flt(a.get_shader_parameter(key)), _flt(b.get_shader_parameter(key))), "Twin body matches non-Twin %s" % key)
	_check(a.get_shader_parameter("use_overlay") == b.get_shader_parameter("use_overlay"), "Twin body matches non-Twin use_overlay")
	var oa := a.get_shader_parameter("overlay_tex") as Texture2D
	var ob := b.get_shader_parameter("overlay_tex") as Texture2D
	_check(oa != null and ob != null and oa.resource_path == ob.resource_path, "Twin body matches non-Twin face atlas")


## #270's stave dim and spec skip still apply after the Twin shader swap.
## Removing the keg_stave_dim include from toon_noir_twin fails this.
func _test_stave_dim(d: DieVisual) -> void:
	var src := FileAccess.get_file_as_string("res://shaders/3d/toon_noir_twin.gdshader")
	_check("keg_stave_dim.gdshaderinc" in src, "twin shader includes keg_stave_dim")
	_check("keg_ink_keep" in src, "twin shader fades the other numerals")
	_check("keg_spec_keep" in src and "keg_spec_lobe" in src, "twin shader skips the hard stave specular")
	var dim := d.get_node_or_null("KegStaveDim") as KegStaveDim
	_check(dim != null, "Twin keg wears KegStaveDim")
	_check(is_equal_approx(_flt(d.body_material.get_shader_parameter("spec_strength")), KegStaveDim.SPEC_STRENGTH), "Twin keg spec_strength is 0.05")
	var body := d.faces.get_node("Body") as MeshInstance3D
	_check(is_equal_approx(_flt(body.get_instance_shader_parameter(&"keg_body")), 1.0), "Twin keg mesh keg_body is 1")
	if dim != null:
		dim.set_read(3, true)
	_check(is_equal_approx(_flt(body.get_instance_shader_parameter(&"lit_stave")), 3.0), "Twin keg lit_stave is the landed 3")
	_check(is_equal_approx(_flt(body.get_instance_shader_parameter(&"stave_dim")), 1.0), "Twin keg stave_dim fades the other numerals")
	_check(_energy(d.body_material) <= 0.3, "stave dim adds no emission above 0.3")


## Powder Keg only: no Twin glow, glyph is cream. Reverting the colour fails.
func _test_keg_mark(d: DieVisual) -> void:
	var m := d.body_material
	_check(is_equal_approx(_flt(m.get_shader_parameter("twin_strength")), DieArtMaterial.TWIN_STRENGTH), "keg path twin_strength is 0")
	_check(is_equal_approx(_flt(m.get_shader_parameter("twin_halo_strength")), DieArtMaterial.TWIN_HALO), "keg path twin_halo_strength is 0")
	var unlit: Variant = m.get_shader_parameter("twin_unlit")
	_check(unlit is Color and (unlit as Color).is_equal_approx(Color("#E8DCC0")), "keg path twin_unlit is cream #E8DCC0")
	_check(_energy(m) <= 0.3, "keg Twin adds no emission above 0.3")


## A Twin material that is not the keg keeps the shared TwinFaceGlow defaults.
func _test_other_twin() -> void:
	_check(is_equal_approx(TwinFaceGlow.DEFAULT_STRENGTH, 1.6), "shared core strength stays 1.6")
	_check(is_equal_approx(TwinFaceGlow.DEFAULT_HALO_STRENGTH, 1.6), "shared halo strength stays 1.6")
	_check(TwinFaceGlow.DEFAULT_UNLIT.is_equal_approx(Color("#403440")), "shared unlit stays #403440")
	var mat := ShaderMaterial.new()
	mat.shader = load(TWIN) as Shader
	var glow := TwinFaceGlow.new()
	root.add_child(glow)
	glow.bind_material(mat)
	_check(is_equal_approx(_flt(mat.get_shader_parameter("twin_strength")), 1.6), "non-keg Twin strength stays 1.6")
	_check(is_equal_approx(_flt(mat.get_shader_parameter("twin_halo_strength")), 1.6), "non-keg Twin halo stays 1.6")
	var unlit: Variant = mat.get_shader_parameter("twin_unlit")
	_check(unlit is Color and (unlit as Color).is_equal_approx(Color("#403440")), "non-keg Twin unlit stays #403440")
	glow.queue_free()


## The dark unlit colour is mixed by the mask's R, not painted on the whole stave.
func _test_glyph_only() -> void:
	var code := FileAccess.get_file_as_string("res://shaders/3d/toon_noir_twin.gdshader")
	_check("mix(col, twin_unlit.rgb, twin_m.r)" in code, "unlit tint follows the mask glyph, not the whole body")
	_check("mix(col, vec3(0.02), twin_inlay_w)" in code, "settled darkening follows the gated glyph")


func _energy(m: ShaderMaterial) -> float:
	return _flt(m.get_shader_parameter("emission_energy"))


func _flt(v: Variant) -> float:
	return float(v) if v is float or v is int else 0.0
