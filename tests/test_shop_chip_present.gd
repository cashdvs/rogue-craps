## Shop shelf chips: one tint per existing tier, a larger scale, and the face
## aimed at the shop camera. Prices, odds and ChipLooks tiers are not touched.
##   godot --headless --path . --script res://tests/test_shop_chip_present.gd
extends SceneTree

var _passed := 0
var _failed := 0

## One id per ChipLooks tier (C common, S special, R rare).
const SAMPLES: Array[StringName] = [&"thumb", &"fuse_cord", &"double_down"]


func _initialize() -> void:
	_test_palette()
	await _test_shelf()
	_test_plain_chip_unchanged()
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _check(ok: bool, what: String) -> void:
	if ok:
		_passed += 1
	else:
		_failed += 1
		print("FAIL: ", what)


## The palette has exactly the existing tiers, and every colour is distinct.
func _test_palette() -> void:
	_check(ShopChipBuild.RARITY_TINT.size() == ChipLooks.TIER.size(),
		"one tint per existing tier (%d tints, %d tiers)" % [ShopChipBuild.RARITY_TINT.size(), ChipLooks.TIER.size()])
	var seen: Array[Color] = []
	for tier: StringName in ChipLooks.TIER:
		_check(ShopChipBuild.RARITY_TINT.has(tier), "tint exists for tier %s" % tier)
		if not ShopChipBuild.RARITY_TINT.has(tier):
			continue
		var tint: Color = ShopChipBuild.RARITY_TINT[tier]
		var clash := false
		for other: Color in seen:
			var d := Vector3(tint.r, tint.g, tint.b).distance_to(Vector3(other.r, other.g, other.b))
			if tint.is_equal_approx(other) or d < 0.25:
				clash = true
		_check(not clash, "tint for %s is distinct (%s)" % [tier, tint])
		seen.append(tint)
	_check(ShopChipBuild.SHOP_CHIP_SCALE >= 1.25 and ShopChipBuild.SHOP_CHIP_SCALE <= 1.4,
		"shelf scale is in 1.25-1.4 (got %s)" % ShopChipBuild.SHOP_CHIP_SCALE)


## A real shelf item gets the tint, the scale, and a camera-facing face.
func _test_shelf() -> void:
	var host := Node3D.new()
	root.add_child(host)
	var items: Array[ShopItem] = []
	for id: StringName in SAMPLES:
		var look: Dictionary = ChipLooks.look(id)
		var o := ShopOffer._make(ShopOffer.Kind.CHIP, 0, id, str(look.get("name", "")), id, 10)
		var it := ShopItem.new()
		root.add_child(it)
		it.setup(o, 100, 120.0, 28, 1.0)
		items.append(it)
	await process_frame
	for it: ShopItem in items:
		var id := it.offer.id
		var tier: StringName = ChipLooks.look(id).tier
		var chip := it.find_child("Chip_%s" % id, true, false) as Node3D
		_check(chip != null, "%s chip node is on the shelf item" % id)
		if chip == null:
			continue
		var rim := _rim(chip)
		var mat := rim.material_override as ShaderMaterial
		var albedo: Color = mat.get_shader_parameter("albedo")
		var want: Color = ShopChipBuild.RARITY_TINT[tier]
		_check(albedo.is_equal_approx(want), "%s rim got the %s tint (got %s want %s)" % [id, tier, albedo, want])
		var glow := float(mat.get_shader_parameter("emission_energy"))
		_check(glow <= 0.3 and is_zero_approx(glow), "%s rim emission stays 0 (got %s)" % [id, glow])
		_check(is_equal_approx(chip.scale.x, ShopChipBuild.SHOP_CHIP_SCALE)
			and is_equal_approx(chip.scale.y, ShopChipBuild.SHOP_CHIP_SCALE),
			"%s scale is the shelf scale (got %s)" % [id, chip.scale])
		var face := _face(chip)
		_check(face != null, "%s keeps its face disc" % id)
		if face != null:
			var face_mat := face.material_override as StandardMaterial3D
			_check(face_mat.albedo_texture != null, "%s face art stays on the disc" % id)
			_check(face_mat.albedo_color.is_equal_approx(Color.WHITE), "%s face disc is not recoloured" % id)
		var dot := _face_dot(it, chip)
		_check(dot > 0.95, "%s face points at the shop camera (dot %.3f)" % [id, dot])
		_check(_inside_icon(it, chip), "%s stays inside its icon" % id)
		var foot := (it.icon as ShopIcon).rig.contact_local()
		var vs := Vector2((it.icon as ShopIcon).rig.view.size)
		_check(foot.y > vs.y * 0.5 and foot.y <= vs.y + 0.5,
			"%s foot stays in the icon for the pad (%.1f of %.0f)" % [id, foot.y, vs.y])
	# Hover lifts the Control. The face basis must stay aimed at the camera.
	var lifted := items[0]
	var chip0 := lifted.find_child("Chip_%s" % lifted.offer.id, true, false) as Node3D
	lifted.lift(true)
	# An idle slide (no rotation) must not turn the face away either.
	chip0.position += ShopChipBuild._camera_up() * 0.05
	await process_frame
	var after := _face_dot(lifted, chip0)
	_check(after > 0.95, "hover lift and a slide keep the face toward the camera (dot %.3f)" % after)
	for it: ShopItem in items:
		it.free()


