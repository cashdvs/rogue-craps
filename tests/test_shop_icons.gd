## Shop redesign PR A2: real item icons (3D dice with the warm key + fill
## rig, glyph tokens) and the Smiles still behind the counter, driven by the
## real RunScreen on the Shop screen.
##   godot --headless --path . --script res://tests/test_shop_icons.gd
extends SceneTree

var _passed: int = 0
var _failed: int = 0
var scene: RunScreen
var run: MapRun


func _initialize() -> void:
	scene = (load("res://scenes/run.tscn") as PackedScene).instantiate()
	scene.run_seed = 1234
	root.add_child(scene)
	await process_frame
	run = scene.run
	run.screen = MapRun.Screen.SHOP
	for k in 300:  # A shop whose second die is rare, as in test_shop_counter.
		run.shop_rerolls = k
		run._roll_shop()
		if run.shop_dice.size() > 1 and run.shop_dice[1] != null and run.shop_dice[1].is_rare():
			break
	run.progress.embers = 100
	scene.refresh()
	_test_icons()
	_test_lights()
	_test_die_framing()
	_test_dealer_layouts()
	_test_still_is_lifted()
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _check(ok: bool, what: String) -> void:
	if ok:
		_passed += 1
	else:
		_failed += 1
		print("FAIL: ", what)


func _die_item() -> ShopItem:
	for it in scene.shop_screen.items:
		if it.offer.kind == ShopOffer.Kind.DIE and it.offer.index == 1:
			return it
	return null


## Every item's icon is a ShopIcon; dice show their 3D model in a SubViewport.
func _test_icons() -> void:
	var items := scene.shop_screen.items
	_check(items.size() > 0 and items.all(func(it: ShopItem) -> bool: return it.icon is ShopIcon), "every item icon is a ShopIcon")
	var d := _die_item()
	_check(d != null and (d.icon as ShopIcon).die_view != null, "die icon has its 3D SubViewport")
	for k: StringName in [&"pyre_d6", &"gilt_d6", &"lodestone_d6", &"ossuary_d6", &"bellows_d6"]:
		_check(ShopIcon.model_path(DiceIds.body_key(k)) != "", "%s draws a model that exists" % k)
	_check(ShopIcon.GLYPHS[&"mod_wild"] == "spark", "token glyph keys")


## The rig: a warm key brighter than a soft fill, plus a dim ambient.
func _test_lights() -> void:
	var d := _die_item()
	if d == null:
		_check(false, "no die item")
		return
	var view: SubViewport = (d.icon as ShopIcon).die_view
	var lights: Array = view.get_children().filter(func(n: Node) -> bool: return n is DirectionalLight3D)
	_check(lights.size() == 2, "key and fill lights (got %d)" % lights.size())
	if lights.size() == 2:
		var key: DirectionalLight3D = lights[0]
		var fill: DirectionalLight3D = lights[1]
		_check(key.light_color.r > key.light_color.b, "key light is warm")
		var fc := fill.light_color
		_check(fc.r > fc.b + 0.05 and fc.r >= fc.g and fc.g >= fc.b, "fill light is warm, not cold (%s)" % fc)
		_check(key.light_energy > fill.light_energy * 2 and fill.light_energy > 0.0, "fill is soft next to the key")
		_check(key.global_basis.z.dot(fill.global_basis.z) < 0.5, "fill comes from another side")
	var envs: Array = view.get_children().filter(func(n: Node) -> bool: return n is WorldEnvironment)
	_check(envs.size() == 1 and (envs[0] as WorldEnvironment).environment.ambient_light_energy < 1.0, "dim ambient")


## Framing: the model is centred at the origin with its widest side 1 unit,
## and the camera shows all of it, filling most of the square.
func _test_die_framing() -> void:
	var d := _die_item()
	if d == null:
		_check(false, "no die item")
		return
	var view: SubViewport = (d.icon as ShopIcon).die_view
	var cam: Camera3D = view.get_camera_3d()
	var model: Node3D = view.get_children().filter(func(n: Node) -> bool: return n is Node3D and not (n is Camera3D or n is Light3D))[0]
	var b := ShopDieRender._bounds(model)
	b = model.transform * b
	_check(b.get_center().length() < 0.02, "model centred (off by %.3f)" % b.get_center().length())
	var lo := Vector2.INF
	var hi := -Vector2.INF
	for i in 8:
		var q := cam.unproject_position(b.get_endpoint(i))
		lo = lo.min(q)
		hi = hi.max(q)
	var vs := Vector2(view.size)
	var fill := maxf(hi.x - lo.x, hi.y - lo.y) / vs.x
	_check(lo.x >= 0 and lo.y >= 0 and hi.x <= vs.x and hi.y <= vs.y, "whole die in view")
	_check(fill > 0.6 and fill <= 1.0, "die fills the icon (%.2f)" % fill)
	# Every die model, even one built off its origin, is centred and sized.
	var worst := 0.0
	for f: String in DirAccess.get_files_at("res://art/models/dice"):
		if not f.ends_with(".glb"):
			continue
		var o := ShopOffer.new()
		o.art_key = StringName(f.get_basename())
		var r := ShopDieRender.make(o, 64)
		var m: Node3D = r.view.get_child(0)
		var mb := m.transform * ShopDieRender._bounds(m)
		worst = maxf(worst, mb.get_center().length() + absf(mb.get_longest_axis_size() - 1.0))
		r.free()
	_check(worst < 0.02, "every die model centred at unit size (worst %.3f)" % worst)


