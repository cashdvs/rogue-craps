## Headless tests for the VFX lighting layers (lighting_layers_spec.md
## sections 4 and 5): contact blob opacity per renderer, scale and fade vs
## height, hidden above 0.25 m / held / potted, die material untouched;
## dust counts per platform, never below 0.08 m, off under reduced motion.
##
## Run:
##   godot --headless --path . --script res://tests/test_lighting_layers_fx.gd
extends SceneTree


class FakeTable extends Node3D:
	var dice: Array[DieVisual] = []
	var pot_dice: Array[DieVisual] = []
	var phase: int = Table3D.Phase.BET
	var reduced_motion: bool = false
	func is_reduced_motion() -> bool:
		return reduced_motion


var _passed: int = 0
var _failed: int = 0


func _initialize() -> void:
	print("=== Dice of the Damned: lighting layers fx tests ===")
	_run.call_deferred()


func _run() -> void:
	_test_curves()
	await _test_blobs(true)
	await _test_blobs(false)
	await _test_dust(false)
	await _test_dust(true)
	_test_hook()
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _check(condition: bool, name: String) -> void:
	if condition:
		_passed += 1
	else:
		_failed += 1
		print("FAIL: ", name)


func _near(a: float, b: float, name: String) -> void:
	_check(absf(a - b) < 1e-4, "%s (got %f, want %f)" % [name, a, b])


func _test_curves() -> void:
	_near(ContactShadows.alpha_at(0.0, true), 0.55, "F+ rest alpha 0.55")
	_near(ContactShadows.alpha_at(0.0, false), 0.65, "Compat rest alpha 0.65")
	_near(ContactShadows.alpha_at(0.125, true), 0.275, "F+ alpha halves at 0.125 m")
	_near(ContactShadows.alpha_at(0.125, false), 0.325, "Compat alpha halves at 0.125 m")
	_near(ContactShadows.scale_at(0.0), 1.0, "scale 1 at rest")
	_near(ContactShadows.scale_at(0.125), 1.3, "scale 1.3 at 0.125 m")
	_near(ContactShadows.scale_at(0.25), 1.6, "scale +60% at 0.25 m")
	_near(ContactShadows.scale_at(1.0), 1.6, "scale capped at +60%")
	_near(ContactShadows.scale_at(-0.01), 1.0, "no shrink below rest")
	_check(ContactShadows.visible_at(0.25), "visible at 0.25 m")
	_check(not ContactShadows.visible_at(0.251), "hidden above 0.25 m")
	_near(ContactShadows.alpha_at(0.3, false), 0.0, "alpha 0 above 0.25 m")
	var prev := 1.0
	var mono := true
	for i in 26:
		var a := ContactShadows.alpha_at(i * 0.01, true)
		mono = mono and a <= prev + 1e-6
		prev = a
	_check(mono, "alpha falls monotonically with height")
	var tex := ContactShadows.blob_texture().get_image()
	_check(tex.get_width() == 64 and tex.get_height() == 64, "blob texture 64 px")
	_check(tex.get_pixel(32, 32).a > 0.99 and tex.get_pixel(32, 32).r == 0.0, "blob centre solid black")
	_check(tex.get_pixel(0, 32).a < 0.01, "blob edge transparent")


