## Headless test: NO FIRE ON DICE (Cash, Oct 19; bonfire_map_events_juice.md
## 3 and 6). Runs every dice moment of BonfireJuice (score tiers 0-3, Hot
## Hand ignite, the fly-back trail, drop) on the real Bonfire table, with and
## without the art branch, and checks that nothing fiery is spawned on or
## around the dice: no fire / flame / ignite / pillar scenes or materials, no
## new real lights, no rising (flame-like) particles, trails gone in ~0.3 s,
## glow colours never violet or Soul cyan, and the glow clears on drop.
##
## Run:
##   godot --headless --path . --script res://tests/test_fx_no_fire_on_dice.gd
extends SceneTree

const FIRE_WORDS: Array[String] = ["fire", "flame", "ignite", "pillar", "inferno", "blaze"]

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
	print("=== Dice of the Damned: no fire on dice (fx) ===")
	_test_palette()
	await _test_table(true)
	await _test_table(false)
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


## Glow colours: warm only (amber .. near-white), never violet or cyan.
func _test_palette() -> void:
	var prev_v := -1.0
	for k in DieGlow.TIER_COLORS.size():
		var c := DieGlow.TIER_COLORS[k]
		var warm := c.h <= 0.17 or c.s < 0.15
		_check(warm, "glow tier %d is warm (hue %.2f)" % [k, c.h])
		_check(not (c.h > 0.45 and c.h < 0.55) and not (c.h > 0.70 and c.h < 0.92), "glow tier %d is not cyan or violet" % k)
		_check(c != Palette.SOUL_FLAME and c != Palette.DANGER, "glow tier %d isn't Soul cyan or Danger" % k)
		_check(c.v >= prev_v - 0.25, "glow tier %d doesn't get darker than the one below" % k)
		prev_v = c.v
	_check(DieGlow.TRAIL_LIFE <= 0.3 and DieGlow.HOT_SPARK_LIFE <= 0.3, "trail and Hot Hand sparks fade within 0.3 s")
	_check(DieGlow.SPARK_DIRECTION.y <= 0.0 and DieGlow.TRAIL_DIRECTION.y <= 0.0, "spark/trail aim down or out, never up")
	_check(DieGlow.SPARK_SPREAD_DEG <= 90.0 and DieGlow.TRAIL_SPREAD_DEG <= 90.0, "spread ≤ 90° keeps initial velocity.y ≤ 0 with DOWN aim")
	_check(DieGlow.SPARK_GRAVITY < 0.0 and DieGlow.TRAIL_GRAVITY < 0.0, "spark/trail gravity pulls down")
	_check(DieGlow.peak_spark_height() <= 0.01, "sparks cannot rise more than 1 cm (peak %.4f)" % DieGlow.peak_spark_height())
	_check(DieGlow.peak_trail_height() <= 0.01, "ember trail cannot rise more than 1 cm (peak %.4f)" % DieGlow.peak_trail_height())


func _words_in(s: String) -> String:
	var l := s.to_lower()
	for w in FIRE_WORDS:
		if w in l:
			return w
	return ""


## Every node under `n` (inclusive) as a flat list.
func _all(n: Node, out: Array[Node]) -> Array[Node]:
	out.append(n)
	for c in n.get_children():
		_all(c, out)
	return out


## What looks like fire on a node: its name, scene, materials or particles.
func _fire_reason(n: Node) -> String:
	var w := _words_in(String(n.name)) if not n.name.begins_with("@") else ""
	if w == "" and n.scene_file_path != "":
		w = _words_in(n.scene_file_path)
	if w != "":
		return "%s (%s)" % [n.name, w]
	if n is GeometryInstance3D:
		var mats: Array[Material] = [(n as GeometryInstance3D).material_override]
		if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
			var mesh := (n as MeshInstance3D).mesh
			for i in mesh.get_surface_count():
				mats.append(mesh.surface_get_material(i))
		if n is CPUParticles3D and (n as CPUParticles3D).mesh != null:
			mats.append((n as CPUParticles3D).mesh.surface_get_material(0))
		for m in mats:
			if m != null and _words_in(m.resource_path) != "":
				return "%s material %s" % [n.name, m.resource_path]
	if n is CPUParticles3D:
		var p := n as CPUParticles3D
		if p.gravity.y > 0.0:
			return "%s rises like flame (gravity %.1f)" % [n.name, p.gravity.y]
		# Aiming up with a wide cone lets sparks climb above the die (flame cue).
		if p.direction.y > 0.01 and p.spread >= 90.0:
			return "%s aims up (dir.y=%.2f spread %.0f)" % [n.name, p.direction.y, p.spread]
		if p.lifetime > 0.5:
			return "%s lingers %.2f s" % [n.name, p.lifetime]
	if n is GPUParticles3D:
		return "%s GPU particles (the art fire scenes)" % n.name
	return ""