## The HUD path (shop_chip false) keeps the clay / brass / bone rim and the fit scale.
func _test_plain_chip_unchanged() -> void:
	var o := ShopOffer._make(ShopOffer.Kind.CHIP, 0, &"thumb", "Thumb Chip", &"thumb", 10)
	var rig := ShopDieRender.make(o, 36.0, false)
	root.add_child(rig)
	var chip := rig.view.get_child(0) as Node3D
	var rim := _rim(chip)
	var albedo: Color = (rim.material_override as ShaderMaterial).get_shader_parameter("albedo")
	var clay: Color = ChipLooks.TIER[&"C"].rim
	_check(albedo.is_equal_approx(clay), "plain chip keeps the clay rim (got %s)" % albedo)
	_check(not is_equal_approx(chip.scale.x, ShopChipBuild.SHOP_CHIP_SCALE),
		"plain chip scale is the icon fit, not the shelf scale")
	rig.free()


func _rim(chip: Node3D) -> MeshInstance3D:
	return ShopChipBuild._rim_mesh(chip)


func _face(chip: Node3D) -> MeshInstance3D:
	var found: MeshInstance3D = null
	for m: Node in chip.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.material_override is StandardMaterial3D and (mi.material_override as StandardMaterial3D).albedo_texture != null:
			if found == null or mi.position.y < found.position.y:
				found = mi
	return found


func _camera(it: ShopItem) -> Camera3D:
	var view: SubViewport = (it.icon as ShopIcon).die_view
	for c: Node in view.get_children():
		if c is Camera3D:
			return c
	return null


## Dot of the face normal with the direction from the face to the camera.
func _face_dot(it: ShopItem, chip: Node3D) -> float:
	var face := _face(chip)
	var cam := _camera(it)
	if face == null or cam == null:
		return 0.0
	var normal := face.global_transform.basis.y.normalized()
	var to_cam := (cam.global_position - face.global_position).normalized()
	return normal.dot(to_cam)


## Rim samples in the face plane. The world AABB of a turned chip is wider than
## the disc, so this uses points on the rim itself (radius a little past the body).
func _inside_icon(it: ShopItem, chip: Node3D) -> bool:
	var cam := _camera(it)
	cam.current = true
	var view: SubViewport = (it.icon as ShopIcon).die_view
	var vs := Vector2(view.size)
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for i in 16:
		var a := float(i) / 16.0 * TAU
		var local := Vector3(cos(a), 0.0, sin(a)) * 1.05
		var sp := cam.unproject_position(chip.global_transform * local)
		lo = lo.min(sp)
		hi = hi.max(sp)
		if sp.x < -1.0 or sp.y < -1.0 or sp.x > vs.x + 1.0 or sp.y > vs.y + 1.0:
			print("  outside icon: ", chip.name, " ", sp, " view ", vs)
			return false
	var fill := maxf(hi.x - lo.x, hi.y - lo.y) / vs.x
	# Larger than the old flat read, and still clear of the icon edge.
	if fill < 0.55 or fill > 0.92:
		print("  icon fill: ", chip.name, " ", fill, " bounds ", lo, hi)
		return false
	return true
