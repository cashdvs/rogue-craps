extends SceneTree
## Each table shape's collider hull is the same size as the body we draw
## (mesh box x body_scale), so a die rests on what the player sees. The keg
## uses a fallback hull from its mobile LOD; it must be scaled the same way.

var _passed := 0
var _failed := 0


func check(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		print("FAIL  ", what)


func _box(pts: PackedVector3Array) -> AABB:
	var b := AABB(pts[0], Vector3.ZERO)
	for p in pts:
		b = b.expand(p)
	return b


func _same(a: Vector3, b: Vector3) -> bool:
	## Within 2% of the biggest side on every axis.
	var d := (a - b).abs()
	return maxf(d.x, maxf(d.y, d.z)) < maxf(b.x, maxf(b.y, b.z)) * 0.02


func _initialize() -> void:
	for shape: StringName in PolyBody.TABLE_SHAPES:
		var mesh := PolyBody.mesh_for(shape)
		var drawn := mesh.get_aabb().size * PolyBody.body_scale(shape)
		var hull := _box(PolyDie.hull(shape)).size
		check(_same(hull, drawn), "%s: hull %s matches drawn body %s" % [shape, hull, drawn])
	# The fallback is scaled by body_scale too (here a made-up 1.3).
	var keg := PolyBody.mesh_for(&"keg")
	var fit := _box(PolyBody._fit_hull(DieHullData.SHAPES[&"keg"]["hull"], keg, 1.3)).size
	check(_same(fit, keg.get_aabb().size * 1.3), "keg: fallback hull follows body_scale (%s)" % fit)
	print("test_hull_drawn_size: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)