func _scan(s: Bonfire3D, before: Dictionary, tag: String, moment: String) -> void:
	var roots: Array[Node] = [s.fx_root, s.juice]
	for d in s.all_dice:
		roots.append(d)
	var bad: Array[String] = []
	var lights := 0
	for r in roots:
		for n in _all(r, []):
			if before.has(n.get_instance_id()):
				continue
			if n is Light3D:
				lights += 1
			var why := _fire_reason(n)
			if why != "":
				bad.append(why)
	_check(bad.is_empty(), "[%s] %s: nothing fiery spawned on/around the dice %s" % [tag, moment, str(bad)])
	_check(lights == 0, "[%s] %s: no new real lights (bloom only) (%d)" % [tag, moment, lights])


func _snapshot(s: Bonfire3D) -> Dictionary:
	var ids := {}
	var roots: Array[Node] = [s.fx_root, s.juice]
	for d in s.all_dice:
		roots.append(d)
	for r in roots:
		for n in _all(r, []):
			ids[n.get_instance_id()] = true
	return ids


func _test_table(fallback: bool) -> void:
	var tag := "fallback" if fallback else "adapter"
	var s := (load("res://scenes/bonfire.tscn") as PackedScene).instantiate() as Bonfire3D
	s.setup = TableSetup.sandbox(load("res://resources/tuning/bonfire_tuning.tres") as BonfireTuning, 5)
	root.add_child(s)
	s.juice.force_fallback = fallback
	await process_frame
	await process_frame
	var j := s.juice
	var dice: Array[DieVisual] = s.all_dice.duplicate()
	for k in 4:
		var before := _snapshot(s)
		j.calls.clear()
		j.escalate(k, dice, false, false)
		await process_frame
		_scan(s, before, tag, "score tier %d" % k)
		_check(j.calls.has("fx:glow_%d" % k), "[%s] tier %d logs its glow (%s)" % [tag, k, str(j.calls)])
		var halo := dice[0].get_node_or_null(DieGlow.HALO_NAME) as MeshInstance3D
		_check(halo != null, "[%s] tier %d: soft halo on the die" % [tag, k])
		_check(is_equal_approx(float(dice[0].body_material.get_shader_parameter("emission_energy")), DieGlow.TIER_EMISSION[k]), "[%s] tier %d: emission ramps" % [tag, k])
		_check(k < 3 or j.calls.has("fx:brazier_column") or j.calls.has("fx:brazier_missing"), "[%s] 1000+ goes to the brazier, not the dice (%s)" % [tag, str(j.calls)])
		Engine.time_scale = 1.0
	j.drop(dice, true)
	var clean := true
	for d in dice:
		clean = clean and d.get_node_or_null(DieGlow.HALO_NAME) == null and is_zero_approx(float(d.body_material.get_shader_parameter("emission_energy")))
	_check(clean, "[%s] drop() clears every glow and halo" % tag)
	# Hot Hand: glow pulse + sparks, then the ember trail while flying.
	var before := _snapshot(s)
	j.calls.clear()
	j.hot_hand(dice)
	await process_frame
	var m0 := dice[0].body_material
	_check(is_equal_approx(float(m0.get_shader_parameter("rim_strength")), DieGlow.TIER_RIM[3]), "[%s] Hot Hand uses glow tier 3 (rim)" % tag)
	var eco: Color = m0.get_shader_parameter("emission_color")
	_check(eco.is_equal_approx(Palette.EMBER), "[%s] Hot Hand emission is ember colour (%s)" % [tag, eco])
	var halo_hh := dice[0].get_node_or_null(DieGlow.HALO_NAME) as MeshInstance3D
	_check(halo_hh != null and is_equal_approx((halo_hh.mesh as QuadMesh).size.x, dice[0].edge * DieGlow.TIER_HALO_SIZE[3]), "[%s] Hot Hand halo is tier 3 size" % tag)
	j.fly_start(dice, 0.3)
	for i in 4:
		await create_timer(0.06).timeout
		_scan(s, before, tag, "Hot Hand + trail (t=%.2f)" % (0.06 * (i + 1)))
	_check(j.calls.has("fx:hot_hand_glow") and j.calls.has("fx:ember_trail"), "[%s] Hot Hand glow + trail hooks (%s)" % [tag, str(j.calls)])
	j.fly_stop(dice)
	await create_timer(1.0).timeout
	var left := 0
	for n in _all(s.fx_root, []):
		if n is CPUParticles3D and not before.has(n.get_instance_id()):
			left += 1
	_check(left == 0, "[%s] trail and spark dots are gone ~0.8 s after landing (%d left)" % [tag, left])
	_check(dice[0].get_node_or_null(DieGlow.HALO_NAME) == null, "[%s] fly_stop clears the Hot Hand glow" % tag)
	s.queue_free()
	await create_timer(0.5).timeout