## Smiles stands behind the rail on PC and portrait, filling the top band;
## landscape has no room for him.
func _test_dealer_layouts() -> void:
	var ss := scene.shop_screen
	for c: Array in [[Vector2i(1920, 1080), true], [Vector2i(390, 844), true], [Vector2i(2400, 1080), false]]:
		ss.window_override = c[0]
		ss.build(scene)
		_check((ss.dealer != null) == c[1], "dealer shown=%s for %s" % [c[1], c[0]])
		if ss.dealer == null:
			continue
		var spec_top: float = ShopScreen.LAYOUTS[ss.layout].top
		var h := ss.get_viewport().get_visible_rect().size.y
		var top: float = spec_top * ss.k if spec_top >= 1.0 else spec_top * h  # Counter top.
		var r := ss.dealer.get_rect()
		var vw := ss.get_viewport().get_visible_rect().size.x
		var st: TextureRect = ss.dealer.still
		var fig := Rect2(st.global_position, st.size)
		var src: Vector2 = (st.texture as AtlasTexture).region.size if st.texture is AtlasTexture else Vector2.ZERO
		_check(src != Vector2.ZERO and absf(fig.size.aspect() - src.aspect()) < 0.01, "Smiles keeps his shape, uncut, for %s" % c[0])
		_check(fig.position.x >= 0 and fig.end.x <= vw and fig.position.y >= r.position.y - 0.5, "all of Smiles (arm too) in view for %s" % c[0])
		_check(absf(fig.get_center().x - vw / 2.0) < 1.0, "Smiles centred for %s" % c[0])
		_check(fig.size.y > r.size.y * 0.8, "Smiles fills the band for %s" % c[0])
		var lip := Rect2(ss.dealer.rail.global_position, ss.dealer.rail.size)
		_check(absf(fig.end.y - lip.end.y) <= 0.5, "Smiles stands on the rail, feet tucked under it (bottom %.1f, rail %.1f..%.1f) for %s" % [fig.end.y, lip.position.y, lip.end.y, c[0]])
		_check(st.stretch_mode == TextureRect.STRETCH_SCALE and st.expand_mode == TextureRect.EXPAND_IGNORE_SIZE and st.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Smiles still scales and ignores the mouse for %s" % c[0])
		_check(lip.position.y > fig.position.y + fig.size.y * 0.75 and lip.end.y <= r.end.y + 0.5, "rail sits below his head and shoulders for %s" % c[0])
		_check(is_equal_approx(lip.position.x, 0.0) and is_equal_approx(lip.size.x, vw) and ss.dealer.shadow.size.x == vw and ss.dealer.shadow.position.y >= ss.dealer.rail.get_rect().end.y - 0.5, "full-width rail with shadow line for %s" % c[0])
		var plate := ss.embers_label.get_parent()
		while plate != null and not (plate is PriceTag):
			plate = plate.get_parent()
		_check(plate != null and not r.intersects(Rect2((plate as Control).global_position, (plate as Control).size)), "backdrop clear of the Ember total for %s" % c[0])
		_check(r.end.y <= top + 0.5 and r.size.y > 80 * ss.k, "dealer sits in the band above the counter for %s" % c[0])
		_check(is_equal_approx(ss.dealer.shadow.get_rect().end.y, r.size.y) and ss.dealer.rail.color == ShopScreen.BRASS, "brass rail along his bottom for %s" % c[0])
		_check(ss.dealer.get_index() < ss.shelves[0].get_index(), "dealer is behind the counter")
	ss.window_override = Vector2i.ZERO
	scene.refresh()


## The boss_toon lift is baked in: background clear, and no opaque pixel is
## darker than the +0.08 grey step (the raw render has near-black shadows).
func _test_still_is_lifted() -> void:
	var img: Image = (load(DealerBackdrop.STILL) as Texture2D).get_image()
	img.decompress()
	_check(img.get_pixel(0, 0).a == 0.0, "black background is transparent")
	var dark := 0
	var opaque := 0
	for y in range(0, img.get_height(), 2):
		for x in range(0, img.get_width(), 2):
			var p := img.get_pixel(x, y)
			if p.a >= 0.99:
				opaque += 1
				if minf(p.r, minf(p.g, p.b)) < 0.06:
					dark += 1
	_check(opaque > 1000 and dark == 0, "every opaque pixel is lifted (%d of %d too dark)" % [dark, opaque])