func _test_blobs(fplus: bool) -> void:
	var tag := "F+" if fplus else "Compat"
	var t := FakeTable.new()
	root.add_child(t)
	var a := DieVisual.new(0.06)
	var b := DieVisual.new(0.06)
	t.add_child(a)
	t.add_child(b)
	t.dice = [a, b] as Array[DieVisual]
	a.global_position = Vector3(0.1, 0.03, 0.2)
	b.global_position = Vector3(-0.2, 0.03 + 0.15, 0.0)
	var mats := [a.body_material, b.body_material]
	var params := [a.body_material.get_shader_parameter("emission_energy"), a.body_material.get_shader_parameter("albedo")]
	var fx := LightingLayersFx.new()
	t.add_child(fx)
	fx.bind(t, "forward_plus" if fplus else "gl_compatibility")
	await process_frame
	fx.shadows.update_now()
	var ba := fx.shadows.blob_for(a)
	var bb := fx.shadows.blob_for(b)
	_check(ba != null and bb != null, tag + ": one blob per die")
	if ba == null or bb == null:
		t.queue_free()
		return
	var mat := ba.material_override as StandardMaterial3D
	_near(mat.albedo_color.a, 0.55 if fplus else 0.65, tag + ": rest blob alpha")
	_check(mat.albedo_color.r == 0.0 and mat.albedo_color.g == 0.0 and mat.albedo_color.b == 0.0, tag + ": blob is black")
	_near((ba.mesh as QuadMesh).size.x, 0.096, tag + ": diameter 1.6 x edge (0.06 -> 0.096)")
	_near(ba.global_position.y, 0.002, tag + ": blob on the felt")
	_near(ba.global_position.x, 0.09, tag + ": follows die x (-0.01 offset)")
	_near(ba.global_position.z, 0.21, tag + ": follows die z (+0.01 offset)")
	_near(bb.scale.x, 1.36, tag + ": mid-air blob scaled (h 0.15)")
	_near((bb.material_override as StandardMaterial3D).albedo_color.a, (0.55 if fplus else 0.65) * 0.4, tag + ": mid-air blob faded")
	_check(not (a.get_node("Blob") as Node3D).visible, tag + ": old built-in blob hidden")
	a.rotate_x(1.0)
	fx.shadows.update_now()
	_check(ba.global_transform.basis.is_equal_approx(Basis()), tag + ": blob never rotates with the die")
	b.global_position.y = 0.03 + 0.3
	fx.shadows.update_now()
	_check(not bb.visible, tag + ": hidden above 0.25 m")
	t.phase = Table3D.Phase.HELD
	fx.shadows.update_now()
	_check(not ba.visible, tag + ": hidden while held")
	t.phase = Table3D.Phase.BET
	t.pot_dice = [a] as Array[DieVisual]
	fx.shadows.update_now()
	_check(not ba.visible, tag + ": hidden when potted")
	_check(a.body_material == mats[0] and b.body_material == mats[1], tag + ": die materials are the same objects")
	_check(a.body_material.get_shader_parameter("emission_energy") == params[0] and a.body_material.get_shader_parameter("albedo") == params[1], tag + ": die material params untouched")
	var body := a.get_node("Faces/Body") as MeshInstance3D
	_check(body.material_override == mats[0] and body.material_overlay == null, tag + ": no override/overlay on the die mesh")
	_check(ba.get_parent() == fx.shadows, tag + ": blob lives under the fx node, not the die")
	t.queue_free()
	await process_frame


func _test_dust(mobile: bool) -> void:
	var tag := "mobile" if mobile else "PC"
	var t := FakeTable.new()
	root.add_child(t)
	var fx := LightingLayersFx.new()
	t.add_child(fx)
	fx.bind(t, "gl_compatibility" if mobile else "forward_plus")
	await process_frame
	var p := fx.dust.particles
	_check((p is CPUParticles3D) if mobile else (p is GPUParticles3D), tag + ": particle node type")
	_check(fx.dust.amount() == (16 if mobile else 48), tag + ": count cap")
	var sm: Variant = fx.dust.particles.get("scale_amount_min" if mobile else "process_material")
	if mobile:
		_near(float(sm), 0.003, tag + ": min size 3 mm")
		_near(float(p.get("scale_amount_max")), 0.004, tag + ": max size 4 mm")
	else:
		var pm := sm as ParticleProcessMaterial
		_near(pm.scale_min, 0.002, tag + ": min size 2 mm")
		_near(pm.scale_max, 0.004, tag + ": max size 4 mm")
		_check(pm.initial_velocity_max <= 0.03, tag + ": slow drift")
	var mat := ((p.get("mesh" if mobile else "draw_pass_1")) as Mesh).surface_get_material(0) as ShaderMaterial
	_check((mat.get_shader_parameter("tint") as Color).to_html(false).to_upper() == "FFE2B0", tag + ": colour #FFE2B0")
	_near(float(mat.get_shader_parameter("peak")), 0.15 if mobile else 0.18, tag + ": alpha")
	_check(float(mat.get_shader_parameter("floor_y")) >= 0.08, tag + ": shader floor at 0.08 m")
	var bottom := p.position.y - float(p.get("emission_ring_height") if mobile else (p.get("process_material") as ParticleProcessMaterial).emission_ring_height) * 0.5
	_near(bottom, 0.25, tag + ": emission starts 0.25 m above felt")
	_check(LampDust.lowest_emitted_y() >= 0.08, tag + ": drift never descends toward the felt")
	_check(fx.dust.is_emitting(), tag + ": emitting normally")
	t.reduced_motion = true
	await process_frame
	await process_frame
	_check(not fx.dust.is_emitting() and not p.visible, tag + ": off under reduced motion")
	t.reduced_motion = false
	await process_frame
	await process_frame
	_check(fx.dust.is_emitting(), tag + ": back on after reduced motion")
	t.queue_free()
	await process_frame


func _test_hook() -> void:
	var src := FileAccess.get_file_as_string("res://scripts/table3d/table_3d.gd")
	_check(src.count("add_child(LightingLayersFx.new())") == 1, "one add_child hook in table_3d.gd")
